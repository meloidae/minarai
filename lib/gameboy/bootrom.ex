defmodule Gameboy.Bootrom do
  alias Gameboy.Bootrom
  alias Gameboy.Memory
  defstruct memory: struct(Memory), active: false

  @path "roms/DMG_ROM.bin"

  def init(path \\ @path) do
    data = File.read!(path)
    %Bootrom{memory: %Memory{data: data}, active: true}
  end

  def read(%{memory: memory} = bootrom, addr), do: Memory.read(memory, addr)
end
