defmodule TpLinkHs100.Switch.Private do
  @moduledoc false

  require Logger
  alias TpLinkHs100.Encryption

  # --- Internals

  defmodule State do
    @moduledoc false
    defstruct options: [],
              socket: nil,
              timer: nil,
              devices: %{}
  end

  def handle_response(%State{} = state, ip, port, data) do
    case decrypt_and_parse(data) do
      %{"system" => %{"get_sysinfo" => sysinfo}} ->
        set_device(state, ip_to_string(ip), port, sysinfo)

      %{"system" => %{"set_relay_state" => %{"err_code" => err_code}}} ->
        if err_code != 0 do
          Logger.error("Got error #{err_code}.")
        end

        state

      other ->
        IO.puts("unknown message to parse: #{inspect(other)}")
        state
    end
  end

  defp send_packet(%State{} = state, ip, packet) do
    :gen_udp.send(
      state.socket,
      to_charlist(ip),
      state.options[:broadcast_port],
      Encryption.encrypt(Poison.encode!(packet))
    )
  end

  def send_broadcast_packet(%State{} = state, packet) do
    send_packet(state, state.options[:broadcast_address], packet)
  end

  def send_targeted_packet(%State{} = state, id, packet) do
    case Map.fetch(state.devices, id) do
      {:ok, device} -> send_packet(state, device.ip, packet)
      :error -> {:error, "No such device id #{id}."}
    end
  end

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

  defp set_device(state, ip, port, %{"deviceId" => device_id} = sysinfo) do
    device_info = %{ip: ip, port: port, sysinfo: sysinfo}
    %{state | devices: Map.put(state.devices, device_id, device_info)}
  end

  defp ip_to_string({ip1, ip2, ip3, ip4}), do: "#{ip1}.#{ip2}.#{ip3}.#{ip4}"

  defp decrypt_and_parse(data), do: data |> Encryption.decrypt() |> Poison.decode!()
end
