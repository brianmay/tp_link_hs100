defmodule TpLinkHs100.Client.Server do
  @moduledoc false

  use GenServer
  require Logger

  alias TpLinkHs100.Client.Private
  alias TpLinkHs100.Client.Private.State

  @default_options [
    # Port used for broadcasts.
    broadcast_port: 9999,
    # Address used for broadcasts.
    broadcast_address: "192.168.5.255",
    # Sending broadcasts every milliseconds.
    refresh_interval: 5000
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: TpLinkHs100.Client)
  end

  @impl true
  @spec init(keyword) :: {:ok, TpLinkHs100.Client.Private.State.t()}
  def init(opts) do
    opts = Keyword.merge(@default_options, opts)

    {:ok, socket} = Private.create_udp_socket()

    {:ok, _} = :timer.send_interval(opts[:refresh_interval], :refresh)
    Process.send_after(self(), :refresh, 0)

    {:ok, %Private.State{options: opts, socket: socket}}
  end

  # --- Callbacks

  @impl true
  def handle_call(:get_devices, _from, %State{} = state) do
    {:reply, state.devices, state}
  end

  @impl true
  def handle_call({:handler, handler}, {_pid, _}, %State{} = state) do
    _ref = Process.monitor(handler)
    {:reply, :ok, %Private.State{state | handlers: [handler | state.handlers]}}
  end

  @impl true
  def handle_info({:udp, socket, ip, port, data}, %Private.State{socket: socket} = state) do
    state = Private.handle_response(state, ip, port, data)
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, %State{} = state) do
    {dead_devices, keep_devices} =
      Enum.split_with(state.devices, fn {_, %{pid: device_pid}} -> device_pid == pid end)

    handlers = Enum.reject(state.handlers, fn handler -> handler == pid end)

    Enum.each(dead_devices, fn {_, device} -> Private.notify(state, device, :deleted) end)

    keep_devices = TpLinkHs100.Private.keyword_list_to_map(keep_devices)
    state = %Private.State{state | handlers: handlers, devices: keep_devices}
    {:noreply, state}
  end

  @impl true
  def handle_info(:refresh, %State{} = state) do
    packet = %{"system" => %{"get_sysinfo" => %{}}}

    case Private.send_broadcast_packet(state, packet) do
      :ok -> nil
      {:error, error} -> Logger.error("Got send_broadcast_packet error #{inspect(error)}.")
    end

    {:noreply, state}
  end
end
