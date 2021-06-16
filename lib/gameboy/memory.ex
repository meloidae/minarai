defmodule Gameboy.Memory do
  alias Gameboy.Memory

  defstruct data: <<0x00::size(0x1)-unit(8)>>

  def init(mem_size) do
    %Memory{data: <<0x00::size(mem_size)-unit(8)>>}
  end

  def read(%Memory{data: data} = memory, addr), do: :binary.at(data, addr)

  def write(%Memory{data: data} = memory, addr, value) do
    <<first::binary-size(addr), _::binary-size(1), rest::binary>> = data
    put_in(memory.data, first <> <<value>> <> rest)
  end
end
