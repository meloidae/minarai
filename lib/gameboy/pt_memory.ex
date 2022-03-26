defmodule Gameboy.PtMemory do
  alias Gameboy.PtMemory

  def init(name, bin) do
    data = :binary.bin_to_list(bin)
    |> List.to_tuple()
    :persistent_term.put(name, data)
    name
  end

  def read(key, addr), do: elem(:persistent_term.get(key), addr)

  def read_binary(key, addr, len) do
    data = :persistent_term.get(key)
    _read_binary(data, addr, len)
  end

  defp _read_binary(data, addr, len) do
    tuple2list(data, addr, addr + len - 1)
    |> IO.iodata_to_binary()
  end

  defp tuple2list(t, first, last), do: tuple2list(t, first, last, [])
  defp tuple2list(t, first, first, acc), do: [elem(t, first) | acc]
  defp tuple2list(t, first, i, acc), do: tuple2list(t, first, i - 1, [elem(t, i) | acc])
end
