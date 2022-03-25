defmodule Gameboy.Memory do
  alias Gameboy.Memory

  defstruct data: <<0x00::size(0x1)-unit(8)>>, size: 0x01

  def init(size, _name), do: init(size)
  def init(mem_size) do
    %Memory{data: <<0x00::size(mem_size)-unit(8)>>, size: mem_size}
  end

  def init_memory_array(block_size, num_blocks) do
    _init_memory_array(%{}, block_size, num_blocks)
  end

  defp _init_memory_array(mem_array, block_size, i) do
    if i == 0, do: mem_array, else: _init_memory_array(Map.put(mem_array, i - 1, init(block_size)), block_size, i - 1)
  end

  # def read(%Memory{data: data} = memory, addr, :bin) do
  #   <<_first::binary-size(addr), value::binary-size(1), _rest::binary>> = data
  #   value
  # end

  # def read(%Memory{data: data} = memory, addr, _), do: :binary.at(data, addr)

  def read(%Memory{data: data} = _memory, addr), do: :binary.at(data, addr)

  def read_range(%Memory{data: data} = _memory, addr, len), do: :binary.bin_to_list(data, addr, len)

  def read_int(%Memory{data: data} = _memory, addr, size) do 
    <<_first::binary-size(addr), value::integer-size(size), _rest::binary>> = data
    value
  end

  def read_binary(%Memory{data: data} = _memory, addr, len) do
    <<_first::binary-size(addr), value::binary-size(len), _rest::binary>> = data
    value
  end

  def write(%Memory{data: data} = memory, addr, value) do
    <<first::binary-size(addr), _::binary-size(1), rest::binary>> = data
    Map.put(memory, :data, first <> <<value>> <> rest)
  end

  def write_binary(%Memory{data: data} = memory, addr, value, len) do
    <<first::binary-size(addr), _::binary-size(len), rest::binary>> = data
    Map.put(memory, :data, first <> value <> rest)
  end

  def read_array(mem_array, bank, addr), do: read(mem_array[bank], addr)

  def write_array(mem_array, bank, addr, value) do
    new_memory = write(mem_array[bank], addr, value)
    Map.put(mem_array, bank, new_memory)
  end

  def array_size(mem_array), do: map_size(mem_array)
end
