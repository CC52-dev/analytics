defmodule PlausibleWeb.Live.Admin.Users do
  @moduledoc """
  Admin panel: list, search and create user accounts.
  """

  use PlausibleWeb, :live_view

  import PlausibleWeb.Live.Admin.Components

  alias Plausible.Admin

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(search: "", show_form?: false, selected_sites: MapSet.new())
     |> assign_form(Admin.change_new_user())
     |> load()}
  end

  def handle_params(params, _uri, socket) do
    {:noreply, assign(socket, show_form?: params["new"] == "1")}
  end

  def render(assigns) do
    ~H"""
    <.page
      active={:users}
      title="Users"
      subtitle="Create accounts for your team and customers, and choose which sites each customer can see."
    >
      <:actions>
        <.button :if={not @show_form?} phx-click="toggle-form">
          <Heroicons.user_plus class="size-4" /> New user
        </.button>
      </:actions>

      <div class="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <.stat label="Total users" value={length(@all_users)} />
        <.stat label="Platform admins" value={Enum.count(@all_users, & &1.platform_admin)} />
        <.stat label="Customers" value={Enum.count(@all_users, &(not &1.platform_admin))} />
      </div>

      <.card :if={@show_form?} title="New user" class="mt-6">
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
            <.input field={@form[:name]} label="Full name" autocomplete="off" />
            <.input field={@form[:email]} type="email" label="Email" autocomplete="off" />
          </div>
          <div class="flex items-end gap-2">
            <div class="flex-1">
              <.input
                field={@form[:password]}
                type="text"
                label="Password"
                autocomplete="new-password"
                help_text="At least 12 characters. Share it with the user securely; they can change it in their settings."
              />
            </div>
            <.button type="button" theme="secondary" phx-click="generate-password" class="mb-6">
              Generate
            </.button>
          </div>
          <.input
            field={@form[:platform_admin]}
            type="checkbox"
            label="Platform admin: can manage all users and sites, and sees every dashboard"
          />

          <div :if={not admin_selected?(@form)}>
            <div class="text-sm font-medium text-gray-900 dark:text-gray-100">Site access</div>
            <p class="text-sm text-gray-500 dark:text-gray-400">
              The user can view dashboards for the sites you tick. You can change roles later.
            </p>
            <p :if={@sites == []} class="mt-3 text-sm text-gray-500 dark:text-gray-400">
              No sites yet.
              <.link navigate={~p"/admin/sites?new=1"} class="text-indigo-600 hover:underline">
                Add a site
              </.link>
              first.
            </p>
            <div class="mt-3 grid max-h-64 grid-cols-1 gap-2 overflow-y-auto sm:grid-cols-2">
              <label
                :for={site <- @sites}
                class="flex cursor-pointer items-center gap-3 rounded-lg border border-gray-200 px-3 py-2 text-sm hover:bg-gray-50 has-[:checked]:border-indigo-500 has-[:checked]:bg-indigo-50 dark:border-gray-700 dark:hover:bg-gray-800 dark:has-[:checked]:bg-indigo-500/10"
              >
                <input
                  type="checkbox"
                  name="sites[]"
                  value={site.id}
                  checked={MapSet.member?(@selected_sites, site.id)}
                  class="rounded border-gray-300 text-indigo-600 focus:ring-indigo-500 dark:border-gray-600 dark:bg-gray-800"
                />
                <span class="truncate text-gray-900 dark:text-gray-100">{site.domain}</span>
              </label>
            </div>
          </div>

          <div class="flex justify-end gap-2 border-t border-gray-100 pt-5 dark:border-gray-800">
            <.button type="button" theme="secondary" phx-click="toggle-form">Cancel</.button>
            <.button type="submit">Create user</.button>
          </div>
        </.form>
      </.card>

      <.card class="mt-6">
        <div class="mb-4 flex items-center justify-between gap-4">
          <.search name="search" value={@search} placeholder="Search by name or email" />
        </div>
        <div class="overflow-x-auto">
          <table class="min-w-full text-sm">
            <thead>
              <tr class="text-left text-xs uppercase tracking-wide text-gray-500 dark:text-gray-400">
                <th class="pb-3 pr-4 font-medium">User</th>
                <th class="pb-3 pr-4 font-medium">Role</th>
                <th class="hidden pb-3 pr-4 font-medium sm:table-cell">Sites</th>
                <th class="hidden pb-3 pr-4 font-medium md:table-cell">Last seen</th>
                <th class="pb-3"></th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100 dark:divide-gray-800">
              <tr
                :for={user <- @users}
                class="group cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-800/50"
                phx-click={JS.navigate(~p"/admin/users/#{user.id}")}
              >
                <td class="py-3 pr-4">
                  <div class="flex items-center gap-3">
                    <.avatar name={user.name || user.email} />
                    <div class="min-w-0">
                      <div class="truncate font-medium text-gray-900 dark:text-gray-100">
                        {user.name}
                        <span :if={user.id == @current_user.id} class="text-gray-400">(you)</span>
                      </div>
                      <div class="truncate text-gray-500 dark:text-gray-400">{user.email}</div>
                    </div>
                  </div>
                </td>
                <td class="py-3 pr-4">
                  <.badge :if={user.platform_admin} kind={:admin}>Platform admin</.badge>
                  <.badge :if={not user.platform_admin} kind={:customer}>Customer</.badge>
                </td>
                <td class="hidden py-3 pr-4 text-gray-700 dark:text-gray-300 sm:table-cell">
                  {if user.platform_admin, do: "All", else: Map.get(@site_counts, user.id, 0)}
                </td>
                <td class="hidden py-3 pr-4 text-gray-500 dark:text-gray-400 md:table-cell">
                  {format_date(user.last_seen)}
                </td>
                <td class="py-3 text-right">
                  <Heroicons.chevron_right class="inline size-4 text-gray-300 group-hover:text-gray-500" />
                </td>
              </tr>
            </tbody>
          </table>
          <p :if={@users == []} class="py-8 text-center text-sm text-gray-500 dark:text-gray-400">
            No users match your search.
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
     |> assign(show_form?: not socket.assigns.show_form?, selected_sites: MapSet.new())
     |> assign_form(Admin.change_new_user())}
  end

  def handle_event("generate-password", _params, socket) do
    params = Map.put(socket.assigns.form.params, "password", generate_password())
    {:noreply, assign_form(socket, Admin.change_new_user(params))}
  end

  def handle_event("validate", %{"user" => params} = all, socket) do
    changeset = params |> Admin.change_new_user() |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(selected_sites: selected_sites(all))
     |> assign_form(changeset)}
  end

  def handle_event("create", %{"user" => params} = all, socket) do
    case Admin.create_user(params) do
      {:ok, user} ->
        if not user.platform_admin do
          site_roles = Map.new(selected_sites(all), &{&1, :viewer})
          {:ok, :ok} = Admin.set_site_access(user, site_roles)
        end

        {:noreply,
         socket
         |> put_flash(:success, "#{user.email} was created")
         |> push_navigate(to: ~p"/admin/users/#{user.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(selected_sites: selected_sites(all)) |> assign_form(changeset)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not create the user")}
    end
  end

  defp load(socket) do
    all_users = Admin.list_users()

    users =
      if socket.assigns.search == "",
        do: all_users,
        else: Admin.list_users(socket.assigns.search)

    assign(socket,
      all_users: all_users,
      users: users,
      sites: Admin.list_sites(),
      site_counts: Admin.site_counts_by_user()
    )
  end

  defp assign_form(socket, changeset), do: assign(socket, form: to_form(changeset, as: :user))

  defp selected_sites(params) do
    params
    |> Map.get("sites", [])
    |> Enum.map(&String.to_integer/1)
    |> MapSet.new()
  end

  defp admin_selected?(form) do
    form[:platform_admin].value in [true, "true"]
  end
end
