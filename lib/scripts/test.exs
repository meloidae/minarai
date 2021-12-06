defmodule Gameboy.Test do
  def run_loop({_cpu, %{counter: counter}} = gb, n) when counter >= n, do: gb
  def run_loop(gb, n) do
    run_loop(Gameboy.step(gb), n)
  end
end
# gb = Gameboy.init()
{cpu, hw} = "state.gb"
            |> File.read!()
            |> :erlang.binary_to_term()
gb = {cpu, Map.put(hw, :counter, 0)}

Gameboy.Test.run_loop(gb, 17556 * 60)
