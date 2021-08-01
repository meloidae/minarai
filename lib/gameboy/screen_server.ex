defmodule ScreenServer do
  use GenServer

  # Client call
  def start_link() do
    GenServer.start_link(__MODULE__, [])
  end

  def write(pid, pixel) do
    GenServer.cast(pid, {:write, pixel})
  end

  def flush(pid) do
    GenServer.cast(pid, :flush)
  end

  def animate(pid) do
    GenServer.cast(pid, :animate_frame)
  end

  # Server (callbacks)

  @impl true
  def init(_default) do
    # {:ok, <<>>}
    {:ok, []}
  end

  @impl true
  def handle_cast({:write, pixel}, state) do
    # {:noreply, state <> pixel}
    {:noreply, [state | pixel]}
  end

  @impl true
  def handle_cast(:flush, _state) do
    # {:noreply, <<>>}
    {:noreply, []}
  end

  @impl true
  def handle_cast(:animate_frame, state) do
    # send(Info, {:animate_frame, state})
    # {:noreply, <<>>}
    send(Info, {:animate_frame, state |> IO.iodata_to_binary()})
    {:noreply, []}
  end

end
