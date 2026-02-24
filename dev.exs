# Development server for Oban Web

# Oban

defmodule WebDev.Generator do
  use GenServer

  @min_delay 500
  @max_delay 60_000
  @min_sleep 300
  @max_sleep 30_000
  @min_jobs 1
  @max_jobs 10
  @max_schedule 120
  @delay_chance 30

  @workers [
    Oban.Workers.ArticleSummarizer,
    Oban.Workers.AvatarProcessor,
    Oban.Workers.BotCleaner,
    Oban.Workers.DigestMailer,
    Oban.Workers.ExportGenerator,
    Oban.Workers.MailingListSyncer,
    Oban.Workers.PricingAnalyzer,
    Oban.Workers.PushNotifier,
    Oban.Workers.ReadabilityAnalyzer,
    Oban.Workers.ReceiptMailer,
    Oban.Workers.SyntaxAnalyzer,
    Oban.Workers.TranscriptionAnalyzer,
    Oban.Workers.VideoProcessor
  ]

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)

    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec random_perform(integer(), integer()) :: :ok
  def random_perform(min \\ @min_sleep, max \\ @max_sleep) do
    chance = :rand.uniform(100)

    cond do
      chance in 0..10 ->
        Process.sleep(min * chance)

        {:snooze, chance}

      chance in 11..25 ->
        Process.sleep(min * chance)

        raise RuntimeError, "Something went wrong!"

      true ->
        min..max
        |> Enum.random()
        |> Process.sleep()
    end
  end

  # Callbacks

  @impl GenServer
  def init(_opts) do
    Enum.each(@workers, &delay_generation/1)

    {:ok, []}
  end

  @impl GenServer
  def handle_info({:generate, worker}, state) do
    changesets =
      for _ <- @min_jobs..@max_jobs do
        []
        |> weighted_schedule()
        |> random_priority()
        |> tracing_meta()
        |> worker.gen()
      end

    Oban.insert_all(changesets)

    delay_generation(worker)

    {:noreply, state}
  end

  defp delay_generation(worker) do
    delay = Enum.random(@min_delay..@max_delay)

    Process.send_after(self(), {:generate, worker}, delay)
  end

  defp weighted_schedule(opts) do
    if :rand.uniform(100) < @delay_chance do
      Keyword.put(opts, :schedule_in, :rand.uniform(@max_schedule))
    else
      opts
    end
  end

  defp random_priority(opts) do
    Keyword.put(opts, :priority, Enum.random(0..3))
  end

  defp tracing_meta(opts) do
    Keyword.put(opts, :meta, %{trace: Faker.UUID.v4(), vsn: Faker.App.semver()})
  end
end

defmodule Oban.Workers.AvatarProcessor do
  @moduledoc false

  use Oban.Pro.Worker, queue: :media, tags: ["media"]

  alias Faker.Avatar
  alias WebDev.Generator

  def gen(opts \\ []) do
    new(%{id: Enum.random(100..10_000), image_url: Avatar.image_url()}, opts)
  end

  @impl Worker
  def perform(_job), do: Generator.random_perform(300, 3_000)
end

defmodule Oban.Workers.BotCleaner do
  @moduledoc false

  use Oban.Pro.Worker, queue: :default, max_attempts: 5, recorded: true

  alias Faker.Internet
  alias Faker.Internet.UserAgent
  alias WebDev.Generator

  def gen(opts \\ []) do
    opts = Keyword.put(opts, :tags, ["agent", "bots"])

    new(%{domain: Internet.domain_name(), user_agent: UserAgent.user_agent()}, opts)
  end

  @impl Oban.Pro.Worker
  def process(_job) do
    Generator.random_perform(1_000, 3_000)
  end
end

