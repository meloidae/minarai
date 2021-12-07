defmodule Gameboy.Hram do
  use Bitwise
  alias Gameboy.Hram
  alias Gameboy.MapMemory

  defstruct memory: nil

  @hram_mask 0x007f

  def init do
    memory = MapMemory.init(0x80)
    %Hram{memory: memory}
  end

  def read(%Hram{memory: memory} = _hram, addr), do: MapMemory.read(memory, addr &&& @hram_mask)

  def write(%Hram{memory: memory} = hram, addr, value) do
    Map.put(hram, :memory, MapMemory.write(memory, addr &&& @hram_mask, value))
  end
end
