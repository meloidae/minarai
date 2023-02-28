defmodule Gameboy.PtAtomicsMemory do
  import Bitwise

  def init(size, name) do
    ref = :atomics.new(size, [signed: false])
    :persistent_term.put(name, ref)
    name
  end

  def init_array(block_size, num_blocks, name) do
    IO.puts("init_array(): name=#{name}, bank=#{num_blocks}, bank_size=#{block_size}")
    ref = :atomics.new(block_size * num_blocks, [signed: false])
    :persistent_term.put(name, ref)
    {name, block_size}
  end

  def read(name, addr) do
    :persistent_term.get(name)
    |> :atomics.get(addr + 1)
  end

  def read_short(name, addr) do
    ref = :persistent_term.get(name)
    high = :atomics.get(ref, addr + 1)
    low = :atomics.get(ref, addr + 2)
    (high <<< 8) ||| low
  end

  def read_range(name, addr, len), do: tolist(name, addr + 1, len)

  def read_binary(name, addr, len) do
    tolist(name, addr + 1, len)
    |> IO.iodata_to_binary()
  end

  def read_array({name, block_size}, bank, addr) do
    :persistent_term.get(name)
    |> :atomics.get(block_size * bank + addr + 1)
  end

  def write(name, addr, value) do
    :persistent_term.get(name)
    |> :atomics.put(addr + 1, value)
  end

  def write_array({name, block_size}, bank, addr, value) do
    :persistent_term.get(name)
    |> :atomics.put(block_size * bank + addr + 1, value)
  end

  # tolist uses one-based indexing
  defp tolist(name, addr, len) do
    ref = :persistent_term.get(name)
    tolist(ref, addr, addr + len - 1, [])
  end
  defp tolist(ref, first, first, acc), do: [:atomics.get(ref, first) | acc]
  defp tolist(ref, first, i, acc) do
    tolist(ref, first, i - 1, [:atomics.get(ref, i) | acc])
  end
end