defmodule Oban.Workers.DigestMailer do
  @moduledoc false

  use Oban.Pro.Worker, queue: :mailers, max_attempts: 1, tags: ["notification"]

  alias Faker.{Company, Internet}
  alias WebDev.Generator

  def gen(opts \\ []) do
    new(%{email: Internet.email(), project: Company.bullshit()}, opts)
  end

  @impl Worker
  def perform(_job), do: Generator.random_perform(100, 5_000)
end

defmodule Oban.Workers.ExportGenerator do
  @moduledoc false

  use Oban.Pro.Worker,
    queue: :exports,
    max_attempts: 3,
    encrypted: [key: {__MODULE__, :enc_key, []}]

  alias Faker.{File, Internet}
  alias WebDev.Generator

  def gen(opts \\ []) do
    new(%{email: Internet.free_email(), file: File.file_name()}, opts)
  end

  @impl Oban.Pro.Worker
  def process(_job), do: Generator.random_perform(1_200, 8_000)

  @doc false
  def enc_key, do: "3qvMCmkaKR3t/6DB8Lg6p8l+nO5V014GFpbUV5HdrkU="
end

defmodule Oban.Workers.MailingListSyncer do
  @moduledoc false

  use Oban.Pro.Worker, queue: :events, tags: ["notification"]

  alias Faker.{Address, Date, Internet, Person}
  alias WebDev.Generator

  def gen(_opts) do
    new(%{
      name: Person.name(),
      email: Internet.free_email(),
      avatar: Internet.image_url(),
      address: %{
        city: Address.city(),
        country: Address.country(),
        state: Address.state(),
        zip: Address.zip()
      }
    })
  end

  @impl Worker
  def perform(_job), do: Generator.random_perform(400, 2_500)

  @impl Worker
  def timeout(_job), do: :timer.seconds(20)
end

defmodule Oban.Workers.PricingAnalyzer do
  @moduledoc false

  use Oban.Pro.Worker, queue: :analysis, recorded: true

  alias Faker.{Commerce, Date, UUID}
  alias WebDev.Generator

  def gen(opts \\ []) do
    days = :rand.uniform(20)

    args = %{
      id: UUID.v4(),
      price: Commerce.price(),
      started_at: Date.backward(days)
    }

    new(args, opts)
  end

  @impl Oban.Pro.Worker
  def process(_job) do
    Generator.random_perform(500, 10_000)

    {:ok,
     %{
       product: Commerce.product_name(),
       size: Commerce.product_name_adjective(),
       ticker: Faker.Finance.Stock.ticker(),
       analyzed_at: DateTime.utc_now()
     }}
  end
end

defmodule Oban.Workers.PushNotifier do
  @moduledoc false

  use Oban.Pro.Worker, queue: :events, max_attempts: 10

  alias Faker.{Team, UUID}
  alias WebDev.Generator

  def gen(opts \\ []) do
    max = Enum.random(3..20)
    ids = for _ <- 2..max, do: UUID.v4()

    new(%{fcm_ids: ids, message: "Welcome to #{Team.name()}"}, opts)
  end

  @impl Worker
  def perform(_job), do: Generator.random_perform(300, 5_000)

  @impl Worker
  def backoff(_job), do: 30
end

defmodule Oban.Workers.ReadabilityAnalyzer do
  @moduledoc false

  use Oban.Pro.Worker, queue: :analysis

  alias Faker.Lorem.Shakespeare
  alias Faker.UUID
  alias WebDev.Generator

  def gen(opts \\ []) do
    new(%{id: UUID.v4(), phrase: Shakespeare.hamlet()}, opts)
  end

  @impl Worker
  def perform(_job) do
    if :rand.uniform() < 0.75 do
      Generator.random_perform(1_000, 15_000)
    else
      {:cancel, "no longer neaded"}
    end
  end
end

defmodule Oban.Workers.ReceiptMailer do
  @moduledoc false

  use Oban.Pro.Worker, queue: :mailers, max_attempts: 10

  alias Faker.{Commerce, Company, UUID}
  alias WebDev.Generator

  def gen(opts \\ []) do
    new(%{account: Company.name(), id: UUID.v4(), price: Commerce.price()}, opts)
  end

  @impl Worker
  def perform(_job), do: Generator.random_perform(400, 6_000)
