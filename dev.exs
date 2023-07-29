# Development server for Oban Web

# Oban

defmodule WebDev.Generator do
  use GenServer

  @min_delay 100
  @max_delay 45_000
  @min_sleep 300
  @max_sleep 30_000
  @min_jobs 1
  @max_jobs 15
  @max_schedule 120
  @delay_chance 30

  @workers [
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
    for _ <- @min_jobs..@max_jobs do
      []
      |> weighted_schedule()
      |> random_priority()
      |> tracing_meta()
      |> worker.gen()
      |> Oban.insert!()
    end

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

  use Oban.Worker, queue: :media, tags: ["media"]

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
    Generator.random_perform(1_000, 4_000)

    if :rand.uniform() > 0.75 do
      {:ok, %{bots_cleaned: :rand.uniform(30)}}
    else
      {:snooze, 5}
    end
  end
end

defmodule Oban.Workers.DigestMailer do
  @moduledoc false

  use Oban.Worker, queue: :mailers, max_attempts: 1, tags: ["notification"]

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

  use Oban.Worker, queue: :events, tags: ["notification"]

  alias Faker.{Address, Date, Internet, Person}
  alias WebDev.Generator

  def gen(opts \\ []) do
    users =
      for _ <- 2..:rand.uniform(10) do
        %{
          name: Person.name(),
          city: Address.city(),
          country: Address.country(),
          email: Internet.free_email(),
          avatar: Internet.image_url()
        }
      end

    new(%{new_users: users, last_sync_at: Date.backward(1)}, opts)
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

  use Oban.Worker, queue: :events, max_attempts: 10

  alias Faker.{Team, UUID}
  alias WebDev.Generator

  def gen(opts \\ []) do
    fcm_ids = for _ <- 2..:rand.uniform(20), do: UUID.v4()

    new(%{fcm_ids: fcm_ids, message: "Welcome to #{Team.name()}"}, opts)
  end

  @impl Worker
  def perform(_job), do: Generator.random_perform(300, 5_000)

  @impl Worker
  def backoff(_job), do: 30
end

defmodule Oban.Workers.ReadabilityAnalyzer do
  @moduledoc false

  use Oban.Worker, queue: :analysis

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

  use Oban.Worker, queue: :mailers, max_attempts: 10

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
    field :id, :uuid
    field :description, :string
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
    field :id, :id
    field :file, :string
    field :type, :string
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

# Repo

defmodule WebDev.Repo do
  use Ecto.Repo, otp_app: :oban_web, adapter: Ecto.Adapters.Postgres
end

defmodule WebDev.Migration0 do
  use Ecto.Migration

  def up do
    Oban.Migrations.up()
    Oban.Pro.Migrations.Producers.up()
    Oban.Pro.Migrations.DynamicCron.up()
    Oban.Pro.Migrations.DynamicQueues.up()
  end

  def down do
    Oban.Pro.Migrations.DynamicQueues.down()
    Oban.Pro.Migrations.DynamicCron.down()
    Oban.Pro.Migrations.Producers.down()
    Oban.Migrations.down()
  end
end

# Phoenix

defmodule WebDev.Router do
  use Phoenix.Router, helpers: false

  import Oban.Web.Router

  pipeline :browser do
    plug :fetch_session
  end

  scope "/" do
    pipe_through :browser

    oban_dashboard "/oban"
  end
end

defmodule WebDev.Endpoint do
  use Phoenix.Endpoint, otp_app: :oban_web

  socket "/live", Phoenix.LiveView.Socket
  socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket

  plug Phoenix.LiveReloader
  plug Phoenix.CodeReloader

  plug Plug.Session,
    store: :cookie,
    key: "_oban_web_key",
    signing_salt: "/VEDsdfsffMnp5"

  plug WebDev.Router
end

defmodule WebDev.ErrorHTML do
  use Phoenix.HTML

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
  repo: WebDev.Repo,
  queues: [
    analysis: 30,
    default: 30,
    events: 15,
    exports: [global_limit: 8],
    mailers: [local_limit: 10, rate_limit: [allowed: 90, period: 15]],
    media: [
      local_limit: 10,
      rate_limit: [allowed: 60, period: 60, partition: [fields: [:worker]]]
    ]
  ],
  plugins: [
    {Oban.Pro.Plugins.DynamicLifeline, []},
    {Oban.Pro.Plugins.DynamicPruner, mode: {:max_age, {1, :days}}}
  ]
]

Task.async(fn ->
  children = [
    {Phoenix.PubSub, [name: WebDev.PubSub, adapter: Phoenix.PubSub.PG2]},
    {WebDev.Repo, []},
    {Oban, oban_opts},
    {WebDev.Generator, []},
    {WebDev.Endpoint, []}
  ]

  Ecto.Adapters.Postgres.storage_up(WebDev.Repo.config())

  {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one)

  Ecto.Migrator.run(WebDev.Repo, [{0, WebDev.Migration0}], :up, all: true)

  Process.sleep(:infinity)
end)
