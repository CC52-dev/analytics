defmodule PlausibleWeb.Live.Admin.User do
  @moduledoc """
  Admin panel: edit one user, reset their password, choose their site access
  or delete the account.
  """

  use PlausibleWeb, :live_view

  import PlausibleWeb.Live.Admin.Components

  alias Plausible.Admin

  def mount(%{"id" => id}, _session, socket) do
    user = Admin.get_user!(id)

    {:ok,
     socket
     |> assign(user: user, new_password: nil)
     |> assign_profile_form(Admin.change_user(user))
     |> load_access()}
  end

  def render(assigns) do
    ~H"""
    <.page active={:users} title={@user.name} subtitle={@user.email}>
      <:actions>
        <.button_link href={~p"/admin/users"} theme="secondary">
          <Heroicons.arrow_left class="size-4" /> All users
        </.button_link>
      </:actions>

      <div class="grid grid-cols-1 gap-6 lg:grid-cols-3">
        <div class="space-y-6 lg:col-span-2">
          <.card title="Site access">
            <div
              :if={@user.platform_admin}
              class="flex items-start gap-3 rounded-lg bg-indigo-50 p-4 text-sm text-indigo-800 dark:bg-indigo-500/10 dark:text-indigo-200"
            >
              <Heroicons.shield_check class="mt-0.5 size-5 shrink-0" />
              <div>Platform admins can see and manage every site, so per-site access doesn't apply.</div>
            </div>

            <form :if={not @user.platform_admin} phx-submit="save-access" class="space-y-4">
              <p class="text-sm text-gray-500 dark:text-gray-400">
                Tick the sites this user may open. <strong>Viewers</strong>
                see the dashboard only; <strong>editors</strong>
                can also change site settings such as goals.
              </p>
              <p :if={@sites == []} class="text-sm text-gray-500 dark:text-gray-400">
                There are no sites yet.
                <.link navigate={~p"/admin/sites?new=1"} class="text-indigo-600 hover:underline">
                  Add a site
                </.link>
              </p>
              <ul class="divide-y divide-gray-100 rounded-lg border border-gray-200 dark:divide-gray-800 dark:border-gray-700">
                <li :for={site <- @sites} class="flex items-center gap-3 px-4 py-3">
                  <input
                    type="checkbox"
                    id={"site-#{site.id}"}
                    name={"access[#{site.id}][enabled]"}
                    value="true"
                    checked={Map.has_key?(@guest_roles, site.id) or Map.has_key?(@team_roles, site.id)}
                    disabled={Map.has_key?(@team_roles, site.id)}
                    class="rounded border-gray-300 text-indigo-600 focus:ring-indigo-500 dark:border-gray-600 dark:bg-gray-800"
                  />
                  <label for={"site-#{site.id}"} class="flex-1 truncate text-sm text-gray-900 dark:text-gray-100">
                    {site.domain}
                  </label>
                  <span :if={Map.has_key?(@team_roles, site.id)} class="text-xs text-gray-500">
                    Team {role_label(@team_roles[site.id])}
                  </span>
                  <select
                    :if={not Map.has_key?(@team_roles, site.id)}
                    name={"access[#{site.id}][role]"}
                    class="rounded-md border-gray-300 py-1 pl-2 pr-8 text-sm focus:border-indigo-500 focus:ring-indigo-500 dark:border-gray-700 dark:bg-gray-800 dark:text-gray-100"
                  >
                    <option value="viewer" selected={@guest_roles[site.id] != :editor}>Viewer</option>
                    <option value="editor" selected={@guest_roles[site.id] == :editor}>Editor</option>
                  </select>
                </li>
              </ul>
              <div :if={@sites != []} class="flex justify-end">
                <.button type="submit">Save access</.button>
              </div>
            </form>
          </.card>

          <.card title="Profile">
            <.form for={@profile_form} phx-submit="save-profile" class="space-y-5">
              <div class="grid grid-cols-1 gap-5 sm:grid-cols-2">
                <.input field={@profile_form[:name]} label="Full name" />
                <.input field={@profile_form[:email]} type="email" label="Email" />
              </div>
              <.input
                field={@profile_form[:platform_admin]}
                type="checkbox"
                label="Platform admin"
                disabled={@user.id == @current_user.id or @founder?}
              />
              <p :if={@founder?} class="text-xs text-gray-500 dark:text-gray-400">
                This is the founding admin account that owns all sites, so it always stays an admin.
              </p>
              <div class="flex justify-end">
                <.button type="submit">Save profile</.button>
              </div>
            </.form>
          </.card>
        </div>

        <div class="space-y-6">
          <.card title="Account">
            <dl class="space-y-3 text-sm">
              <div class="flex justify-between gap-4">
                <dt class="text-gray-500 dark:text-gray-400">Role</dt>
                <dd>
                  <.badge :if={@user.platform_admin} kind={:admin}>Platform admin</.badge>
                  <.badge :if={not @user.platform_admin} kind={:customer}>Customer</.badge>
                </dd>
              </div>
              <div class="flex justify-between gap-4">
                <dt class="text-gray-500 dark:text-gray-400">Created</dt>
                <dd class="text-gray-900 dark:text-gray-100">{format_date(@user.inserted_at)}</dd>
              </div>
              <div class="flex justify-between gap-4">
                <dt class="text-gray-500 dark:text-gray-400">Last seen</dt>
                <dd class="text-gray-900 dark:text-gray-100">{format_date(@user.last_seen)}</dd>
              </div>
              <div class="flex justify-between gap-4">
                <dt class="text-gray-500 dark:text-gray-400">Two-factor auth</dt>
                <dd class="text-gray-900 dark:text-gray-100">
                  {if @user.totp_enabled, do: "On", else: "Off"}
                </dd>
              </div>
            </dl>
          </.card>

          <.card title="Password">
            <form phx-submit="set-password" class="space-y-3">
              <p class="text-sm text-gray-500 dark:text-gray-400">
                Set a new password for this user. Their other sessions stay signed in.
              </p>
              <input
                type="text"
                name="password"
                value={@new_password}
                minlength="12"
                required
                autocomplete="new-password"
                placeholder="New password (12+ characters)"
                class="block w-full rounded-md border-gray-300 text-sm shadow-sm focus:border-indigo-500 focus:ring-indigo-500 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-100"
              />
              <div class="flex justify-between gap-2">
                <.button type="button" theme="secondary" phx-click="generate-password">
                  Generate
                </.button>
                <.button type="submit">Set password</.button>
              </div>
            </form>
          </.card>

          <.card :if={@user.id != @current_user.id and not @founder?} title="Danger zone">
            <p class="text-sm text-gray-500 dark:text-gray-400">
              Deleting this user removes their account and access. Sites stay in place.
            </p>
            <button
              type="button"
              phx-click="delete"
              data-confirm={"Delete #{@user.email}? This can't be undone."}
              class="mt-4 inline-flex items-center gap-2 rounded-md bg-red-600 px-3.5 py-2 text-sm font-medium text-white shadow-sm hover:bg-red-700"
            >
              <Heroicons.trash class="size-4" /> Delete user
            </button>
          </.card>
        </div>
      </div>
    </.page>
    """
  end

  def handle_event("save-access", params, socket) do
    selected =
      for {site_id, entry} <- Map.get(params, "access", %{}),
          entry["enabled"] == "true",
          into: %{} do
        {String.to_integer(site_id), if(entry["role"] == "editor", do: :editor, else: :viewer)}
      end

    # Team members already see their team's sites; only per-site guest access is managed here
    site_roles = Map.drop(selected, Map.keys(socket.assigns.team_roles))

    {:ok, :ok} = Admin.set_site_access(socket.assigns.user, site_roles)

    {:noreply, socket |> load_access() |> put_flash(:success, "Site access saved")}
  end

  def handle_event("save-profile", %{"user" => params}, socket) do
    params =
      if socket.assigns.user.id == socket.assigns.current_user.id,
        do: Map.delete(params, "platform_admin"),
        else: params

    case Admin.update_user(socket.assigns.user, params) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign(user: user)
         |> assign_profile_form(Admin.change_user(user))
         |> load_access()
         |> put_flash(:success, "Profile saved")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_profile_form(socket, changeset)}
    end
  end

  def handle_event("generate-password", _params, socket) do
    {:noreply, assign(socket, new_password: generate_password())}
  end

  def handle_event("set-password", %{"password" => password}, socket) do
    case Admin.set_password(socket.assigns.user, password) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign(user: user, new_password: nil)
         |> put_flash(:success, "Password updated. Share it with the user securely.")}

      {:error, changeset} ->
        message =
          Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
          |> Map.get(:password, ["is invalid"])
          |> Enum.join(", ")

        {:noreply, socket |> assign(new_password: password) |> put_flash(:error, "Password #{message}")}
    end
  end

  def handle_event("delete", _params, socket) do
    case Admin.delete_user(socket.assigns.user, socket.assigns.current_user) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:success, "#{socket.assigns.user.email} was deleted")
         |> push_navigate(to: ~p"/admin/users")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Could not delete the user (#{inspect(reason)})")}
    end
  end

  defp load_access(socket) do
    access = Admin.site_access(socket.assigns.user)

    assign(socket,
      sites: Admin.list_sites(),
      founder?: Admin.founder?(socket.assigns.user),
      guest_roles: for({site, role, :guest} <- access, into: %{}, do: {site.id, role}),
      team_roles: for({site, role, :team} <- access, into: %{}, do: {site.id, role})
    )
  end

  defp assign_profile_form(socket, changeset) do
    assign(socket, profile_form: to_form(changeset, as: :user))
  end
end