end

defmodule Oban.Workers.SyntaxAnalyzer do
  @moduledoc false

  use Oban.Pro.Worker, queue: :analysis

  args_schema do
    field(:id, :uuid)
    field(:description, :string)
  end

  alias Faker.{Food, UUID}
  alias WebDev.Generator

  def gen(opts \\ []) do
    new(%{id: UUID.v4(), description: Food.description()}, opts)
  end

  @impl Oban.Pro.Worker
  def process(%Job{args: _}), do: Generator.random_perform(500, 10_000)
end

defmodule Oban.Workers.TranscriptionAnalyzer do
  @moduledoc false

  # Purposefully using Oban.Worker rather than Oban.Pro.Worker
  use Oban.Worker, queue: :analysis

  alias Faker.Lorem.Shakespeare
  alias Faker.UUID
  alias WebDev.Generator

  def gen(opts \\ []) do
    new(%{id: UUID.v4(), transcript: Shakespeare.as_you_like_it()}, opts)
  end

  @impl Worker
  def perform(_job), do: Generator.random_perform(1_500, 7_000)
end

defmodule Oban.Workers.VideoProcessor do
  @moduledoc false

  use Oban.Pro.Worker, queue: :media, max_attempts: 5

  args_schema do
    field(:id, :id)
    field(:file, :string)
    field(:type, :string)
  end

  alias Faker.File
  alias WebDev.Generator

  def gen(opts \\ []) do
    args = %{
      id: Enum.random(100..10_000),
      file: File.file_name(:video),
      type: File.mime_type(:video)
    }

    new(args, opts)
  end

  @impl Oban.Pro.Worker
  def process(%Job{args: %__MODULE__{}}), do: Generator.random_perform(1_000, 20_000)
end

defmodule Oban.Workers.ArticleSummarizer do
  @moduledoc false

  use Oban.Pro.Decorator

  alias Faker.{Team, UUID}
  alias WebDev.Generator

  def gen(_opts) do
    new_summarize(UUID.v4(), Team.name())
  end

  @job true
  def summarize(_id, _team) do
    Generator.random_perform(500, 5_000)
  end
end

# Cron Workers

defmodule Oban.Workers.HealthChecker do
  use Oban.Pro.Worker, queue: :health, max_attempts: 3

  alias WebDev.Generator

  @impl Oban.Pro.Worker
  def process(_job) do
    Generator.random_perform(2_000, 5_000)
  end
end

defmodule Oban.Workers.CustomerSegmenter do
  use Oban.Pro.Worker, queue: :default

  alias WebDev.Generator

  @impl Oban.Pro.Worker
  def process(_job) do
    Generator.random_perform(5_000, 20_000)
  end
end

defmodule Oban.Workers.TrialCleaner do
  use Oban.Pro.Worker, queue: :health

  alias WebDev.Generator

  @impl Oban.Pro.Worker
  def process(_job) do
    Generator.random_perform(2_000, 6_000)
  end
end

defmodule Oban.Workers.DormantLocker do
  use Oban.Pro.Worker, queue: :health

  alias WebDev.Generator

  @impl Oban.Pro.Worker
  def process(_job) do
    Generator.random_perform(3_000, 9_000)
  end
end

defmodule Oban.Workers.IndexRebuilder do
  use Oban.Pro.Worker, queue: :health

  alias WebDev.Generator

  @impl Oban.Pro.Worker
  def process(_job) do
    Generator.random_perform(10_000, 20_000)
  end
end

defmodule Oban.Workers.SecurityScanner do
  use Oban.Pro.Worker, queue: :health

  alias WebDev.Generator

  @impl Oban.Pro.Worker
  def process(_job) do
    Generator.random_perform(10_000, 20_000)
  end
