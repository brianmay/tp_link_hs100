defmodule TpLinkHs100.Device.Server do
  @moduledoc false

  use GenServer
  require Logger

  alias TpLinkHs100.Device.Private
  alias TpLinkHs100.Device.Private.State

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  defp get_dead_time, do: Application.get_env(:tp_link_hs100, :dead_time)

  @impl true
  @spec init(keyword) :: {:ok, TpLinkHs100.Device.Private.State.t()}
  def init(opts) do
    id = Keyword.fetch!(opts, :id)
    ip = Keyword.fetch!(opts, :ip)
    port = Keyword.fetch!(opts, :port)
    dead_timer = Process.send_after(self(), :dead, get_dead_time())
    {:ok, socket} = Private.create_udp_socket()

    {:ok,
     %State{
       id: id,
       ip: ip,
       port: port,
       socket: socket,
       queue: Qex.new(),
       dead_timer: dead_timer
     }}
  end

  @spec prefix(State.t()) :: String.t()
  defp prefix(state) do
    "TpLinkHs100.Device.Server #{state.id}:"
  end

  @impl true
  def handle_call({:switch, power}, from, state) do
    Logger.debug("#{prefix(state)} Got switch request")
    state = %State{state | queue: Qex.push(state.queue, {from, power})}
    state = Private.check_queue(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:update, ip, port}, %State{} = state) do
    Logger.debug("#{prefix(state)} Got update")
    Process.cancel_timer(state.dead_timer)
    dead_timer = Process.send_after(self(), :dead, get_dead_time())
    state = %State{state | ip: ip, port: port, dead_timer: dead_timer}
    {:noreply, state}
  end

  @impl true
  def handle_info(:timer, %Private.State{} = state) do
    Logger.debug("#{prefix(state)} Got timeout")
    state = Private.handle_timer(state)
    {:noreply, state}
  end

  @impl true
  def handle_info({:udp, socket, ip, port, data}, %Private.State{socket: socket} = state) do
    Logger.debug("#{prefix(state)} Got packet")
    Process.cancel_timer(state.dead_timer)
    dead_timer = Process.send_after(self(), :dead, get_dead_time())
    state = %State{state | dead_timer: dead_timer}
    state = Private.handle_response(state, ip, port, data)
    {:noreply, state}
  end

  def handle_info(:dead, %State{} = state) do
    Logger.debug("#{prefix(state)} Got dead")
    {:stop, :normal, state}
  end
end
