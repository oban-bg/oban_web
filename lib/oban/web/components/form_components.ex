defmodule Oban.Web.FormComponents do
  @moduledoc false

  use Oban.Web, :html

  attr :label, :string, required: true
  attr :name, :string, required: true
  attr :value, :any, default: nil
  attr :type, :string, default: "text"
  attr :colspan, :string, default: nil
  attr :placeholder, :string, default: nil
  attr :required, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :hint, :string, default: nil
  attr :rows, :integer, default: 2

  def form_field(assigns) do
    ~H"""
    <div class={@colspan}>
      <label
        for={@name}
        class="flex items-center gap-1 font-medium text-sm text-gray-700 dark:text-gray-300 mb-2"
      >
        {@label}
        <span :if={@required} class="text-rose-500">*</span>
        <span
          :if={@hint}
          id={"#{@name}-hint"}
          data-title={@hint}
          phx-hook="Tippy"
          class="translate-y-px"
        >
          <Icons.info_circle class="w-4 h-4 text-gray-400 dark:text-gray-500" />
        </span>
      </label>
      <%= if @type == "textarea" do %>
        <textarea
          id={@name}
          name={@name}
          rows={@rows}
          disabled={@disabled}
          placeholder={@placeholder}
          class="block w-full font-mono text-sm shadow-sm border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 rounded-md focus:ring-blue-500 focus:border-blue-500 disabled:opacity-50"
        >{@value}</textarea>
      <% else %>
        <input
          type={@type}
          id={@name}
          name={@name}
          value={@value}
          disabled={@disabled}
          placeholder={@placeholder}
          required={@required}
          class="block w-full font-mono text-sm shadow-sm border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 rounded-md focus:ring-blue-500 focus:border-blue-500 disabled:opacity-50"
        />
      <% end %>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :name, :string, required: true
  attr :value, :any, default: nil
  attr :options, :list, required: true
  attr :disabled, :boolean, default: false

  def select_field(assigns) do
    ~H"""
    <div>
      <label for={@name} class="block font-medium text-sm text-gray-700 dark:text-gray-300 mb-2">
        {@label}
      </label>
      <select
        id={@name}
        name={@name}
        disabled={@disabled}
        class="block w-full font-mono text-sm shadow-sm border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 rounded-md focus:ring-blue-500 focus:border-blue-500 disabled:opacity-50"
      >
        <option :for={{label, val} <- @options} value={val} selected={val == @value}>
          {label}
        </option>
      </select>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :name, :string, required: true
  attr :checked, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :hint, :string, default: nil
  attr :colspan, :string, default: nil

  def checkbox_field(assigns) do
    ~H"""
    <div class={[@colspan, "group"]}>
      <input type="hidden" name={@name} value="false" />
      <label
        for={@name}
        class="flex items-center font-medium text-sm text-gray-700 dark:text-gray-300 cursor-pointer group-has-[:disabled]:opacity-50 group-has-[:disabled]:cursor-not-allowed"
      >
        <div class="relative mr-2">
          <input
            type="checkbox"
            id={@name}
            name={@name}
            value="true"
            checked={@checked}
            disabled={@disabled}
            class="sr-only peer"
          />
          <span class="block w-4 h-4 rounded border border-gray-300 dark:border-gray-600 peer-checked:border-blue-500 peer-checked:bg-blue-500" />
          <Icons.check class="w-3 h-3 text-white absolute top-0.5 left-0.5 hidden peer-checked:block" />
        </div>
        {@label}
        <span
          :if={@hint}
          id={"#{@name}-hint"}
          data-title={@hint}
          phx-hook="Tippy"
          class="ml-1 translate-y-px"
        >
          <Icons.info_circle class="w-4 h-4 text-gray-400 dark:text-gray-500" />
        </span>
      </label>
    </div>
    """
  end

  # Form Parsing Helpers

  @doc """
  Parses and trims a string, returning nil for empty values.
  """
  def parse_string(nil), do: nil
  def parse_string(""), do: nil
  def parse_string(str), do: String.trim(str)

  @doc """
  Parses a string to an integer, returning nil for empty or invalid values.
  """
  def parse_int(nil), do: nil
  def parse_int(""), do: nil

  def parse_int(str) when is_binary(str) do
    case Integer.parse(str) do
      {num, ""} -> num
      _ -> nil
    end
  end

  @doc """
  Parses a comma-separated string into a list of trimmed tags. Returns nil for empty input.
  """
  def parse_tags(nil), do: nil
  def parse_tags(""), do: nil

  def parse_tags(str) when is_binary(str) do
    str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> case do
      [] -> nil
      tags -> tags
    end
  end

  @doc """
  Parses a JSON string into a map, returning nil for empty or invalid values.
  """
  def parse_json(nil), do: nil
  def parse_json(""), do: nil

  def parse_json(str) when is_binary(str) do
    case Oban.JSON.decode!(str) do
      map when is_map(map) -> map
      _ -> nil
    end
  rescue
    _ -> nil
  end

  @doc """
  Builds queue options from a list of queue structs.
  """
  def queue_options(queues) do
    queues
    |> Enum.map(fn %{name: name} -> {name, name} end)
    |> Enum.sort_by(&elem(&1, 0))
  end
end