end

defmodule Oban.Workers.TrafficReport do
  use Oban.Pro.Worker, queue: :exports

  alias WebDev.Generator

  @impl Oban.Pro.Worker
  def process(_job) do
    Generator.random_perform(3_000, 10_000)
  end
end

defmodule Oban.Workers.WeeklyUpdate do
  use Oban.Pro.Worker, queue: :default

  alias WebDev.Generator

  @impl Oban.Pro.Worker
  def process(_job) do
    Generator.random_perform(2_000, 7_000)
  end
end

# Workflow Workers

defmodule Oban.Workers.DocumentProcessor do
  use Oban.Pro.Worker, queue: :media

  @impl Oban.Pro.Worker
  def process(_job), do: WebDev.Generator.random_perform(500, 12_000)
end

defmodule Oban.Workers.OrderProcessor do
  use Oban.Pro.Worker, queue: :fulfillment, recorded: true

  @impl Oban.Pro.Worker
  def process(_job), do: WebDev.Generator.random_perform(300, 8_000)
end

defmodule Oban.Workers.DataPipeline do
  use Oban.Pro.Worker, queue: :etl

  @impl Oban.Pro.Worker
  def process(_job), do: WebDev.Generator.random_perform(1_000, 20_000)
end

defmodule Oban.Workers.TenantProvisioner do
  use Oban.Pro.Worker, queue: :default

  @impl Oban.Pro.Worker
  def process(_job), do: WebDev.Generator.random_perform(500, 15_000)
end

defmodule Oban.Workers.ApprovalHandler do
  use Oban.Pro.Worker, queue: :default, recorded: true

  @impl Oban.Pro.Worker
  def process(_job), do: WebDev.Generator.random_perform(300, 10_000)
end

defmodule Oban.Workers.Notifier do
  use Oban.Pro.Worker, queue: :notifications

  @impl Oban.Pro.Worker
  def process(_job), do: WebDev.Generator.random_perform(200, 5_000)
end

# Repo

defmodule WebDev.Repo do
  use Ecto.Repo, otp_app: :oban_web, adapter: Ecto.Adapters.Postgres
end

defmodule WebDev.Migration0 do
  use Ecto.Migration

  def up, do: Oban.Migration.up()

  def down, do: Oban.Migration.down()
end

defmodule WebDev.Migration1 do
  use Ecto.Migration

  def up, do: Oban.Pro.Migration.up()

  def down, do: Oban.Pro.Migration.down()
end

# Workflows

