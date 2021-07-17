defmodule Gameboy.Hram do
  use Bitwise
  alias Gameboy.Hram
  alias Gameboy.Memory

  defstruct memory: struct(Memory)

  @hram_mask 0x007f

  def init do
    memory = Memory.init(0x80)
    %Hram{memory: memory}
  end

  def read(%Hram{memory: memory} = hram, addr), do: Memory.read(memory, addr &&& @hram_mask)

  def write(%Hram{memory: memory} = hram, addr, value) do
    Map.put(hram, :memory, Memory.write(memory, addr &&& @hram_mask, value))
  end


end
