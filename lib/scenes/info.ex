defmodule Minarai.Scene.Info do
  use Scenic.Scene
  alias Scenic.Graph
  alias Scenic.ViewPort
  import Scenic.Primitives, only: [text: 3]

  # Constants
  @graph Graph.build(font: :roboto, font_size: 24)
  @frame_ms 192


  # Initalization
  def init(_arg, opts) do
    viewport = opts[:viewport]

    # Get viewport size
    {:ok, %ViewPort.Status{size: {vp_width, vp_height}}} = ViewPort.info(viewport)

    # Calculate text position (center of the screen)
    position = {0, vp_height / 2}

    # Start timer
    {:ok, timer} = :timer.send_interval(@frame_ms, :frame)

    gb = Gameboy.init()

    state = %{
      viewport: viewport,
      graph: @graph,
      gb: gb,
      position: position, # temp
      frame_timer: timer
    }

    graph = @graph
            |> text(inspect(gb.cpu), fill: :white, translate: position)

    {:ok, state, push: graph}
  end

  def handle_info(:frame, %{gb: gb, position: position} = state) do
    graph = state.graph
            |> print_info(gb.cpu, position)
    {:noreply, state, push: graph}
  end


  def handle_input({:key, {"enter", :press, _}}, _context, state) do
    gb = Gameboy.step(state.gb)
    {:noreply, put_in(state.gb, gb)}
  end

  def handle_input(_input, _context, state), do: {:noreply, state}

  def print_info(graph, cpu, position) do
    graph
    |> text(inspect(cpu), fill: :white, translate: position)
  end

end
