defmodule Gameboy.Test.Ppu do
  def run_ppu(ppu) when ppu.screen.ready, do: ppu
  def run_ppu(ppu), do: run_ppu(Gameboy.Ppu.cycle(ppu))

  def run_ppu_frames(ppu, 0), do: ppu
  def run_ppu_frames(ppu, n) do
    ppu = run_ppu(ppu)
    ppu = Gameboy.Ppu.flush_screen_buffer(ppu)
    run_ppu_frames(ppu, n - 1)
  end

  def run_ppu_fps(ppu, 0, fps_info), do: {ppu, fps_info}
  def run_ppu_fps(ppu, n, fps_info) do
    start_time = System.monotonic_time()
    ppu = run_ppu(ppu)
    end_time = System.monotonic_time()
    ppu = Gameboy.Ppu.flush_screen_buffer(ppu)
    # counter = gb.hw.counter
    fps = 1_000_000 / System.convert_time_unit(end_time - start_time, :native, :microsecond)
    # IO.puts("#{n}: #{fps}, #{counter}")
    # IO.puts("#{n}: #{fps}")
    run_ppu_fps(ppu, n - 1, [fps | fps_info])
  end
end

gb = Gameboy.init()
# Turn on lcd
gb = put_in(gb.hw.ppu, Gameboy.Ppu.set_lcd_control(gb.hw.ppu, 0x91))

# Single frame
# {ppu, _} = Gameboy.Test.Ppu.run_ppu_fps(gb.hw.ppu, 1, [])

# Measure fps
{ppu, fps_info} = Gameboy.Test.Ppu.run_ppu_fps(gb.hw.ppu, 300, [])
for {i, fps} <- Stream.zip(Stream.iterate(0, &(&1 + 1)), Enum.reverse(fps_info)) do
  IO.puts("#{i}: #{fps}")
end
avg = Enum.sum(fps_info) / length(fps_info)
IO.puts("Avg: #{avg}")

# For fprof
# ppu = Gameboy.Test.Ppu.run_ppu_frames(gb.hw.ppu, 10)
