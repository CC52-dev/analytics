defmodule PlausibleWeb.Live.Admin.Auth do
  @moduledoc """
  LiveView `on_mount` hook that restricts the admin panel to platform admins,
  on the initial render as well as every WebSocket mount and reconnect.
  """

  import Phoenix.LiveView, only: [redirect: 2, put_flash: 3]
  import Phoenix.Component, only: [assign: 3]

  alias PlausibleWeb.UserAuth

  def on_mount(:default, _params, session, socket) do
    current_user =
      case UserAuth.get_user_session(session) do
        {:ok, %{user: user}} -> user
        _ -> nil
      end

    if Plausible.Auth.platform_admin?(current_user) do
      {:cont, assign(socket, :current_user, current_user)}
    else
      {:halt,
       socket
       |> put_flash(:error, "You don't have access to the admin panel")
       |> redirect(to: "/sites")}
    end
  end
end
