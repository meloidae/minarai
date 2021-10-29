# defmodule Gameboy.Dma do
#   use Bitwise
# 
#   @request_index 1
#   @source_index 2
# 
#   def init do
#     :atomics.new(2, [signed: false])
#   end
# 
#   def request(dma, value) do
#     :atomics.put(dma, @source_index, value)
#     :atomics.put(dma, @request_index, 1)
#   end
# 
#   @requested {false, true}
#   @compile {:inline, :requested, 1}
#   def requested(dma), do: elem(@requested, :atomics.get(dma, @request_index))
# 
#   def source(dma), do: :atomics.get(dma, @source_index)
# 
#   def address(dma), do: :atomics.get(dma, @source_index) <<< 8
# 
#   def acknowledge_request(dma), do: :atomics.put(dma, @request_index, 0)
# end
# 
defmodule Gameboy.Dma do
  use Bitwise
  alias Gameboy.Dma

  defstruct requested: false,
            source: 0x00

  def init do
    %Dma{}
  end

  def request(dma, value) do
    %{dma | source: value, requested: true}
  end

  def address(dma), do: dma.source <<< 8

  def acknowledge_request(dma), do: Map.put(dma, :requested, false)
end