defmodule WebDev.Workflows do
  alias Oban.Pro.Workflow
  alias Oban.Workers.{DocumentProcessor, Notifier, OrderProcessor, TenantProvisioner}

  # ETL Cascade Functions

  def etl_extract(_ctx) do
    WebDev.Generator.random_perform(2_000, 10_000)
    {:ok, %{extracted_at: DateTime.utc_now()}}
  end

  def etl_transform(_ctx) do
    WebDev.Generator.random_perform(3_000, 12_000)
    {:ok, %{transformed_at: DateTime.utc_now()}}
  end

  def etl_load(_ctx) do
    WebDev.Generator.random_perform(5_000, 15_000)
    {:ok, %{loaded_at: DateTime.utc_now()}}
  end

  def etl_verify(_ctx) do
    WebDev.Generator.random_perform(1_000, 6_000)
    {:ok, %{verified_at: DateTime.utc_now()}}
  end

  def etl_index(_ctx) do
    WebDev.Generator.random_perform(2_000, 9_000)
    {:ok, %{indexed_at: DateTime.utc_now()}}
  end

  def etl_notify(_ctx) do
    WebDev.Generator.random_perform(500, 3_000)
    {:ok, %{notified_at: DateTime.utc_now()}}
  end

  # Tenant Cascade Functions

  def tenant_setup(_ctx) do
    WebDev.Generator.random_perform(200, 800)
    {:ok, %{setup_at: DateTime.utc_now()}}
  end

  def tenant_provision(_ctx) do
    WebDev.Generator.random_perform(300, 1_200)
    {:ok, %{provisioned_at: DateTime.utc_now()}}
  end

  def tenant_configure(_ctx) do
    WebDev.Generator.random_perform(200, 600)
    {:ok, %{configured_at: DateTime.utc_now()}}
  end

  def tenant_activate(_ctx) do
    WebDev.Generator.random_perform(100, 400)
    {:ok, %{activated_at: DateTime.utc_now()}}
  end

  # Approval Cascade Functions

  def approval_submit(_ctx) do
    WebDev.Generator.random_perform(100, 300)
    {:ok, %{submitted_at: DateTime.utc_now()}}
  end

  def approval_review(_ctx) do
    WebDev.Generator.random_perform(200, 800)

    if :rand.uniform(100) <= 20 do
      {:cancel, "rejected"}
    else
      {:ok, %{reviewed_at: DateTime.utc_now()}}
    end
  end

  def approval_decide(_ctx) do
    WebDev.Generator.random_perform(100, 400)
    {:ok, %{decided_at: DateTime.utc_now()}}
  end

  def approval_execute(_ctx) do
    WebDev.Generator.random_perform(300, 1_000)
    {:ok, %{executed_at: DateTime.utc_now()}}
  end

  def approval_notify(_ctx) do
    WebDev.Generator.random_perform(50, 200)
    {:ok, %{notified_at: DateTime.utc_now()}}
  end

  # Workflow Builders

  def document_processing do
    [workflow_name: "document-processing"]
    |> Workflow.new()
    |> Workflow.add(:ingest, DocumentProcessor.new(%{step: "ingest"}))
    |> Workflow.add(:parse, DocumentProcessor.new(%{step: "parse"}), deps: [:ingest])
    |> Workflow.add(:index, DocumentProcessor.new(%{step: "index"}), deps: [:parse])
    |> Workflow.add(:archive, DocumentProcessor.new(%{step: "archive"}), deps: [:index])
    |> Workflow.add(:notify, Notifier.new(%{type: "document_processed"}), deps: [:archive])
  end

  def order_fulfillment do
    validation =
      Workflow.new()
      |> Workflow.add(:validate_customer, OrderProcessor.new(%{step: "validate_customer"}))
      |> Workflow.add(:validate_payment, OrderProcessor.new(%{step: "validate_payment"}))
      |> Workflow.add(:check_inventory, OrderProcessor.new(%{step: "check_inventory"}))

    shipping =
      Workflow.new()
      |> Workflow.add(:pick_items, OrderProcessor.new(%{step: "pick_items"}))
      |> Workflow.add(:generate_label, OrderProcessor.new(%{step: "generate_label"}))
      |> Workflow.add(:ship_order, OrderProcessor.new(%{step: "ship_order"}), deps: [:pick_items, :generate_label])

    [workflow_name: "order-fulfillment"]
    |> Workflow.new()
    |> Workflow.add(:receive_order, OrderProcessor.new(%{step: "receive_order"}))
    |> Workflow.add_workflow(:validation, validation, deps: [:receive_order])
    |> Workflow.add(:confirm_order, OrderProcessor.new(%{step: "confirm_order"}), deps: [:validation])
    |> Workflow.add_workflow(:shipping, shipping, deps: [:confirm_order])
    |> Workflow.add(:notify, Notifier.new(%{step: "notify", type: "order_shipped"}), deps: [:shipping])
  end

  def data_migration do
    source = Enum.random(~w(legacy_db csv_import api_sync s3_bucket))

    Workflow.new()
    |> Workflow.put_context(%{source: source})
    |> Workflow.add_cascade(:extract, &etl_extract/1, queue: :etl)
    |> Workflow.add_cascade(:transform, &etl_transform/1, deps: [:extract], queue: :etl)
    |> Workflow.add_cascade(:load, &etl_load/1, deps: [:transform], queue: :etl)
    |> Workflow.add_cascade(:verify, &etl_verify/1, deps: [:load], queue: :etl)
    |> Workflow.add_cascade(:index, &etl_index/1, deps: [:verify], queue: :etl)
    |> Workflow.add_cascade(:notify, &etl_notify/1, deps: [:index], queue: :notifications)
  end

  def tenant_onboarding do
    tenant_count = Enum.random(3..5)
    tenant_ids = for num <- 1..tenant_count, do: "tenant_#{num}"

    [workflow_name: "tenant-onboarding"]
    |> Workflow.new()
    |> Workflow.add(:initialize, TenantProvisioner.new(%{step: "initialize", tenant_count: tenant_count}))
    |> Workflow.add_cascade(:tenants, {tenant_ids, &provision_tenant/2}, deps: [:initialize])
    |> Workflow.add(:aggregate, TenantProvisioner.new(%{step: "aggregate"}), deps: [:tenants])
    |> Workflow.add(:report, TenantProvisioner.new(%{step: "report"}), deps: [:aggregate])
    |> Workflow.add(:notify, Notifier.new(%{type: "tenants_onboarded"}), deps: [:report])
  end

  def provision_tenant(tenant_id, _ctx) do
    WebDev.Generator.random_perform(500, 3_000)
    {:ok, %{tenant_id: tenant_id, provisioned_at: DateTime.utc_now()}}
  end

  def approval_chain do
    request_id = Faker.UUID.v4()

    [workflow_name: "approval-chain", ignore_cancelled: true]
    |> Workflow.new()
    |> Workflow.put_context(%{request_id: request_id})
    |> Workflow.add_cascade(:submit, &approval_submit/1)
    |> Workflow.add_cascade(:review, &approval_review/1, deps: [:submit])
    |> Workflow.add_cascade(:decide, &approval_decide/1, deps: [:review])
    |> Workflow.add_cascade(:execute, &approval_execute/1, deps: [:decide])
    |> Workflow.add_cascade(:notify, &approval_notify/1, deps: [:execute], queue: :notifications)
  end
