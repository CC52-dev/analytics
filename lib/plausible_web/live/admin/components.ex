defmodule PlausibleWeb.Live.Admin.Components do
  @moduledoc """
  Shared building blocks for the admin panel pages.
  """

  use Phoenix.Component
  use PlausibleWeb.VerifiedRoutes

  attr :active, :atom, required: true, values: [:users, :sites]
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  slot :actions
  slot :inner_block, required: true

  def page(assigns) do
    ~H"""
    <div class="container max-w-5xl pt-6 pb-12">
      <div class="flex items-center gap-2 text-sm font-medium text-indigo-600 dark:text-indigo-400">
        <Heroicons.shield_check class="size-4" /> Admin panel
      </div>
      <div class="mt-2 flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h1 class="text-2xl font-bold tracking-tight text-gray-900 dark:text-gray-100">
            {@title}
          </h1>
          <p :if={@subtitle} class="mt-1 text-sm text-gray-500 dark:text-gray-400">{@subtitle}</p>
        </div>
        <div class="flex items-center gap-2">{render_slot(@actions)}</div>
      </div>

      <nav class="mt-6 flex gap-1 border-b border-gray-200 dark:border-gray-800">
        <.tab href={~p"/admin/users"} active={@active == :users}>
          <Heroicons.users class="size-4" /> Users
        </.tab>
        <.tab href={~p"/admin/sites"} active={@active == :sites}>
          <Heroicons.globe_alt class="size-4" /> Sites
        </.tab>
      </nav>

      <div class="mt-6">{render_slot(@inner_block)}</div>
    </div>
    """
  end

  attr :href, :string, required: true
  attr :active, :boolean, default: false
  slot :inner_block, required: true

  defp tab(assigns) do
    ~H"""
    <.link
      navigate={@href}
      class={[
        "-mb-px flex items-center gap-2 border-b-2 px-4 py-2.5 text-sm font-medium transition-colors",
        if(@active,
          do: "border-indigo-600 text-indigo-600 dark:border-indigo-400 dark:text-indigo-400",
          else:
            "border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200"
        )
      ]}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  attr :title, :string, default: nil
  attr :class, :string, default: ""
  slot :inner_block, required: true
  slot :header_actions

  def card(assigns) do
    ~H"""
    <section class={[
      "rounded-xl border border-gray-200 bg-white shadow-sm dark:border-gray-800 dark:bg-gray-900",
      @class
    ]}>
      <header
        :if={@title}
        class="flex items-center justify-between border-b border-gray-100 px-5 py-4 dark:border-gray-800"
      >
        <h2 class="text-base font-semibold text-gray-900 dark:text-gray-100">{@title}</h2>
        <div>{render_slot(@header_actions)}</div>
      </header>
      <div class="p-5">{render_slot(@inner_block)}</div>
    </section>
    """
  end

  attr :value, :any, required: true
  attr :label, :string, required: true

  def stat(assigns) do
    ~H"""
    <div class="rounded-xl border border-gray-200 bg-white px-5 py-4 shadow-sm dark:border-gray-800 dark:bg-gray-900">
      <div class="text-sm text-gray-500 dark:text-gray-400">{@label}</div>
      <div class="mt-1 text-2xl font-semibold text-gray-900 dark:text-gray-100">{@value}</div>
    </div>
    """
  end

  attr :name, :string, required: true
  attr :class, :string, default: "size-9 text-sm"

  def avatar(assigns) do
    ~H"""
    <span class={[
      "inline-flex shrink-0 items-center justify-center rounded-full bg-indigo-100 font-semibold text-indigo-700 dark:bg-indigo-500/20 dark:text-indigo-300",
      @class
    ]}>
      {initials(@name)}
    </span>
    """
  end

  attr :kind, :atom, required: true
  slot :inner_block, required: true

  def badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium ring-1 ring-inset",
      case @kind do
        :admin ->
          "bg-indigo-50 text-indigo-700 ring-indigo-600/20 dark:bg-indigo-500/10 dark:text-indigo-300 dark:ring-indigo-400/30"

        :editor ->
          "bg-amber-50 text-amber-700 ring-amber-600/20 dark:bg-amber-500/10 dark:text-amber-300 dark:ring-amber-400/30"

        :viewer ->
          "bg-emerald-50 text-emerald-700 ring-emerald-600/20 dark:bg-emerald-500/10 dark:text-emerald-300 dark:ring-emerald-400/30"

        _ ->
          "bg-gray-50 text-gray-600 ring-gray-500/20 dark:bg-gray-500/10 dark:text-gray-300 dark:ring-gray-400/30"
      end
    ]}>
      {render_slot(@inner_block)}
    </span>
    """
  end

  attr :name, :string, required: true
  attr :value, :string, default: ""
  attr :placeholder, :string, required: true

  def search(assigns) do
    ~H"""
    <form phx-change="search" phx-submit="search" class="relative w-full sm:max-w-xs">
      <Heroicons.magnifying_glass class="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-gray-400" />
      <input
        type="text"
        name={@name}
        value={@value}
        placeholder={@placeholder}
        phx-debounce="250"
        autocomplete="off"
        class="block w-full rounded-md border-gray-300 pl-9 text-sm shadow-sm focus:border-indigo-500 focus:ring-indigo-500 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-100"
      />
    </form>
    """
  end

  def role_label(:viewer), do: "Viewer"
  def role_label(:editor), do: "Editor"
  def role_label(:admin), do: "Admin"
  def role_label(:owner), do: "Owner"
  def role_label(role), do: role |> to_string() |> String.capitalize()

  def format_date(nil), do: "Never"
  def format_date(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%b %-d, %Y")
  def format_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%b %-d, %Y")

  def generate_password do
    :crypto.strong_rand_bytes(12) |> Base.url_encode64(padding: false)
  end

  defp initials(name) do
    name
    |> to_string()
    |> String.split(~r/[\s@._-]+/, trim: true)
    |> Enum.take(2)
    |> Enum.map_join(&String.first/1)
    |> String.upcase()
  end
end
