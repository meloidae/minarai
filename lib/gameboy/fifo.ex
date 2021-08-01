defmodule Gameboy.Fifo do

  @table_name :fifo_table
  @capacity 16

  def init() do
    :ets.new(@table_name, [:set, :named_table])
    :ets.insert(@table_name, {:front, 0})
    :ets.insert(@table_name, {:back, 0})
  end

  def clear() do
    :ets.insert(@table_name, {:front, 0})
    :ets.insert(@table_name, {:back, 0})
  end

  def push(value) do
    back = :ets.lookup_element(@table_name, :back, 2)
    :ets.insert(@table_name, {back, value})
    :ets.insert(@table_name, {:back, rem(back + 1, @capacity)})
  end

  def pop() do
    front = :ets.lookup_element(@table_name, :front, 2)
    :ets.insert(@table_name, {:front, rem(front + 1, @capacity)})
    :ets.lookup_element(@table_name, front, 2)
  end
end
# defmodule Gameboy.Utils.MapFifo do
#   alias Gameboy.Utils.MapFifo
#   defstruct buffer: nil,
#             size: 0,
#             front: 0,
#             back: 0,
#             capacity: 0
# 
#   def init(capacity) do
#     buffer = 0..capacity - 1
#              |> Enum.reduce(%{}, fn i, m -> Map.put(m, i, 0) end)
#     %MapFifo{buffer: buffer, capacity: capacity}
#   end
# 
#   def clear(%MapFifo{} = fifo) do
#     %{fifo | size: 0, front: 0, back: 0}
#   end
# 
#   def push(%MapFifo{buffer: buffer, size: size, back: back, capacity: capacity} = fifo, value) do
#     %{fifo | buffer: Map.put(buffer, back, value), back: rem(back + 1, capacity), size: size + 1}
#   end
# 
#   def pop(%MapFifo{buffer: buffer, size: size, front: front, capacity: capacity} = fifo) do
#     {Map.get(buffer, front), %{fifo | front: rem(front + 1, capacity), size: size - 1}}
#   end
# end
# 
# 
