defmodule Gameboy.WRAM do
  use Bitwise
  alias Gameboy.WRAM
  alias Gameboy.Memory

  defstruct memory: struct(Memory),
            offset: 0x1000 # CGB has switchable 1-7 high banks, but ignore that for now

  @wram_mask 0x0fff

  def init do
    memory = Memory.init(0x8000)
    %WRAM{memory: memory}
  end

  def read_low(%WRAM{memory: memory} = wram, addr), do: Memory.read(memory, addr &&& @wram_mask)

  def read_high(%WRAM{memory: memory, offset: offset} = wram, addr) do
    Memory.read(memory, offset ||| (addr &&& @wram_mask))
  end

  def write_low(%WRAM{memory: memory} = wram, addr, value) do
    put_in(wram.memory, Memory.write(memory, addr &&& @wram_mask, value))
  end

  def write_high(%WRAM{memory: memory, offset: offset} = wram, addr, value) do
    put_in(wram.memory, Memory.write(memory, offset ||| (addr &&& @wram_mask), value))
  end

end
