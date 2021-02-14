defmodule TpLinkHs100.Private do
  @moduledoc false
  alias TpLinkHs100.Encryption

  @spec ip_to_string({integer, integer, integer, integer}) :: String.t()
  def ip_to_string({ip1, ip2, ip3, ip4}), do: "#{ip1}.#{ip2}.#{ip3}.#{ip4}"

  @spec decrypt_and_parse(String.t()) :: map()
  def decrypt_and_parse(data), do: data |> Encryption.decrypt() |> Poison.decode!()

  @spec keyword_list_to_map(values :: list) :: map
  def keyword_list_to_map(values) do
    for {key, val} <- values, into: %{}, do: {key, val}
  end
end
