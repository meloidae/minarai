defmodule Gameboy.Wram do
  use Bitwise
  alias Gameboy.Wram
  # alias Gameboy.MapMemory
  alias Gameboy.EtsMemory
  # alias Gameboy.AtomicsMemory

  # defstruct memory: nil,
  #           offset: 0x1000 # CGB has switchable 1-7 high banks, but ignore that for now

  @wram_mask 0x0fff

  def init do
    # memory = MapMemory.init(0x2000)
    # %Wram{memory: memory}
    {EtsMemory.init(:wram, 0x2000), 0x1000}
  end

  # def read_low(%Wram{memory: memory} = _wram, addr), do: MapMemory.read(memory, addr &&& @wram_mask)
  def read_low({data, _offset}, addr), do: EtsMemory.read(data, addr &&& @wram_mask)

  # def read_high(%Wram{memory: memory, offset: offset} = _wram, addr) do
  #   MapMemory.read(memory, offset ||| (addr &&& @wram_mask))
  # end
  def read_high({data, offset}, addr) do
    EtsMemory.read(data, offset ||| (addr &&& @wram_mask))
  end

  # def read_binary_low(%Wram{memory: memory} = _wram, addr, len) do
  #   MapMemory.read_binary(memory, addr &&& @wram_mask, len)
  # end
  def read_binary_low({data, _offset}, addr, len) do
    EtsMemory.read_binary(data, addr &&& @wram_mask, len)
  end

  # def read_binary_high(%Wram{memory: memory, offset: offset} = _wram, addr, len) do
  #   MapMemory.read_binary(memory, offset ||| (addr &&& @wram_mask), len)
  # end
  def read_binary_high({data, offset}, addr, len) do
    EtsMemory.read_binary(data, offset ||| (addr &&& @wram_mask), len)
  end

  # def write_low(%Wram{memory: memory} = wram, addr, value) do
  #   Map.put(wram, :memory, MapMemory.write(memory, addr &&& @wram_mask, value))
  # end
  def write_low({data, _offset} = wram, addr, value) do
    EtsMemory.write(data, addr &&& @wram_mask, value)
    wram
  end

  # def write_high(%Wram{memory: memory, offset: offset} = wram, addr, value) do
  #   Map.put(wram, :memory, MapMemory.write(memory, offset ||| (addr &&& @wram_mask), value))
  # end
  def write_high({data, offset} = wram, addr, value) do
    EtsMemory.write(data, offset ||| (addr &&& @wram_mask), value)
    wram
  end

end
