defmodule Gameboy.EtsMemory do
  import Bitwise

  def init(size, name) do
    handle = :ets.new(name, [:set, :public, :named_table])
    # Initialize contents of ets
    0..size - 1
    |> Enum.each(fn i -> :ets.insert(handle, {i, 0}) end)
    handle
  end

  def init_array(block_size, num_blocks, name) do
    IO.puts("init_array(): name=#{name}, bank=#{num_blocks}, bank_size=#{block_size}")
    handle = :ets.new(name, [:set, :public, :named_table])
    _init_array(block_size, handle, num_blocks)
  end

  def _init_array(_block_size, handle, 0), do: handle
  def _init_array(block_size, handle, i) do
    0..block_size - 1
    |> Enum.each(fn j -> :ets.insert(handle, {{i - 1, j}, 0}) end)
    _init_array(block_size, handle, i - 1)
  end

  def read(handle, addr) do
    :ets.lookup_element(handle, addr, 2)
  end

  def read_range(handle, addr, len), do: ets2list(handle, addr, addr + len - 1, [])

  def read_binary(handle, addr, len) do
    ets2list(handle, addr, addr + len - 1, [])
    |> IO.iodata_to_binary()
  end

  def read_short(handle, addr) do
    high = :ets.lookup_element(handle, addr, 2)
    low = :ets.lookup_element(handle, addr + 1, 2)
    (high <<< 8) ||| low
  end

  def read_array(handle, bank, addr) do
    :ets.lookup_element(handle, {bank, addr}, 2)
  end

  def write(handle, addr, value) do
    # IO.puts("write(): name=#{handle}, addr=#{addr}, value=#{value}")
    :ets.insert(handle, {addr, value})
  end

  def write_array(handle, bank, addr, value) do
    # IO.puts("write_array(): name=#{handle}, bank=#{bank}, addr=#{addr}, value=#{value}")
    :ets.insert(handle, {{bank, addr}, value})
  end

  defp ets2list(handle, first, first, acc) do
    value = :ets.lookup_element(handle, first, 2)
    [value | acc]
  end
  defp ets2list(handle, first, i, acc) do
    value = :ets.lookup_element(handle, i, 2)
    ets2list(handle, first, i - 1, [value | acc])
  end
end
