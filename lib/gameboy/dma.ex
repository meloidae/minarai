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
