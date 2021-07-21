defmodule Gameboy.Utils.Fifo do
  alias Gameboy.Utils.Fifo
  defstruct buffer: nil,
            size: 0,
            front: 0,
            back: 0,
            capacity: 0

  def init(capacity) do
    buffer = 0..capacity - 1
             |> Enum.reduce(%{}, fn i, m -> Map.put(m, i, 0) end)
    %Fifo{buffer: buffer, capacity: capacity}
  end

  def clear(%Fifo{} = fifo) do
    %{fifo | size: 0, front: 0, back: 0}
  end

  def push(%Fifo{buffer: buffer, size: size, back: back, capacity: capacity} = fifo, value) do
    %{fifo | buffer: Map.put(buffer, back, value), back: rem(back + 1, capacity), size: size + 1}
  end

  def pop(%Fifo{buffer: buffer, size: size, front: front, capacity: capacity} = fifo) do
    {Map.get(buffer, front), %{fifo | front: rem(front + 1, capacity), size: size - 1}}
  end
end
