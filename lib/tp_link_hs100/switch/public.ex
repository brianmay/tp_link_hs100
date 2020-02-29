defmodule TpLinkHs100.Switch do
  def start_link(opts \\ []) do
    GenServer.start_link(TpLinkHs100.Switch.Server, opts, name: __MODULE__)
  end

  def refresh() do
    GenServer.cast(__MODULE__, :refresh)
  end

  def off(id) do
    GenServer.cast(__MODULE__, {:off, id})
  end

  def on(id) do
    GenServer.cast(__MODULE__, {:on, id})
  end

  def devices do
    GenServer.call(__MODULE__, :get_devices)
  end
end
