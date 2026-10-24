defmodule Plausible.Repo.Migrations.AddPlatformAdminToUsers do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add :platform_admin, :boolean, null: false, default: false
    end

    # On an existing instance, the earliest account becomes the first platform admin
    execute """
    UPDATE users SET platform_admin = true
    WHERE id = (SELECT min(id) FROM users)
    """
  end

  def down do
    alter table(:users) do
      remove :platform_admin
    end
  end
end
