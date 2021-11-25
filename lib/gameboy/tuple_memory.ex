defmodule Gameboy.TupleMemory do
  alias Gameboy.TupleMemory

  def init(bin) do
    :binary.bin_to_list(bin)
    |> List.to_tuple()
  end

  def read(data, addr), do: elem(data, addr)

end
