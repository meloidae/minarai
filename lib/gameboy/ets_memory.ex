defmodule Gameboy.EtsMemory do
  use Bitwise

  def init(name, size) do
    handle = :ets.new(name, [:set, :private])
    # Initialize contents of ets
    0..size - 1
    |> Enum.each(fn i -> :ets.insert(handle, {i, 0}) end)
    handle
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

  def write(handle, addr, value), do: :ets.insert(handle, {addr, value})

  defp ets2list(handle, first, first, acc) do
    value = :ets.lookup_element(handle, first, 2)
    [value | acc]
  end
  defp ets2list(handle, first, i, acc) do
    value = :ets.lookup_element(handle, i, 2)
    ets2list(handle, first, i - 1, [value | acc])
  end
end