end

defmodule WebDev.WorkflowGenerator do
  use GenServer

  @min_delay 5_000
  @max_delay 30_000

  @workflows [
    :document_processing,
    :order_fulfillment,
    :data_migration,
    :tenant_onboarding,
    :approval_chain
  ]

  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)

    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl GenServer
  def init(_opts) do
    Enum.each(@workflows, &schedule_generation/1)

    {:ok, []}
  end

  @impl GenServer
  def handle_info({:generate, workflow}, state) do
    WebDev.Workflows
    |> apply(workflow, [])
    |> Oban.insert_all()

    schedule_generation(workflow)

    {:noreply, state}
  end

  defp schedule_generation(workflow) do
    delay = Enum.random(@min_delay..@max_delay)

    Process.send_after(self(), {:generate, workflow}, delay)
  end
end

# Phoenix

defmodule WebDev.Router do
  use Phoenix.Router, helpers: false

  import Oban.Web.Router

  pipeline :browser do
    plug(:fetch_session)
  end

  scope "/" do
    pipe_through(:browser)

    oban_dashboard("/oban")
  end
end

defmodule WebDev.Endpoint do
  use Phoenix.Endpoint, otp_app: :oban_web

  socket "/live", Phoenix.LiveView.Socket
  socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket

  plug Tidewave

  plug Phoenix.LiveReloader
  plug Phoenix.CodeReloader

  plug Plug.Session, store: :cookie, key: "_oban_web_key", signing_salt: "/VEDsdfsffMnp5"

  plug WebDev.Router
end

defmodule WebDev.ErrorHTML do
  use Phoenix.Component

  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end

# Configuration

