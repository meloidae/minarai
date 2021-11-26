defmodule Gameboy.TupleMemory do
  alias Gameboy.TupleMemory

  def init(bin) do
    :binary.bin_to_list(bin)
    |> List.to_tuple()
  end

  def read(data, addr), do: elem(data, addr)

  def read_binary(data, addr, len) do
    tuple2list(data, addr, addr + len)
    |> IO.iodata_to_binary()
  end

  defp tuple2list(t, first, last), do: tuple2list(t, first, last, [])
  defp tuple2list(_t, first, i, acc) when i < first, do: acc
  defp tuple2list(t, first, i, acc), do: tuple2list(t, first, i - 1, [elem(t, i) | acc])

end
