defmodule Minarai.Scene.Info do
  use Scenic.Scene
  alias Scenic.Graph
  alias Scenic.ViewPort
  import Scenic.Primitives, only: [text: 3]

  alias Gameboy.CPU

  # Constants
  @graph Graph.build(font: :roboto, font_size: 24)


  # Initalization
  def init(_arg, opts) do
    viewport = opts[:viewport]

    # Get viewport size
    {:ok, %ViewPort.Status{size: {vp_width, vp_height}}} = ViewPort.info(viewport)

    # Calculate text position (center of the screen)
    position = {0, vp_height / 2}

    cpu = CPU.init()

    state = %{
      viewport: viewport,
      graph: @graph,
      cpu: cpu,
    }

    graph = @graph
            |> text(inspect(cpu), fill: :white, translate: position)

    {:ok, state, push: graph}
  end


end
