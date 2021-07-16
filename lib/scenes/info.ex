defmodule Minarai.Scene.Info do
  import ExProf.Macro
  use Scenic.Scene
  alias Scenic.Graph
  alias Scenic.ViewPort
  import Scenic.Primitives, only: [text: 3, rect: 3]
  alias Scenic.Utilities.Texture
  alias Scenic.Cache.Dynamic.Texture, as: Cache

  alias Gameboy.Utils
  alias Gameboy.Ppu

  # Constants
  @graph Graph.build(font: :roboto, font_size: 24)
  @frame_ms 192
  @pixel_size 2
  @screen_width 160
  @screen_height 144
  

  # Initalization
  def init(_arg, opts) do
    viewport = opts[:viewport]

    screen = Texture.build!(:rgb, 256 * @pixel_size, 256 * @pixel_size, clear: {155, 188, 15})
    Cache.put("screen", screen)

    # Start timer
    # {:ok, timer} = :timer.send_interval(@frame_ms, :frame)

    graph = @graph
            |> rect({256 * @pixel_size, 256 * @pixel_size},
              fill: {:dynamic, "screen"},
              # translate: {0, 0},
              id: :gameboy
            )
            |> text("", id: :fps, translate: {20 * @pixel_size, 70 * @pixel_size})


    gb = Gameboy.init()

    state = %{
      viewport: viewport,
      graph: graph,
      gb: gb,
      # frame_timer: timer,
      screen: screen
    }

    send(self(), :step)
    # results = run_profile(gb, 70224)
    {:ok, state, push: graph}
  end

  def handle_info(:frame, %{gb: gb, screen: screen} = state) do
    IO.puts("1")
    gb = put_in(gb.hw.counter, 0)
    screen_buffer = Ppu.screen_buffer(gb.hw.ppu)
    buffer_len = @screen_width * @screen_height - 1
    new_screen = Stream.zip(buffer_len..0, screen_buffer)
                 |> Enum.reduce(screen, fn {i, pixel}, sc -> 
                   y = div(i, @screen_width) * @pixel_size
                   x = rem(i, @screen_width) * @pixel_size
                   for i <- 0..@pixel_size,
                       j <- 0..@pixel_size,
                       reduce: sc do
                     acc -> Texture.put!(acc, x + i, y + j, pixel)
                   end
                 end)
    Cache.put("screen", new_screen)
    gb = put_in(gb.hw.ppu, Ppu.flush_screen_buffer(gb.hw.ppu))
    send(self(), :step)
    {:noreply, %{state | gb: gb, screen: new_screen}}
  end

  def handle_info(:put_frame, %{gb: gb, screen: screen} = state) do
    IO.puts("1")
    gb = put_in(gb.hw.counter, 0)
    screen_buffer = Ppu.screen_buffer(gb.hw.ppu)
    new_screen = Stream.zip(0..@screen_width * @screen_height, screen_buffer)
                 |> Enum.reduce(screen, fn {i, pixel}, sc -> 
                   y = div(i, @screen_width) * @pixel_size
                   x = rem(i, @screen_width) * @pixel_size
                   for i <- 0..@pixel_size,
                       j <- 0..@pixel_size,
                       reduce: sc do
                     acc -> Texture.put!(acc, x + i, y + j, pixel)
                   end
                 end)
    Cache.put("screen", new_screen)
    {:noreply, %{state | gb: gb, screen: new_screen}}
  end

  def handle_info(:step, state) do
    gb = Gameboy.step(state.gb)
    if !Utils.break_point(gb, 0xffffff) do
      if Ppu.screen_buffer_ready(gb.hw.ppu) do
        send(self(), :frame)
      else
        send(self(), :step)
      end
    else
      send(self(), :put_frame)
    end
    {:noreply, put_in(state.gb, gb)}
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

  def run_profile(gb, num_repeat) do
    {records, results} = do_analyze(gb, num_repeat)
    total_percent = Enum.reduce(records, 0.0, &(&1.percent + &2))
    IO.inspect "total = #{total_percent}"
    results
  end

  def do_analyze(gb, num_repeat) do
    profile do
      for i <- 0..num_repeat - 1, reduce: gb do
        gb -> Gameboy.step(gb)
      end
    end
  end

end
