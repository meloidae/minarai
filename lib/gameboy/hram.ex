defmodule Gameboy.HRAM do
  use Bitwise
  alias Gameboy.HRAM
  alias Gameboy.Memory

  defstruct memory: struct(Memory)

  @hram_mask 0x007f

  def init do
    memory = Memory.init(0x80)
    %HRAM{memory: memory}
  end

  def read(%HRAM{memory: memory} = hram, addr), do: Memory.read(memory, addr &&& @hram_mask)

  def write(%HRAM{memory: memory} = hram, addr, value) do
    put_in(hram.memory, Memory.write(memory, addr &&& @hram_mask, value))
  end


end
