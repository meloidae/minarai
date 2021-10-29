defmodule Gameboy.Bootrom do
  alias Gameboy.Bootrom
  alias Gameboy.Memory
  alias Gameboy.EtsMemory
  defstruct memory: struct(Memory), active: false
  # defstruct memory: struct(EtsMemory), active: false

  @path "roms/DMG_ROM.bin"
  # @path "roms/tests/blargg/cpu_instrs/cpu_instrs.gb"

  def init(path \\ nil) do
    path = if is_nil(path) do
      IO.puts("Using default bootrom path: #{@path}")
      @path
    else
      IO.puts("Using bootrom path: #{path}")
      path
    end
    data = File.read!(path)
    %Bootrom{memory: %Memory{data: data}, active: true}
    # %Bootrom{memory: EtsMemory.init_from_binary(:bootrom, data), active: true}
  end

  # Non-zero value disables bootrom
  def set_enable(bootrom, value), do: Map.put(bootrom, :active, value == 0)

  def read(%{memory: memory} = _bootrom, addr), do: Memory.read(memory, addr)
  # def read(%{memory: memory} = _bootrom, addr), do: EtsMemory.read(memory, addr)

  def write(%{memory: memory} = bootrom, addr, data) do
    Map.put(bootrom, :memory, Memory.write(memory, addr, data))
  end

  # def write(%{memory: memory} = bootrom, addr, data) do
  #   EtsMemory.write(memory, addr, data)
  #   bootrom
  # end
end
