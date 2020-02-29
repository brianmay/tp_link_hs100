defmodule TpLinkHs100.Switch.Private do
  require Logger
  alias TpLinkHs100.Encryption

  #--- Internals

  defmodule State do
    defstruct [
      options: [],
      socket: nil,
      timer: nil,
      devices: %{},
    ]
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
        IO.puts "unknown message to parse"
        IO.inspect(other)
        state
    end
  end

  def create_udp_socket() do
    :gen_udp.open(0, [
     :binary, # Sending data as binary.
     {:broadcast, true}, # Allowing broadcasts.
     {:active, true}, # New messages will be given to handle_info()
   ])
 end

  defp set_device(state, ip, port, %{"deviceId" => device_id} = sysinfo) do
    device_info = %{ip: ip, port: port, sysinfo: sysinfo}
    %{state|
      devices: Map.put(state.devices, device_id, device_info)
    }
  end

  defp ip_to_string({ip1, ip2, ip3, ip4}), do: "#{ip1}.#{ip2}.#{ip3}.#{ip4}"

  defp decrypt_and_parse(data), do: data |> Encryption.decrypt |> Poison.decode!

end
