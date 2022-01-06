defmodule Gameboy.AtomicsMemory do
  use Bitwise
  alias AtomicsMemory

  def init(size) do
    :atomics.new(size, [signed: false])
  end

  def read(ref, addr), do: :atomics.get(ref, addr + 1)

  def read_range(ref, addr, len), do: atomics2list(ref, addr + 1, addr + len, [])

  def read_binary(ref, addr, len) do
    atomics2list(ref, addr + 1, addr + len, [])
    |> IO.iodata_to_binary()
  end

  def read_short(ref, addr) do
    high = :atomics.get(ref, addr + 1)
    low = :atomics.get(ref, addr + 2)
    (high <<< 8) ||| low
  end

  def write(ref, addr, value), do: :atomics.put(ref, addr + 1, value)

  # atomics2list() uses one-based indexing
  defp atomics2list(ref, first, first, acc) do
    [:atomics.get(ref, first) | acc]
  end
  defp atomics2list(ref, first, i, acc) do
    atomics2list(ref, first, i - 1, [:atomics.get(ref, i) | acc])
  end
end
