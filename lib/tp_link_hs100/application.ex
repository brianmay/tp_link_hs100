defmodule TpLinkHs100.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      {TpLinkHs100.Client.Server, []},
      {DynamicSupervisor, name: TpLinkHs100.DeviceSupervisor, strategy: :one_for_one}
    ]

    opts = [strategy: :one_for_one, name: TpLinkHs100.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
