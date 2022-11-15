defmodule Gameboy.Bootrom do
  alias Gameboy.TupleMemory

  @path "@{path}"

  @memory @path
  |> File.read!()
  |> TupleMemory.init()

  defp memory, do: @memory

  def init(_path) do
    true
  end

  def set_rom(active, _rom_data) do
    active
  end

  def get_rom(_active), do: memory()

  def active(active = _bootrom), do: active

  # Non-zero value disables bootrom
  def set_enable(_active, value), do: value == 0

  def read(_active, addr), do: TupleMemory.read(memory(), addr)
end
