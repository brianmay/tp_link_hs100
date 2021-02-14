defmodule TpLinkHs100.Device.Server do
  @moduledoc false

  use GenServer
  require Logger

  alias TpLinkHs100.Device.Private
  alias TpLinkHs100.Device.Private.State

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  @spec init(keyword) :: {:ok, TpLinkHs100.Device.Private.State.t()}
  def init(opts) do
    id = Keyword.fetch!(opts, :id)
    ip = Keyword.fetch!(opts, :ip)
    port = Keyword.fetch!(opts, :port)
    {:ok, socket} = Private.create_udp_socket()
    {:ok, %State{id: id, ip: ip, port: port, socket: socket, queue: Qex.new(), timer: nil}}
  end

  @impl true
  def handle_call({:switch, power}, from, state) do
    state = %State{state | queue: Qex.push(state.queue, {from, power})}
    state = Private.check_queue(state)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:update, ip, port}, %State{} = state) do
    state = %State{state | ip: ip, port: port}
    {:noreply, state}
  end

  @impl true
  def handle_info(:timer, %Private.State{} = state) do
    state = Private.handle_timer(state)

    # Don't stop process if pending requests
    if state.timer == nil do
      :gen_udp.close(state.socket)
      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:udp, socket, ip, port, data}, %Private.State{socket: socket} = state) do
    state = Private.handle_response(state, ip, port, data)
    {:noreply, state}
  end
end
