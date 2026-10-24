defmodule Plausible.Admin do
  @moduledoc """
  Platform administration: managing every user, site and per-site permission
  on this instance, used by the admin panel at `/admin`.

  Model:

    * All sites created from the admin panel live in a single "platform team".
      Platform admins are admins of that team, so they see every site.
    * Customers are guest members of a site's team, with a guest membership
      (viewer or editor) for each site they may see. They see nothing else.
  """

  import Ecto.Query

  alias Plausible.{Auth, Repo, Site, Sites, Teams}

  @platform_team_name "SBC"

  # Users

  def list_users(search \\ "") do
    from(u in Auth.User, order_by: [desc: u.platform_admin, asc: u.email])
    |> search_users(search)
    |> Repo.all()
  end

  defp search_users(query, search) do
    case String.trim(search || "") do
      "" ->
        query

      term ->
        pattern = "%" <> escape_like(term) <> "%"
        where(query, [u], ilike(u.email, ^pattern) or ilike(u.name, ^pattern))
    end
  end

  def get_user!(id), do: Repo.get!(Auth.User, id)

  @doc "Number of sites each user can see through guest access, keyed by user id."
  def site_counts_by_user do
    from(tm in Teams.Membership,
      join: gm in assoc(tm, :guest_memberships),
      group_by: tm.user_id,
      select: {tm.user_id, count(gm.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  def change_new_user(attrs \\ %{}), do: Auth.User.admin_create_changeset(attrs)

  def create_user(attrs) do
    Repo.transaction(fn ->
      with {:ok, user} <- Repo.insert(Auth.User.admin_create_changeset(attrs)),
           :ok <- sync_platform_admin(user) do
        user
      else
        {:error, error} -> Repo.rollback(error)
      end
    end)
  end

  def change_user(user, attrs \\ %{}), do: Auth.User.admin_update_changeset(user, attrs)

  def update_user(user, attrs) do
    changeset = Auth.User.admin_update_changeset(user, attrs)

    if founder?(user) and Ecto.Changeset.get_change(changeset, :platform_admin) == false do
      {:error, Ecto.Changeset.add_error(changeset, :platform_admin, "the founding admin can't be demoted")}
    else
      do_update_user(user, attrs)
    end
  end

  defp do_update_user(user, attrs) do
    Repo.transaction(fn ->
      with {:ok, user} <- Repo.update(Auth.User.admin_update_changeset(user, attrs)),
           :ok <- sync_platform_admin(user) do
        user
      else
        {:error, error} -> Repo.rollback(error)
      end
    end)
  end

  def set_password(user, password) do
    user
    |> Auth.User.admin_password_changeset(password)
    |> Repo.update()
  end

  def delete_user(%Auth.User{} = user, %Auth.User{} = acting_admin) do
    cond do
      user.id == acting_admin.id -> {:error, :cannot_delete_self}
      founder?(user) -> {:error, :cannot_delete_founder}
      true ->
        Auth.delete_user(user)
    end
  end

  @doc "The earliest platform admin owns the platform team, so they can't be demoted or deleted."
  def founder?(%Auth.User{id: id}) do
    match?(%Auth.User{id: ^id}, founder())
  end

  defp founder do
    from(u in Auth.User, where: u.platform_admin, order_by: [asc: u.id], limit: 1)
    |> Repo.one()
  end

  def platform_admins_count do
    Repo.aggregate(from(u in Auth.User, where: u.platform_admin), :count)
  end

  # Platform admins get admin access to the platform team so they can see and
  # manage every site; demoted admins lose that team membership again.
  defp sync_platform_admin(%Auth.User{platform_admin: true} = user) do
    with {:ok, team} <- platform_team() do
      case Teams.Memberships.team_role(team, user) do
        {:ok, role} when role in [:owner, :admin] ->
          :ok

        _ ->
          {:ok, _} =
            Teams.Invitations.create_team_membership(
              team,
              :admin,
              user,
              NaiveDateTime.utc_now(:second)
            )

          # A guest promoted to admin: upgrade the role and drop the guest grants
          Repo.update_all(
            from(tm in Teams.Membership,
              where: tm.team_id == ^team.id and tm.user_id == ^user.id and tm.role == :guest
            ),
            set: [role: :admin]
          )

          Repo.delete_all(
            from(gm in Teams.GuestMembership,
              join: tm in assoc(gm, :team_membership),
              where: tm.team_id == ^team.id and tm.user_id == ^user.id
            )
          )

          :ok
      end
    end
  end

  defp sync_platform_admin(%Auth.User{} = user) do
    with {:ok, team} <- platform_team() do
      Repo.delete_all(
        from(tm in Teams.Membership,
          where: tm.team_id == ^team.id and tm.user_id == ^user.id and tm.role == :admin
        )
      )

      :ok
    end
  end

  # Sites

  def list_sites(search \\ "") do
    from(s in Site, where: not s.consolidated, order_by: [asc: s.domain], preload: [:team])
    |> search_sites(search)
    |> Repo.all()
  end

  defp search_sites(query, search) do
    case String.trim(search || "") do
      "" ->
        query

      term ->
        where(query, [s], ilike(s.domain, ^("%" <> escape_like(term) <> "%")))
    end
  end

  def get_site!(id), do: Site |> Repo.get!(id) |> Repo.preload(:team)

  @doc "Number of guest users with access to each site, keyed by site id."
  def user_counts_by_site do
    from(gm in Teams.GuestMembership, group_by: gm.site_id, select: {gm.site_id, count(gm.id)})
    |> Repo.all()
    |> Map.new()
  end

  def change_new_site(attrs \\ %{}), do: Site.changeset(%Site{}, attrs)

  def create_site(%Auth.User{} = acting_admin, attrs) do
    with {:ok, team} <- platform_team(),
         :ok <- sync_platform_admin(acting_admin) do
      case Sites.create(acting_admin, attrs, team) do
        {:ok, %{site: site}} -> {:ok, site}
        {:error, _step, %Ecto.Changeset{} = changeset, _} -> {:error, changeset}
        {:error, _step, reason, _} -> {:error, reason}
      end
    end
  end

  def delete_site(%Site{} = site), do: Site.Removal.run(site)

  # Access

  @doc """
  Sites a user can see, as `{site, role, source}` tuples, where `source` is
  `:guest` for access granted per site and `:team` for team-wide access.
  """
  def site_access(%Auth.User{} = user) do
    guest =
      from(gm in Teams.GuestMembership,
        join: tm in assoc(gm, :team_membership),
        join: s in assoc(gm, :site),
        where: tm.user_id == ^user.id,
        select: {s, gm.role, :guest}
      )
      |> Repo.all()

    team =
      from(tm in Teams.Membership,
        join: s in Site,
        on: s.team_id == tm.team_id,
        where: tm.user_id == ^user.id and tm.role != :guest and not s.consolidated,
        select: {s, tm.role, :team}
      )
      |> Repo.all()

    Enum.sort_by(team ++ guest, fn {site, _, _} -> site.domain end)
  end

  @doc "Users who can see a site, as `{user, role, source}` tuples."
  def site_users(%Site{} = site) do
    guest =
      from(gm in Teams.GuestMembership,
        join: tm in assoc(gm, :team_membership),
        join: u in assoc(tm, :user),
        where: gm.site_id == ^site.id,
        select: {u, gm.role, :guest}
      )
      |> Repo.all()

    team =
      from(tm in Teams.Membership,
        join: u in assoc(tm, :user),
        where: tm.team_id == ^site.team_id and tm.role != :guest,
        select: {u, tm.role, :team}
      )
      |> Repo.all()

    Enum.sort_by(team ++ guest, fn {user, _, source} -> {source, user.email} end)
  end

  @doc """
  Gives a user access to one site with the given role (`:viewer` or `:editor`),
  without sending an invitation. Members of the site's team already see it.
  """
  def grant_access(%Auth.User{} = user, %Site{} = site, role) when role in [:viewer, :editor] do
    site = Repo.preload(site, :team)
    now = NaiveDateTime.utc_now(:second)

    Repo.transaction(fn ->
      {:ok, team_membership} =
        Teams.Invitations.create_team_membership(site.team, :guest, user, now)

      if team_membership.role == :guest do
        team_membership
        |> Teams.GuestMembership.changeset(site, role)
        |> Repo.insert!(
          on_conflict: [set: [role: role, updated_at: now]],
          conflict_target: [:team_membership_id, :site_id]
        )

        :granted
      else
        :team_member
      end
    end)
  end

  def revoke_access(%Auth.User{} = user, %Site{} = site) do
    site = Repo.preload(site, :team)

    Repo.transaction(fn ->
      Repo.delete_all(
        from(gm in Teams.GuestMembership,
          join: tm in assoc(gm, :team_membership),
          where: gm.site_id == ^site.id and tm.user_id == ^user.id
        )
      )

      Teams.Memberships.prune_guests(site.team)
    end)
  end

  @doc "Grants and revokes guest access so the user sees exactly `site_roles` (`%{site_id => role}`)."
  def set_site_access(%Auth.User{} = user, site_roles) when is_map(site_roles) do
    current =
      for {site, role, :guest} <- site_access(user), into: %{}, do: {site.id, role}

    Repo.transaction(fn ->
      for {site_id, _} <- current, not Map.has_key?(site_roles, site_id) do
        revoke_access(user, get_site!(site_id))
      end

      for {site_id, role} <- site_roles, Map.get(current, site_id) != role do
        grant_access(user, get_site!(site_id), role)
      end

      :ok
    end)
  end

  # Platform team

  @doc """
  The team that owns every site created from the admin panel. It belongs to the
  earliest platform admin and is created (and named) on first use.
  """
  def platform_team do
    with %Auth.User{} = founder <- founder(),
         {:ok, team} <- founder_team(founder) do
      {:ok, team}
    else
      nil -> {:error, :no_platform_admin}
      error -> error
    end
  end

  defp founder_team(founder) do
    case Teams.get_by_owner(founder) do
      {:ok, team} -> {:ok, ensure_named(team)}
      {:error, :multiple_teams} -> {:ok, founder |> Teams.Users.owned_teams() |> hd()}
      {:error, :no_team} -> with {:ok, team} <- Teams.get_or_create(founder), do: {:ok, ensure_named(team)}
    end
  end

  defp ensure_named(%Teams.Team{setup_complete: true} = team), do: team

  defp ensure_named(team) do
    team
    |> Teams.Team.name_changeset(%{name: @platform_team_name})
    |> Repo.update!()
    |> Teams.complete_setup()
  end

  defp escape_like(term), do: String.replace(term, ~r/[\\%_]/, "\\\\\\0")
end
