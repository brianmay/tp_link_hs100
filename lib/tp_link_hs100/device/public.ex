defmodule TpLinkHs100.Device do
  @moduledoc "Interact with a device."

  @type t :: %__MODULE__{
          pid: pid(),
          id: String.t(),
          ip: String.t(),
          port: integer(),
          sysinfo: map()
        }
  @enforce_keys [:pid, :id, :ip, :port, :sysinfo]
  defstruct [:pid, :id, :ip, :port, :sysinfo]

  @spec update_device(TpLinkHs100.Device.t(), String.t(), integer) :: :ok
  def update_device(%TpLinkHs100.Device{pid: pid}, ip, port) do
    GenServer.cast(pid, {:update, ip, port})
  end

  @spec switch(TpLinkHs100.Device.t(), boolean) :: :ok | {:error, String.t()}
  def switch(%TpLinkHs100.Device{pid: pid, id: id}, power) do
    GenServer.call(pid, {:switch, power})
  catch
    :exit, value -> {:error, "The device #{id} is dead: #{inspect(value)}"}
  end

  @spec off(TpLinkHs100.Device.t()) :: :ok | {:error, String.t()}
  def off(%TpLinkHs100.Device{} = device) do
    switch(device, false)
  end

  @spec on(TpLinkHs100.Device.t()) :: :ok | {:error, String.t()}
  def on(%TpLinkHs100.Device{} = device) do
    switch(device, true)
  end
end