port = "PORT" |> System.get_env("4000") |> String.to_integer()

Application.put_env(:oban_web, WebDev.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  check_origin: false,
  debug_errors: true,
  http: [port: port],
  live_view: [signing_salt: "eX7TFPY6Y/+XQ1o2pOUW3DjgAoXGTAdX"],
  pubsub_server: WebDev.PubSub,
  render_errors: [formats: [html: WebDev.ErrorHTML], layout: false],
  secret_key_base: "jAu3udxm+8tIRDXLLKo+EupAlEvdLsnNG82O8e9nqylpBM9gP8AjUnZ4PWNttztU",
  url: [host: "localhost"],
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:default, ~w(--watch)]}
  ],
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/oban/web/components/.*(ex)$",
      ~r"lib/oban/web/live/.*(ex)$"
    ]
  ]
)

Application.put_env(:oban_web, WebDev.Repo, url: "postgres://localhost:5432/oban_web_dev")
Application.put_env(:phoenix, :serve_endpoints, true)
Application.put_env(:phoenix, :persistent, true)

oban_opts = [
  engine: Oban.Pro.Engines.Smart,
  node: "web-dev-ex",
  notifier: Oban.Notifiers.Postgres,
  peer: Oban.Peers.Global,
  repo: WebDev.Repo,
  queues: [
    analysis: 30,
    default: 30,
    etl: 10,
    events: 20,
    exports: [global_limit: 8],
    fulfillment: 15,
    health: [global_limit: 1],
    mailers: [local_limit: 10, rate_limit: [allowed: 90, period: 15]],
    media: [
      local_limit: 20,
      rate_limit: [allowed: 120, period: 60, partition: [fields: [:worker]]]
    ],
    notifications: 10
  ],
  plugins: [
    {Oban.Pro.Plugins.DynamicLifeline, []},
    {Oban.Pro.Plugins.DynamicPruner, mode: {:max_age, {1, :days}}},
    {Oban.Pro.Plugins.DynamicCron, crontab: [
       {"*/2 * * * *", Oban.Workers.BotCleaner, tags: ~w(health bots)},
       {"*/5 * * * *", Oban.Workers.TrialCleaner, priority: 2},
       {"*/15 * * * *", Oban.Workers.DormantLocker},
       {"0 * * * *", Oban.Workers.TrafficReport, args: %{format: "json"}, tags: ["reports"]},
    ], sync_mode: :automatic},
    {Oban.Plugins.Cron,
     crontab: [
       {"* * * * *", Oban.Workers.HealthChecker, tags: ~w(health monitoring)},
       {"*/5 * * * *", Oban.Workers.CustomerSegmenter, args: %{batch_size: 1000}},
       {"30 */3 * * *", Oban.Workers.IndexRebuilder, priority: 1},
       {"0 */2 * * *", Oban.Workers.SecurityScanner, tags: ["security"]},
       {"0 6 * * MON", Oban.Workers.WeeklyUpdate, priority: 3}
     ]}
  ]
]

slow_oban_opts = [
  engine: Oban.Pro.Engines.Smart,
  name: Oban.Slow,
  notifier: {Oban.Notifiers.Postgres, namespace: :slow},
  repo: WebDev.Repo
]

Task.async(fn ->
  children = [
    {Phoenix.PubSub, [name: WebDev.PubSub, adapter: Phoenix.PubSub.PG2]},
    {WebDev.Repo, []},
    {Oban, oban_opts},
    {Oban, slow_oban_opts},
    {WebDev.Generator, []},
    {WebDev.WorkflowGenerator, []},
    {WebDev.Endpoint, []}
  ]

  Ecto.Adapters.Postgres.storage_up(WebDev.Repo.config())

  {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one)

  Ecto.Migrator.run(WebDev.Repo, [{0, WebDev.Migration0}, {1, WebDev.Migration1}], :up, all: true)

  Process.sleep(:infinity)
end)
