defmodule Gameboy.MapMemory do
  alias Gameboy.MapMemory

  def init(size) do
    0..size - 1
    |> Enum.reduce(%{}, fn i, acc -> Map.put(acc, i, 0) end)
  end

  def read(data, addr) do
    %{^addr => value} = data
    value
  end

  def read_binary(data, addr, len) do
    map2list(data, addr, addr + len - 1)
    |> IO.iodata_to_binary()
  end

  def write(data, addr, value), do: Map.put(data, addr, value)

  defp map2list(m, first, last), do: map2list(m, first, last, [])
  defp map2list(m, first, first, acc) do
    %{^first => value} = m
    [value | acc]
  end
  defp map2list(m, first, i, acc) do
    %{^i => value} = m
    map2list(m, first, i - 1, [value | acc])
  end
end
