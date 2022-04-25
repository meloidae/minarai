defmodule Gameboy.MutableCartridge.NoMbc do
  use Bitwise
  alias Gameboy.TupleMemory
  alias Gameboy.EtsMemory, as: RWMemory

  @ram_bank_mask 0x1fff

  def init do
    nil
  end

  def read_rom_low(_mbc, rom, addr) do
    TupleMemory.read(rom, addr)
  end

  def read_rom_high(_mbc, rom, addr) do
    # No masking of addr
    TupleMemory.read(rom, addr)
  end

  def read_binary_rom_low(_mbc, rom, addr, len) do
    TupleMemory.read_binary(rom, addr, len)
  end

  def read_binary_rom_high(_mbc, rom, addr, len) do
    # No masking of addr
    TupleMemory.read_binary(rom, addr, len)
  end

  def read_ram(_mbc, ram, addr) do
    RWMemory.read_array(ram, 0x0, addr &&& @ram_bank_mask)
  end

  def write_ram(_mbc, ram, addr, value) do
    RWMemory.write_array(ram, 0x0, addr &&& @ram_bank_mask, value)
  end

  def set_bank_control(_mbc, _rom, _ram, _addr, _value) do
    # NoMbc has no memory bank controller, so does nothing
    nil
  end
end
