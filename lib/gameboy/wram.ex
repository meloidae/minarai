defmodule Gameboy.Wram do
  use Bitwise
  alias Gameboy.Wram
  alias Gameboy.AtomicsMemory, as: RWMemory

  @wram_mask 0x0fff

  def init do
    {RWMemory.init(0x2000, :wram), 0x1000}
  end

  def read_low({data, _offset}, addr), do: RWMemory.read(data, addr &&& @wram_mask)

  def read_high({data, offset}, addr) do
    RWMemory.read(data, offset ||| (addr &&& @wram_mask))
  end

  def read_binary_low({data, _offset}, addr, len) do
    RWMemory.read_binary(data, addr &&& @wram_mask, len)
  end

  def read_binary_high({data, offset}, addr, len) do
    RWMemory.read_binary(data, offset ||| (addr &&& @wram_mask), len)
  end

  def write_low({data, _offset} = wram, addr, value) do
    RWMemory.write(data, addr &&& @wram_mask, value)
    wram
  end

  def write_high({data, offset} = wram, addr, value) do
    RWMemory.write(data, offset ||| (addr &&& @wram_mask), value)
    wram
  end

end
