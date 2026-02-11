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
  attr :rows, :integer, default: 2

  def form_field(assigns) do
    ~H"""
    <div class={@colspan}>
      <label for={@name} class="block font-medium text-sm text-gray-700 dark:text-gray-300 mb-2">
        {@label}
        <span :if={@required} class="text-rose-500">*</span>
      </label>
      <%= if @type == "textarea" do %>
        <textarea
          id={@name}
          name={@name}
          rows={@rows}
          placeholder={@placeholder}
          class="block w-full font-mono text-sm shadow-sm border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 rounded-md focus:ring-blue-500 focus:border-blue-500"
        >{@value}</textarea>
      <% else %>
        <input
          type={@type}
          id={@name}
          name={@name}
          value={@value}
          placeholder={@placeholder}
          required={@required}
          class="block w-full font-mono text-sm shadow-sm border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 rounded-md focus:ring-blue-500 focus:border-blue-500"
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
        class="block w-full font-mono text-sm shadow-sm border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 rounded-md focus:ring-blue-500 focus:border-blue-500 disabled:opacity-50"
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
  attr :colspan, :string, default: nil

  def checkbox_field(assigns) do
    ~H"""
    <div class={@colspan}>
      <input type="hidden" name={@name} value="false" />
      <label
        for={@name}
        class="flex items-center font-medium text-sm text-gray-700 dark:text-gray-300 cursor-pointer"
      >
        <div class="relative mr-2">
          <input
            type="checkbox"
            id={@name}
            name={@name}
            value="true"
            checked={@checked}
            class="sr-only peer"
          />
          <span class="block w-4 h-4 rounded border border-gray-300 dark:border-gray-600 peer-checked:border-blue-500 peer-checked:bg-blue-500" />
          <Icons.check class="w-3 h-3 text-white absolute top-0.5 left-0.5 hidden peer-checked:block" />
        </div>
        {@label}
      </label>
    </div>
    """
  end
end
