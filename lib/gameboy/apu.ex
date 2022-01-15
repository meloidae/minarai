defmodule Gameboy.Apu do
  use Bitwise
  alias Gameboy.Apu
  alias Gameboy.MapMemory

  # Just implement read/write for now. No real audio functionality

  @apu_mask 0x3f

  def init do
    MapMemory.init(0x40)
  end

  def read(apu, addr), do: MapMemory.read(apu, addr &&& @apu_mask)

  def write(apu, addr, value) do
    MapMemory.write(apu, addr &&& @apu_mask, value)
  end
end
