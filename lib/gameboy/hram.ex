defmodule Gameboy.Hram do
  import Bitwise
  alias Gameboy.Hram
  # alias Gameboy.EtsMemory, as: RWMemory
  # alias Gameboy.AtomicsMemory, as: RWMemory
  alias Gameboy.PtAtomicsMemory, as: RWMemory

  # defstruct memory: nil

  @hram_mask 0x007f

  def init do
    # memory = MapMemory.init(0x80)
    # %Hram{memory: memory}
    RWMemory.init(0x80, :hram)
  end

  # def read(%Hram{memory: memory} = _hram, addr), do: MapMemory.read(memory, addr &&& @hram_mask)
  def read(hram, addr), do: RWMemory.read(hram, addr &&& @hram_mask)

  # def write(%Hram{memory: memory} = hram, addr, value) do
  #   Map.put(hram, :memory, MapMemory.write(memory, addr &&& @hram_mask, value))
  # end
  def write(hram, addr, value) do
    RWMemory.write(hram, addr &&& @hram_mask, value)
  end
end
