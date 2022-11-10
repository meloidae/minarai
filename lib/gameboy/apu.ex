defmodule Gameboy.Apu do
  use Bitwise
  alias Gameboy.Apu
  alias Gameboy.EtsMemory, as: RWMemory

  # Just implement read/write for now. No real audio functionality

  @apu_mask 0x3f

  def init do
    RWMemory.init(0x40, :apu)
  end

  def read(apu, addr), do: RWMemory.read(apu, addr &&& @apu_mask)

  def write(apu, addr, value) do
    RWMemory.write(apu, addr &&& @apu_mask, value)
  end
end
