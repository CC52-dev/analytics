defmodule PlausibleWeb.Brand do
  @moduledoc """
  White-label branding values shown to users (names, contact details, links).

  Every value can be overridden through `config :plausible, PlausibleWeb.Brand`
  (see `config/runtime.exs` for the matching environment variables).
  """

  @defaults [
    name: "SBC",
    product_name: "SBC Analytics",
    legal_name: "SBC CREATIVE LLC",
    support_email: "admin@sbc-creative.com",
    website_url: "https://sbc-creative.com",
    # Base URL for the "Learn more" help icons in settings; hidden when not set
    docs_url: nil,
    # AGPL-3.0 requires offering the modified source to users of the service
    source_code_url: nil
  ]

  for {key, _} <- @defaults do
    def unquote(key)(), do: get(unquote(key))
  end

  def mail_from_name, do: get(:mail_from_name) || product_name()

  def support_mailto, do: "mailto:" <> support_email()

  def copyright, do: "© #{Date.utc_today().year} #{legal_name()}"

  defp get(key) do
    config = Application.get_env(:plausible, __MODULE__, [])
    Keyword.get(config, key) || Keyword.get(@defaults, key)
  end
end
