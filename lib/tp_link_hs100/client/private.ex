defmodule TpLinkHs100.Client.Private do
  @moduledoc false

  require Logger
  alias TpLinkHs100.Private
  alias TpLinkHs100.Encryption
  alias TpLinkHs100.Device

  # --- Internals

  defmodule State do
    @moduledoc false
    @type t :: %__MODULE__{
            options: keyword(),
            socket: port(),
            devices: %{required(String.t()) => pid()},
            handlers: list(pid())
          }
    defstruct options: [],
              socket: nil,
              devices: %{},
              handlers: []
  end

  @spec handle_response(State.t(), String.t(), integer(), String.t()) :: State.t()
  def handle_response(%State{} = state, ip, port, data) do
    case Private.decrypt_and_parse(data) do
      %{"system" => %{"get_sysinfo" => sysinfo}} ->
        update_device(state, Private.ip_to_string(ip), port, sysinfo)

      other ->
        IO.puts("TpLinkHs100.Client.Private: Unknown message to parse: #{inspect(other)}")
        state
    end
  end

  @spec send_packet(State.t(), String.t(), integer, map()) :: :ok | {:error, atom()}
  defp send_packet(%State{} = state, ip, port, packet) do
    :gen_udp.send(
      state.socket,
      to_charlist(ip),
      port,
      Encryption.encrypt(Poison.encode!(packet))
    )
  end

  @spec send_broadcast_packet(State.t(), map()) :: :ok | {:error, atom()}
  def send_broadcast_packet(%State{} = state, packet) do
    send_packet(state, state.options[:broadcast_address], state.options[:broadcast_port], packet)
  end

  # def send_targeted_packet(%State{} = state, id, packet) do
  #   case Map.fetch(state.devices, id) do
  #     {:ok, device} -> send_packet(state, device.ip, packet)
  #     :error -> {:error, "No such device id #{id}."}
  #   end
  # end

  @spec create_udp_socket() :: {:ok, port()} | {:error, atom()}
  def create_udp_socket do
    :gen_udp.open(0, [
      # Sending data as binary.
      :binary,
      # Allowing broadcasts.
      {:broadcast, true},
      # New messages will be given to handle_info()
      {:active, true}
    ])
  end

  @spec start_device(String.t(), integer, map()) :: Device.t()
  defp start_device(ip, port, %{"deviceId" => device_id} = sysinfo) do
    opts = [id: device_id, ip: ip, port: port]

    {:ok, pid} =
      DynamicSupervisor.start_child(TpLinkHs100.DeviceSupervisor, {Device.Server, opts})
      Process.monitor(pid)

    %Device{pid: pid, id: device_id, ip: ip, port: port, sysinfo: sysinfo}
  end

  @spec update_device(State.t(), String.t(), integer, map()) ::
          State.t()
  defp update_device(%State{} = state, ip, port, %{"deviceId" => device_id} = sysinfo) do
    device =
      case Map.fetch(state.devices, device_id) do
        {:ok, device} ->
          Logger.debug("TpLinkHs100.Client.Private: Updating device #{device_id}")
          Device.update_device(device, ip, port)
          device = %Device{device | ip: ip, port: port, sysinfo: sysinfo}
          notify(state, device, :updated)
          device

        :error ->
          Logger.debug("TpLinkHs100.Client.Private: Starting device #{device_id}")
          device = start_device(ip, port, sysinfo)
          notify(state, device, :added)
          device
      end

    %State{state | devices: Map.put(state.devices, device_id, device)}
  end

  @spec notify(State.t(), Device.t(), :added | :deleted | :updated) :: :ok
  def notify(%State{} = state, device, status) do
    Enum.each(state.handlers, fn handler ->
      GenServer.cast(handler, {status, device})
    end)
  end
end
