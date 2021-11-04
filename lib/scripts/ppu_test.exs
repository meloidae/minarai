defmodule Gameboy.Test.Ppu do
  def _run_ppu(ppu, intr) when ppu.mode == :oam_search and ppu.counter == 20, do: ppu
  def _run_ppu(ppu, intr), do: _run_ppu(Gameboy.SimplePpu.cycle(ppu, intr), intr)
  def run_ppu(ppu, intr), do: _run_ppu(Gameboy.SimplePpu.cycle(ppu, intr), intr)

  def run_ppu_frames(ppu, intr, 0), do: ppu
  def run_ppu_frames(ppu, intr, n) do
    ppu = run_ppu(ppu, intr)
    run_ppu_frames(ppu, intr, n - 1)
  end

  def run_ppu_fps(ppu, intr, 0, fps_info), do: {ppu, fps_info}
  def run_ppu_fps(ppu, intr, n, fps_info) do
    start_time = System.monotonic_time()
    ppu = run_ppu(ppu, intr)
    end_time = System.monotonic_time()
    # counter = gb.hw.counter
    fps = 1_000_000 / System.convert_time_unit(end_time - start_time, :native, :microsecond)
    # IO.puts("#{n}: #{fps}, #{counter}")
    # IO.puts("#{n}: #{fps}")
    run_ppu_fps(ppu, intr, n - 1, [fps | fps_info])
  end
end

gb = Gameboy.init()
# Turn on lcd
gb = put_in(gb.hw.ppu, Gameboy.SimplePpu.set_lcd_control(gb.hw.ppu, 0x91))

# Single frame
# {ppu, _} = Gameboy.Test.Ppu.run_ppu_fps(gb.hw.ppu, 1, [])

# Measure fps
{ppu, fps_info} = Gameboy.Test.Ppu.run_ppu_fps(gb.hw.ppu, gb.hw.intr, 300, [])
for {i, fps} <- Stream.zip(Stream.iterate(0, &(&1 + 1)), Enum.reverse(fps_info)) do
  IO.puts("#{i}: #{fps}")
end
avg = Enum.sum(fps_info) / length(fps_info)
IO.puts("Avg: #{avg}")

# For fprof
# ppu = Gameboy.Test.Ppu.run_ppu_frames(gb.hw.ppu, 10)
