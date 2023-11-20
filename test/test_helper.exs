{:ok, _} = Application.ensure_all_started(:ex_machina)
Mox.defmock(Plausible.HTTPClient.Mock, for: Plausible.HTTPClient.Interface)
Application.ensure_all_started(:double)
FunWithFlags.enable(:business_tier)
FunWithFlags.enable(:window_time_on_page)
Ecto.Adapters.SQL.Sandbox.mode(Plausible.Repo, :manual)
ExUnit.configure(exclude: [:slow])