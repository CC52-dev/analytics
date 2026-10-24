defmodule PlausibleWeb.Live.Admin.Site do
  @moduledoc """
  Admin panel: one site, the users who can see it, and granting or revoking access.
  """

  use PlausibleWeb, :live_view

  import PlausibleWeb.Live.Admin.Components

  alias Plausible.Admin

  def mount(%{"id" => id}, _session, socket) do
    {:ok, socket |> assign(site: Admin.get_site!(id)) |> load()}
  end

  def render(assigns) do
    ~H"""
    <.page active={:sites} title={@site.domain} subtitle={"Timezone: #{@site.timezone}"}>
      <:actions>
        <.button_link href={~p"/admin/sites"} theme="secondary">
          <Heroicons.arrow_left class="size-4" /> All sites
        </.button_link>
        <.button_link href={"/#{URI.encode_www_form(@site.domain)}"}>
          <Heroicons.chart_bar class="size-4" /> Open dashboard
        </.button_link>
      </:actions>

      <div class="grid grid-cols-1 gap-6 lg:grid-cols-3">
        <div class="space-y-6 lg:col-span-2">
          <.card title="Who can see this site">
            <ul class="divide-y divide-gray-100 dark:divide-gray-800">
              <li :for={{user, role, source} <- @users} class="flex items-center gap-3 py-3">
                <.avatar name={user.name || user.email} />
                <div class="min-w-0 flex-1">
                  <.link
                    navigate={~p"/admin/users/#{user.id}"}
                    class="block truncate text-sm font-medium text-gray-900 hover:text-indigo-600 dark:text-gray-100"
                  >
                    {user.name}
                  </.link>
                  <div class="truncate text-sm text-gray-500 dark:text-gray-400">{user.email}</div>
                </div>

                <%= if source == :team do %>
                  <.badge kind={:admin}>{role_label(role)}</.badge>
                <% else %>
                  <form phx-change="change-role" class="shrink-0">
                    <input type="hidden" name="user_id" value={user.id} />
                    <select
                      name="role"
                      class="rounded-md border-gray-300 py-1 pl-2 pr-8 text-sm focus:border-indigo-500 focus:ring-indigo-500 dark:border-gray-700 dark:bg-gray-800 dark:text-gray-100"
                    >
                      <option value="viewer" selected={role == :viewer}>Viewer</option>
                      <option value="editor" selected={role == :editor}>Editor</option>
                    </select>
                  </form>
                  <button
                    type="button"
                    phx-click="revoke"
                    phx-value-user_id={user.id}
                    data-confirm={"Remove #{user.email}'s access to #{@site.domain}?"}
                    class="rounded-md p-1.5 text-gray-400 hover:bg-red-50 hover:text-red-600 dark:hover:bg-red-500/10"
                    aria-label="Remove access"
                  >
                    <Heroicons.x_mark class="size-5" />
                  </button>
                <% end %>
              </li>
            </ul>

            <form
              :if={@available_users != []}
              phx-submit="grant"
              class="mt-4 flex flex-col gap-2 border-t border-gray-100 pt-4 dark:border-gray-800 sm:flex-row"
            >
              <select
                name="user_id"
                required
                class="flex-1 rounded-md border-gray-300 text-sm focus:border-indigo-500 focus:ring-indigo-500 dark:border-gray-700 dark:bg-gray-800 dark:text-gray-100"
              >
                <option value="">Add a customer…</option>
                <option :for={user <- @available_users} value={user.id}>
                  {user.name} ({user.email})
                </option>
              </select>
              <select
                name="role"
                class="rounded-md border-gray-300 text-sm focus:border-indigo-500 focus:ring-indigo-500 dark:border-gray-700 dark:bg-gray-800 dark:text-gray-100"
              >
                <option value="viewer">Viewer</option>
                <option value="editor">Editor</option>
              </select>
              <.button type="submit">Give access</.button>
            </form>
            <p
              :if={@available_users == []}
              class="mt-4 border-t border-gray-100 pt-4 text-sm text-gray-500 dark:border-gray-800 dark:text-gray-400"
            >
              Every customer already has access.
              <.link navigate={~p"/admin/users?new=1"} class="text-indigo-600 hover:underline">
                Create a new user
              </.link>
            </p>
          </.card>
        </div>

        <div class="space-y-6">
          <.card title="Setup">
            <ul class="space-y-1 text-sm">
              <li>
                <a
                  href={"/#{URI.encode_www_form(@site.domain)}/installation"}
                  class="flex items-center gap-2 rounded-md px-2 py-2 text-gray-700 hover:bg-gray-50 dark:text-gray-300 dark:hover:bg-gray-800"
                >
                  <Heroicons.code_bracket class="size-4 text-gray-400" /> Tracking snippet
                </a>
              </li>
              <li>
                <a
                  href={"/#{URI.encode_www_form(@site.domain)}/settings/general"}
                  class="flex items-center gap-2 rounded-md px-2 py-2 text-gray-700 hover:bg-gray-50 dark:text-gray-300 dark:hover:bg-gray-800"
                >
                  <Heroicons.cog_6_tooth class="size-4 text-gray-400" /> Site settings
                </a>
              </li>
              <li>
                <a
                  href={"/#{URI.encode_www_form(@site.domain)}/settings/goals"}
                  class="flex items-center gap-2 rounded-md px-2 py-2 text-gray-700 hover:bg-gray-50 dark:text-gray-300 dark:hover:bg-gray-800"
                >
                  <Heroicons.flag class="size-4 text-gray-400" /> Goals
                </a>
              </li>
            </ul>
          </.card>

          <.card title="Danger zone">
            <p class="text-sm text-gray-500 dark:text-gray-400">
              Deleting the site permanently removes it and all of its analytics data.
            </p>
            <button
              type="button"
              phx-click="delete"
              data-confirm={"Permanently delete #{@site.domain} and all of its stats? This can't be undone."}
              class="mt-4 inline-flex items-center gap-2 rounded-md bg-red-600 px-3.5 py-2 text-sm font-medium text-white shadow-sm hover:bg-red-700"
            >
              <Heroicons.trash class="size-4" /> Delete site
            </button>
          </.card>
        </div>
      </div>
    </.page>
    """
  end

  def handle_event("grant", %{"user_id" => user_id, "role" => role}, socket) do
    user = Admin.get_user!(user_id)
    {:ok, _} = Admin.grant_access(user, socket.assigns.site, parse_role(role))
    {:noreply, socket |> load() |> put_flash(:success, "#{user.email} can now see this site")}
  end

  def handle_event("change-role", %{"user_id" => user_id, "role" => role}, socket) do
    user = Admin.get_user!(user_id)
    {:ok, _} = Admin.grant_access(user, socket.assigns.site, parse_role(role))
    {:noreply, socket |> load() |> put_flash(:success, "Role updated")}
  end

  def handle_event("revoke", %{"user_id" => user_id}, socket) do
    user = Admin.get_user!(user_id)
    {:ok, _} = Admin.revoke_access(user, socket.assigns.site)
    {:noreply, socket |> load() |> put_flash(:success, "Access removed")}
  end

  def handle_event("delete", _params, socket) do
    {:ok, _} = Admin.delete_site(socket.assigns.site)

    {:noreply,
     socket
     |> put_flash(:success, "#{socket.assigns.site.domain} was deleted")
     |> push_navigate(to: ~p"/admin/sites")}
  end

  defp load(socket) do
    users = Admin.site_users(socket.assigns.site)
    with_access = MapSet.new(users, fn {user, _, _} -> user.id end)

    available =
      Admin.list_users()
      |> Enum.reject(&(&1.platform_admin or MapSet.member?(with_access, &1.id)))

    assign(socket, users: users, available_users: available)
  end

  defp parse_role("editor"), do: :editor
  defp parse_role(_), do: :viewer
end
