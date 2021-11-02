defmodule Gameboy.Test do
  def run_loop(gb, n) when gb.hw.counter >= n, do: gb
  def run_loop(gb, n), do: run_loop(Gameboy.step(gb), n)
end
gb = Gameboy.init()
Gameboy.Test.run_loop(gb, 70224 * 60)
