defmodule Gameboy.Hram do
  use Bitwise
  alias Gameboy.Hram
  alias Gameboy.AtomicsMemory, as: RWMemory

  @hram_mask 0x007f

  def init do
    RWMemory.init(0x80, :hram)
  end

  def read(hram, addr), do: RWMemory.read(hram, addr &&& @hram_mask)

  def write(hram, addr, value) do
    RWMemory.write(hram, addr &&& @hram_mask, value)
  end
end
