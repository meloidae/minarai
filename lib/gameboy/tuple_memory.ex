defmodule Gameboy.TupleMemory do
  alias Gameboy.TupleMemory

  def init(bin) do
    :binary.bin_to_list(bin)
    |> List.to_tuple()
  end

  def read(data, addr), do: elem(data, addr)

  def read_binary(data, addr, len) do
    tuple2list(data, addr, addr + len - 1)
    |> IO.iodata_to_binary()
  end

  defp tuple2list(t, first, last), do: tuple2list(t, first, last, [])
  defp tuple2list(t, first, first, acc), do: [elem(t, first) | acc]
  defp tuple2list(t, first, i, acc), do: tuple2list(t, first, i - 1, [elem(t, i) | acc])
end
