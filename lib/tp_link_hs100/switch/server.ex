defmodule TpLinkHs100.Switch.Server do
  @moduledoc false

  @default_options [
    # Port used for broadcasts.
    broadcast_port: 9999,
    # Address used for broadcasts.
    broadcast_address: "255.255.255.255",
    # Sending broadcasts every milliseconds.
    refresh_interval: 5000
  ]

  use GenServer
  require Logger

  alias TpLinkHs100.Switch.Private

  def init(opts) do
    opts = Keyword.merge(@default_options, opts)

    {:ok, socket} = Private.create_udp_socket()

    {:ok, timer} = :timer.apply_interval(opts[:refresh_interval], __MODULE__, :refresh, [self()])

    {:ok, %Private.State{options: opts, socket: socket, timer: timer}}
  end

  def refresh(process) do
    GenServer.cast(process, :refresh)
  end

  # --- Callbacks

  def handle_cast(:refresh, state) do
    packet = %{"system" => %{"get_sysinfo" => %{}}}

    case Private.send_broadcast_packet(state, packet) do
      :ok -> nil
      {:error, error} -> Logger.error("Got send_broadcast_packet error #{inspect(error)}.")
    end

    {:noreply, state}
  end

  def handle_cast({:off, id}, state) do
    packet = %{system: %{set_relay_state: %{state: 0}}}

    case Private.send_targeted_packet(state, id, packet) do
      :ok -> nil
      {:error, error} -> Logger.error("Got send_targeted_packet error #{inspect(error)}.")
    end

    {:noreply, state}
  end

  def handle_cast({:on, id}, state) do
    packet = %{system: %{set_relay_state: %{state: 1}}}

    case Private.send_targeted_packet(state, id, packet) do
      :ok -> nil
      {:error, error} -> Logger.error("Got send_targeted_packet error #{inspect(error)}.")
    end

    {:noreply, state}
  end

  def handle_call(:get_devices, _from, state) do
    resp = state.devices
    {:reply, resp, state}
  end

  def handle_info({:udp, socket, ip, port, data}, %Private.State{socket: socket} = state) do
    state = Private.handle_response(state, ip, port, data)
    {:noreply, state}
  end
end
