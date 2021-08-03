defmodule Gameboy.Test.Frame do
  alias Gameboy.SimplePpu, as: Ppu
  # def run_frame(gb) when gb.hw.ppu.screen.ready, do: gb
  def run_frame(gb) when gb.hw.counter >= 70224, do: gb
  def run_frame(gb), do: run_frame(Gameboy.step(gb))
  def run_frames_fps(gb, 0, fps_info), do: {gb, fps_info}
  def run_frames_fps(gb, n, fps_info) do
    start_time = System.monotonic_time()
    gb = run_frame(gb)
    end_time = System.monotonic_time()
    gb = put_in(gb.hw.ppu, Ppu.flush_screen_buffer(gb.hw.ppu))
    counter = gb.hw.counter
    gb = put_in(gb.hw.counter, 0)
    fps = 1_000 / System.convert_time_unit(end_time - start_time, :native, :millisecond)
    # IO.puts("#{n}: #{fps}, #{counter}")
    run_frames_fps(gb, n - 1, [fps | fps_info])
  end

  def run_frames(gb, 0), do: gb
  def run_frames(gb, n) do
    run_frames(run_frame(gb), n - 1)
  end
end

gb = Gameboy.init()

{gb, fps_info} = Gameboy.Test.Frame.run_frames_fps(gb, 300, [])
for {i, fps} <- Stream.zip(Stream.iterate(0, &(&1 + 1)), Enum.reverse(fps_info)) do
  IO.puts("#{i}: #{fps}")
end
avg = Enum.sum(fps_info) / length(fps_info)
IO.puts("Avg: #{avg}")
