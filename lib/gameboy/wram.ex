defmodule Gameboy.Wram do
  use Bitwise
  alias Gameboy.Wram
  alias Gameboy.MapMemory

  defstruct memory: nil,
            offset: 0x1000 # CGB has switchable 1-7 high banks, but ignore that for now

  @wram_mask 0x0fff

  def init do
    memory = MapMemory.init(0x8000)
    %Wram{memory: memory}
  end

  def read_low(%Wram{memory: memory} = _wram, addr), do: MapMemory.read(memory, addr &&& @wram_mask)

  def read_high(%Wram{memory: memory, offset: offset} = _wram, addr) do
    MapMemory.read(memory, offset ||| (addr &&& @wram_mask))
  end

  def read_binary_low(%Wram{memory: memory} = _wram, addr, len) do
    MapMemory.read_binary(memory, addr &&& @wram_mask, len)
  end

  def read_binary_high(%Wram{memory: memory, offset: offset} = _wram, addr, len) do
    MapMemory.read_binary(memory, offset ||| (addr &&& @wram_mask), len)
  end

  def write_low(%Wram{memory: memory} = wram, addr, value) do
    Map.put(wram, :memory, MapMemory.write(memory, addr &&& @wram_mask, value))
  end

  def write_high(%Wram{memory: memory, offset: offset} = wram, addr, value) do
    Map.put(wram, :memory, MapMemory.write(memory, offset ||| (addr &&& @wram_mask), value))
  end

end
