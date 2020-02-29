defmodule TpLinkHs100.Encryption do
  @moduledoc "Encryption of messages send via UDP to TP-Link devices."

  @doc """
  Encrypting a given binary.
  """
  def encrypt(input, firstKey \\ 0xAB) when is_binary(input) and firstKey in 0..255,
    do: do_encrypt(firstKey, input, [])

  defp do_encrypt(_key, <<>>, output) do
    output
    |> Enum.reverse()
    |> :binary.list_to_bin()
  end

  defp do_encrypt(key, <<byte, rest::binary>>, output) do
    use Bitwise

    byte_xor = bxor(byte, key)

    do_encrypt(
      # new key
      byte_xor,
      # encrypt rest of binary
      rest,
      # reverse list of encrypted bytes
      [byte_xor | output]
    )
  end

  @doc """
  Decrypting a encrypted binary.
  """
  def decrypt(input, firstKey \\ 0x2B) when is_binary(input) and firstKey in 0..255,
    do: do_decrypt(firstKey, input, [])

  defp do_decrypt(_key, <<>>, output) do
    output
    |> Enum.reverse()
    |> :binary.list_to_bin()
  end

  defp do_decrypt(key, <<byte, rest::binary>>, output) do
    use Bitwise

    # this encryption does only support ASCII, so there are no bytes > 127
    byte_xor = rem(bxor(byte, key), 128)

    do_decrypt(
      # new key
      byte,
      # rest of bytes to decrypt
      rest,
      # reversed list of plain bytes.
      [byte_xor | output]
    )
  end
end
