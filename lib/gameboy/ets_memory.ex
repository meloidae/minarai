defmodule Gameboy.EtsMemory do
  alias Gameboy.EtsMemory

  defstruct table_id: nil, size: 0x00

  def init(table_id, mem_size, access \\ :protected) do
    :ets.new(table_id, [:set, access, :named_table])
    1..mem_size |> Enum.each(fn i -> :ets.insert(table_id, {i - 1, 0}) end)
    %EtsMemory{table_id: table_id, size: mem_size}
  end

  def init_from_binary(table_id, bin, access \\ :protected) do
    :ets.new(table_id, [:set, access, :named_table])
    mem_size = byte_size(bin)
    :binary.bin_to_list(bin)
    |> Enum.zip(1..mem_size)
    |> Enum.each(fn {v, i} -> :ets.insert(table_id, {i - 1, v}) end)
    %EtsMemory{table_id: table_id, size: mem_size}
  end

  def read(%EtsMemory{table_id: table_id} = _memory, addr) do
    :ets.lookup_element(table_id, addr, 2)
  end

  def write(%EtsMemory{table_id: table_id} = memory, addr, value) do
    :ets.insert(table_id, {addr, value})
    memory
  end

end
