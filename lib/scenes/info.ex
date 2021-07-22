defmodule Minarai.Scene.Info do
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
  @pixel_size 4
  @screen_width 160
  @screen_height 144
  

  # Initalization
  def init(_arg, opts) do
    viewport = opts[:viewport]

    screen = Texture.build!(:rgb, 160, 144, clear: {155, 188, 15})
    Cache.put("screen", screen)

    # Start timer
    # {:ok, timer} = :timer.send_interval(@frame_ms, :frame)

    graph = @graph
            |> rect({160, 144},
              fill: {:dynamic, "screen"},
              scale: @pixel_size,
              pin: {0, 0},
              # translate: {160 * @pixel_size, 144 * @pixel_size},
              id: :gameboy
            )

    gb = Gameboy.init()

    state = %{
      viewport: viewport,
      graph: graph,
      gb: gb,
      # frame_timer: timer,
      # screen: screen
      prev_time: nil,
    }

    send(self(), :step)
    # buffer = 1..@screen_width * @screen_height
    #          |> Enum.reduce(<<>>, fn _, b -> b <> <<0, 0, 0>> end)
    # {time, _} = Utils.measure(fn -> Cache.put("screen", {:rgb, @screen_width, @screen_height, buffer, []}) end)
    # IO.puts("Took #{time} seconds to place texture from binary")
    # buffer = 0..@screen_width * @screen_height - 1
    #          |> Enum.reduce(%{}, fn i, m -> Map.put(m, i, 0) end)
    #          |> Enum.map(fn {i, p} -> {i, color(p)} end)
    # {time, screen} = Utils.measure(fn -> render_from_map(screen, buffer) end)
    # IO.puts("Took #{time} seconds to consruct texture")
    # results = run_profile(gb, 70224)
    # steps = 1
    # {time, gb} = Utils.measure(fn -> run_loop(gb, steps) end)
    # IO.puts("Took #{time} seconds to complete #{steps} steps")
    # IO.puts("counter = #{gb.hw.counter}")
    # {time, gb} = Utils.measure(fn -> run_frame(gb) end)
    # IO.puts("Took #{time} seconds to complete a frame (70224 cycles)")
    # IO.puts("counter = #{gb.hw.counter}")
    # cycle = 70224 * 9
    # {time, gb} = Utils.measure(fn -> run_cycle(gb, cycle) end)
    # IO.puts("Took #{time} seconds to complete #{cycle} cycles")
    # IO.puts("counter = #{gb.hw.counter}")

    {:ok, state, push: graph}
  end

  # def color(0b11), do: {15, 65, 15}
  # def color(0b10), do: {48, 98, 48}
  # def color(0b01), do: {139, 172, 15}
  # def color(0b00), do: {155, 188, 15}

  def render_from_array(screen, screen_buffer) do
    buffer_len = @screen_width * @screen_height
    Stream.zip(0..buffer_len - 1, screen_buffer)
    |> Enum.reduce(screen, fn {i, pixel}, sc -> 
      y = div(i, @screen_width) * @pixel_size
      x = rem(i, @screen_width) * @pixel_size
      for i <- 0..@pixel_size - 1,
          j <- 0..@pixel_size - 1,
          reduce: sc do
        acc -> Texture.put!(acc, x + i, y + j, pixel)
      end
    end)
  end

  def render_from_map(screen, screen_buffer) do
    screen_buffer
    |> Enum.reduce(screen, fn {i, pixel}, sc ->
          y = div(i, @screen_width)
          x = rem(i, @screen_width)
          Texture.put!(sc, x, y, pixel)
        end)
  end

  def render_from_list(screen, screen_buffer) do
    buffer_len = @screen_width * @screen_height
    Stream.zip(buffer_len - 1..0, screen_buffer)
    |> Enum.reduce(screen, fn {i, pixel}, sc ->
      y = div(i, @screen_width) * @pixel_size
      x = rem(i, @screen_width) * @pixel_size
      for j <- 0..@pixel_size - 1,
          k <- 0..@pixel_size - 1,
          reduce: sc do
          acc -> Texture.put!(acc, x + j, y + k, pixel)
      end
    end)
  end

  def handle_info(:frame, %{gb: gb} = state) do
    gb = put_in(gb.hw.counter, 0)
    screen_buffer = Ppu.screen_buffer(gb.hw.ppu)
    # new_screen = render_from_list(screen, screen_buffer)
    # new_screen = render_from_map(screen, screen_buffer)
    # new_screen = render_from_array(screen, screen_buffer)
    # Cache.put("screen", new_screen)
    Cache.put("screen", {:rgb, @screen_width, @screen_height, screen_buffer, []})
    gb = put_in(gb.hw.ppu, Ppu.flush_screen_buffer(gb.hw.ppu))
    {graph, prev_time} = if !is_nil(state.prev_time) do
      curr_time = System.monotonic_time()
      diff = System.convert_time_unit(curr_time - state.prev_time, :native, :millisecond)
      fps = 1_000 / diff
      {state.graph |> text("#{Float.round(fps, 2)}", fill: :white, translate: {48, 48}), curr_time}
    else
      {state.graph, System.monotonic_time()}
    end
    send(self(), :step)
    {:noreply, %{state | gb: gb, prev_time: prev_time}, push: graph}
  end

  def handle_info(:put_frame, %{gb: gb} = state) do
    IO.puts("Put frame")
    screen_buffer = Ppu.screen_buffer(gb.hw.ppu)
    # new_screen = render_from_list(screen, screen_buffer)
    # new_screen = render_from_map(screen, screen_buffer)
    # new_screen = render_from_array(screen, screen_buffer)
    # Cache.put("screen", new_screen)
    Cache.put("screen", {:rgb, @screen_width, @screen_height, screen_buffer, []})
    gb = put_in(gb.hw.ppu, Ppu.flush_screen_buffer(gb.hw.ppu))
    {graph, prev_time} = if !is_nil(state.prev_time) do
      curr_time = System.monotonic_time()
      diff = System.convert_time_unit(curr_time - state.prev_time, :native, :millisecond)
      fps = 1_000 / diff
      {state.graph |> text("#{Float.round(fps)}", fill: :white, translate: {48, 48}), curr_time}
    else
      {state.graph, System.monotonic_time()}
    end

    {:noreply, %{state | gb: gb, prev_time: prev_time}, push: graph}
  end

  def handle_info(:step, state) do
    gb = Gameboy.step(state.gb)
    # IO.puts("#{inspect(gb.cpu)}")
    if !Utils.break_point(gb, 0x00e0) do
      if Ppu.screen_buffer_ready(gb.hw.ppu) do
        send(self(), :frame)
      else
        send(self(), :step)
      end
      # send(self(), :step)
    else
      # send(self(), :put_frame)
      send(self(), :render)
    end
    {:noreply, Map.put(state, :gb, gb)}
  end

  def ppu_loop(ppu) when ppu.screen.ready, do: ppu
  def ppu_loop(ppu), do: ppu_loop(Ppu.cycle(ppu))

  def handle_info(:render, state) do
    gb = state.gb
    ppu = ppu_loop(gb.hw.ppu)
    send(self(), :put_frame)
    {:noreply, Map.put(state, :gb, put_in(gb.hw.ppu, ppu))}
  end

  # Until next vblank
  def handle_info(:step_till_vblank, state) do
    gb = Gameboy.step(state.gb)
    if !Ppu.screen_buffer_ready(gb.hw.ppu) do
      send(self(), :step_till_vblank)
    else
      send(self(), :put_frame)
    end
    {:noreply, Map.put(state, :gb, gb)}
  end

  # Single step
  # def handle_input({:key, {"enter", :press, _}}, _context, state) do
  #   gb = Gameboy.step(state.gb)
  #   {:noreply, Map.put(state, :gb, gb)}
  # end
  
  def handle_info(:single_step, state) do
    gb = Gameboy.step(state.gb)
    {:noreply, Map.put(state, :gb, gb)}
  end

  def handle_input({:key, {"enter", :press, _}}, _context, state) do
    IO.puts("#{inspect(state.gb.cpu)}")
    send(self(), :single_step)
    {:noreply, state}
  end

  def handle_input({:key, {"A", :press, _}}, _context, state) do
    send(self(), :step_till_vblank)
    {:noreply, state}
  end


  def handle_input(_input, _context, state), do: {:noreply, state}

  def print_info(graph, cpu, position) do
    graph
    |> text(inspect(cpu), fill: :white, translate: position)
  end

  def run_loop(gb, 0), do: gb
  def run_loop(gb, n), do: run_loop(Gameboy.step(gb), n - 1)

  def run_frame(gb) when gb.hw.counter < 70224, do: run_frame(Gameboy.step(gb))
  def run_frame(gb), do: gb

  def run_cycle(gb, n) when gb.hw.counter < n, do: run_cycle(Gameboy.step(gb), n)
  def run_cycle(gb, _), do: gb
end
