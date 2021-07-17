defmodule Gameboy.Apu do
  use Bitwise
  alias Gameboy.Apu
  alias Gameboy.Memory

  # Just implement read/write for now. No real audio functionality
  defstruct memory: struct(Memory)

  @apu_mask 0x3f

  def init do
    memory = Memory.init(0x40)
    %Apu{memory: memory}
  end

  def read(%{memory: memory} = apu, addr), do: Memory.read(memory, addr &&& @apu_mask)

  def write(%{memory: memory} = apu, addr, value) do
    Map.put(apu, :memory, Memory.write(memory, addr &&& @apu_mask, value))
  end
end
