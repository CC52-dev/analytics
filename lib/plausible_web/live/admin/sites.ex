defmodule PlausibleWeb.Live.Admin.Sites do
  @moduledoc """
  Admin panel: list, search and create sites.
  """

  use PlausibleWeb, :live_view

  import PlausibleWeb.Live.Admin.Components

  alias Plausible.Admin

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(search: "", show_form?: false, selected_users: MapSet.new())
     |> assign_form(Admin.change_new_site(%{"timezone" => "Etc/UTC"}))
     |> load()}
  end

  def handle_params(params, _uri, socket) do
    {:noreply, assign(socket, show_form?: params["new"] == "1")}
  end

  def render(assigns) do
    ~H"""
    <.page
      active={:sites}
      title="Sites"
      subtitle="Every website tracked on this instance, and who can see it."
    >
      <:actions>
        <.button :if={not @show_form?} phx-click="toggle-form">
          <Heroicons.plus class="size-4" /> New site
        </.button>
      </:actions>

      <div class="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <.stat label="Sites" value={length(@all_sites)} />
        <.stat label="Customers" value={length(@customers)} />
        <.stat label="Access grants" value={@user_counts |> Map.values() |> Enum.sum()} />
      </div>

      <.card :if={@show_form?} title="New site" class="mt-6">
        <:header_actions>
          <button
            type="button"
            phx-click="toggle-form"
            class="text-gray-400 hover:text-gray-600 dark:hover:text-gray-200"
            aria-label="Close"
          >
            <Heroicons.x_mark class="size-5" />
          </button>
        </:header_actions>
        <.form for={@form} phx-change="validate" phx-submit="create" class="space-y-5">
          <div class="grid grid-cols-1 gap-5 sm:grid-cols-2">
            <.input
              field={@form[:domain]}
              label="Domain"
              placeholder="example.com"
              autocomplete="off"
              help_text="Without www or https://, e.g. shop.example.com"
            />
            <.input
              field={@form[:timezone]}
              type="select"
              label="Reporting timezone"
              options={Plausible.Timezones.options()}
            />
          </div>

          <div>
            <div class="text-sm font-medium text-gray-900 dark:text-gray-100">Give access to</div>
            <p class="text-sm text-gray-500 dark:text-gray-400">
              Customers you tick can view this site's dashboard. Platform admins always can.
            </p>
            <p :if={@customers == []} class="mt-3 text-sm text-gray-500 dark:text-gray-400">
              No customer accounts yet.
            </p>
            <div class="mt-3 grid max-h-64 grid-cols-1 gap-2 overflow-y-auto sm:grid-cols-2">
              <label
                :for={user <- @customers}
                class="flex cursor-pointer items-center gap-3 rounded-lg border border-gray-200 px-3 py-2 text-sm hover:bg-gray-50 has-[:checked]:border-indigo-500 has-[:checked]:bg-indigo-50 dark:border-gray-700 dark:hover:bg-gray-800 dark:has-[:checked]:bg-indigo-500/10"
              >
                <input
                  type="checkbox"
                  name="users[]"
                  value={user.id}
                  checked={MapSet.member?(@selected_users, user.id)}
                  class="rounded border-gray-300 text-indigo-600 focus:ring-indigo-500 dark:border-gray-600 dark:bg-gray-800"
                />
                <span class="min-w-0">
                  <span class="block truncate text-gray-900 dark:text-gray-100">{user.name}</span>
                  <span class="block truncate text-xs text-gray-500">{user.email}</span>
                </span>
              </label>
            </div>
          </div>

          <div class="flex justify-end gap-2 border-t border-gray-100 pt-5 dark:border-gray-800">
            <.button type="button" theme="secondary" phx-click="toggle-form">Cancel</.button>
            <.button type="submit">Create site</.button>
          </div>
        </.form>
      </.card>

      <.card class="mt-6">
        <div class="mb-4">
          <.search name="search" value={@search} placeholder="Search by domain" />
        </div>
        <div class="overflow-x-auto">
          <table class="min-w-full text-sm">
            <thead>
              <tr class="text-left text-xs uppercase tracking-wide text-gray-500 dark:text-gray-400">
                <th class="pb-3 pr-4 font-medium">Site</th>
                <th class="pb-3 pr-4 font-medium">Customers</th>
                <th class="hidden pb-3 pr-4 font-medium md:table-cell">Created</th>
                <th class="pb-3"></th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100 dark:divide-gray-800">
              <tr
                :for={site <- @sites}
                class="group cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-800/50"
                phx-click={JS.navigate(~p"/admin/sites/#{site.id}")}
              >
                <td class="py-3 pr-4">
                  <div class="flex items-center gap-3">
                    <img
                      src={"/favicon/sources/#{site.domain}?placeholder=site"}
                      class="size-5 rounded"
                      alt=""
                      loading="lazy"
                    />
                    <span class="truncate font-medium text-gray-900 dark:text-gray-100">
                      {site.domain}
                    </span>
                  </div>
                </td>
                <td class="py-3 pr-4 text-gray-700 dark:text-gray-300">
                  {Map.get(@user_counts, site.id, 0)}
                </td>
                <td class="hidden py-3 pr-4 text-gray-500 dark:text-gray-400 md:table-cell">
                  {format_date(site.inserted_at)}
                </td>
                <td class="py-3 text-right">
                  <a
                    href={"/#{URI.encode_www_form(site.domain)}"}
                    class="mr-3 text-indigo-600 hover:underline dark:text-indigo-400"
                    onclick="event.stopPropagation()"
                  >
                    Dashboard
                  </a>
                  <Heroicons.chevron_right class="inline size-4 text-gray-300 group-hover:text-gray-500" />
                </td>
              </tr>
            </tbody>
          </table>
          <p :if={@sites == []} class="py-8 text-center text-sm text-gray-500 dark:text-gray-400">
            {if @search == "", do: "No sites yet.", else: "No sites match your search."}
          </p>
        </div>
      </.card>
    </.page>
    """
  end

  def handle_event("search", %{"search" => search}, socket) do
    {:noreply, socket |> assign(search: search) |> load()}
  end

  def handle_event("toggle-form", _params, socket) do
    {:noreply,
     socket
     |> assign(show_form?: not socket.assigns.show_form?, selected_users: MapSet.new())
     |> assign_form(Admin.change_new_site(%{"timezone" => "Etc/UTC"}))}
  end

  def handle_event("validate", %{"site" => params} = all, socket) do
    changeset = params |> Admin.change_new_site() |> Map.put(:action, :validate)
    {:noreply, socket |> assign(selected_users: selected_users(all)) |> assign_form(changeset)}
  end

  def handle_event("create", %{"site" => params} = all, socket) do
    case Admin.create_site(socket.assigns.current_user, params) do
      {:ok, site} ->
        for user_id <- selected_users(all) do
          {:ok, _} = Admin.grant_access(Admin.get_user!(user_id), site, :viewer)
        end

        {:noreply,
         socket
         |> put_flash(:success, "#{site.domain} was created")
         |> push_navigate(to: ~p"/admin/sites/#{site.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(selected_users: selected_users(all)) |> assign_form(changeset)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Could not create the site (#{inspect(reason)})")}
    end
  end

  defp load(socket) do
    all_sites = Admin.list_sites()

    sites =
      if socket.assigns.search == "",
        do: all_sites,
        else: Admin.list_sites(socket.assigns.search)

    assign(socket,
      all_sites: all_sites,
      sites: sites,
      customers: Enum.reject(Admin.list_users(), & &1.platform_admin),
      user_counts: Admin.user_counts_by_site()
    )
  end

  defp assign_form(socket, changeset), do: assign(socket, form: to_form(changeset, as: :site))

  defp selected_users(params) do
    params
    |> Map.get("users", [])
    |> Enum.map(&String.to_integer/1)
    |> MapSet.new()
  end
end
