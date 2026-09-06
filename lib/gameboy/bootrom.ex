defmodule Gameboy.Bootrom do
  alias Gameboy.Bootrom
  alias Gameboy.Memory
  alias Gameboy.TupleMemory

  @path "roms/DMG_ROM.bin"

  def init(path \\ nil) do
    path = if is_nil(path) do
      IO.puts("Using default bootrom path: #{@path}")
      @path
    else
      IO.puts("Using bootrom path: #{path}")
      path
    end
    data = File.read!(path)
    {TupleMemory.init(data), true}
  end

  def active({_memory, active} = _bootrom), do: active

  # Non-zero value disables bootrom
  def set_enable({memory, _active}, value), do: {memory, value == 0}

  def read({memory, _active} = _bootrom, addr), do: TupleMemory.read(memory, addr)
end
