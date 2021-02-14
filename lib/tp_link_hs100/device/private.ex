defmodule TpLinkHs100.Device.Private do
  @moduledoc false

  require Logger
  alias TpLinkHs100.Private
  alias TpLinkHs100.Encryption

  # --- Internals

  defmodule State do
    @moduledoc false
    @type t :: %__MODULE__{
            id: String.t(),
            ip: String.t(),
            port: integer(),
            socket: port(),
            timer: pid() | nil,
            queue: Qex.t({GenServer.server(), boolean()})
          }
    defstruct [:id, :ip, :port, :socket, :timer, :queue]
  end

  @spec create_udp_socket() :: {:ok, port()} | {:error, atom()}
  def create_udp_socket do
    :gen_udp.open(0, [
      # Sending data as binary.
      :binary,
      # Disallowing broadcasts.
      {:broadcast, false},
      # New messages will be given to handle_info()
      {:active, true}
    ])
  end

  @spec switch(State.t(), boolean) :: :ok | {:error, String.t()}
  def switch(%State{} = state, power) do
    packet = %{system: %{set_relay_state: %{state: power}}}

    case send_targeted_packet(state, packet) do
      :ok -> :ok
      {:error, error} -> {:error, "Got send_targeted_packet error #{inspect(error)}."}
    end
  end

  # No timer set, check for next request
  @spec check_queue(State.t()) :: State.t()
  def check_queue(%State{timer: nil} = state) do
    case Qex.first(state.queue) do
      {:value, {_, power}} ->
        case switch(state, power) do
          :ok ->
            timer = Process.send_after(self(), :timer, 1_000)
            %State{state | timer: timer}

          {:error, error} ->
            send_response(state, {:error, error})
        end

      :empty ->
        state
    end
  end

  # time set, nothing to do
  def check_queue(%State{} = state), do: state

  @spec send_packet(State.t(), String.t(), integer, map()) :: :ok | {:error, atom()}
  defp send_packet(%State{} = state, ip, port, packet) do
    :gen_udp.send(
      state.socket,
      to_charlist(ip),
      port,
      Encryption.encrypt(Poison.encode!(packet))
    )
  end

  @spec send_targeted_packet(State.t(), map()) :: :ok | {:error, atom()}
  def send_targeted_packet(%State{} = state, packet) do
    send_packet(state, state.ip, state.port, packet)
  end

  @spec send_response(State.t(), :ok | {:error, String.t()}) :: State.t()
  def send_response(%State{} = state, response) do
    case Qex.pop(state.queue) do
      {{:value, {from, _}}, queue} ->
        GenServer.reply(from, response)
        %State{state | queue: queue}

      {:empty, queue} ->
        %State{state | queue: queue}
    end
  end

  @spec handle_timer(State.t()) :: State.t()
  def handle_timer(%State{} = state) do
    %State{state | timer: nil}
    |> send_response({:error, "The request timed out"})
    |> check_queue()
  end

  @spec handle_response(State.t(), {integer, integer, integer, integer}, integer(), String.t()) ::
          State.t()
  def handle_response(%State{} = state, ip, port, data) do
    state = %State{state | ip: Private.ip_to_string(ip), port: port}

    case Private.decrypt_and_parse(data) do
      %{"system" => %{"set_relay_state" => %{"err_code" => err_code}}} ->
        Process.cancel_timer(state.timer)

        response =
          if err_code == 0 do
            :ok
          else
            {:error, "Got error #{err_code}."}
          end

        %State{state | timer: nil} |> send_response(response) |> check_queue()

      other ->
        IO.puts("TpLinkHs100.Device.Private: Unknown message to parse: #{inspect(other)}")
        state
    end
  end
end
