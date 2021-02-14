defmodule TpLinkHs100.Client do
  @moduledoc "Interact with a switch."

  alias TpLinkHs100.Device

  @spec refresh :: :ok
  def refresh do
    GenServer.cast(__MODULE__, :refresh)
  end

  @spec get_devices :: %{required(String.t()) => Device.t()}
  def get_devices do
    GenServer.call(__MODULE__, :get_devices)
  end

  @spec get_device(String.t()) :: {:ok, Device.t()} | :error
  def get_device(device_id) do
    devices = get_devices()
    Map.fetch(devices, device_id)
  end

  @spec add_handler(pid()) :: :ok
  def add_handler(handler) do
    GenServer.call(__MODULE__, {:handler, handler})
  end
end
