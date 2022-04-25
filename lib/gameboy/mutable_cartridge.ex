defmodule Gameboy.MutableCartridge do
  use Bitwise
  alias Gameboy.Utils
  alias Gameboy.TupleMemory
  alias Gameboy.EtsMemory, as: RWMemory
  alias Gameboy.MutableCartridge.NoMbc
  alias Gameboy.MutableCartridge.Mbc1
  alias Gameboy.MutableCartridge.Mbc3

  require Record
  Record.defrecordp(:cartridge,
    mbc_type: nil,
    mbc: nil,
    rom: nil,
    ram: nil
  )

  @path "roms/POKEMON_YELLOW.sgb"

  @cart_type_addr 0x0147
  @rom_size_addr 0x0148
  @ram_size_addr 0x0149
  @bank_size 0x4000
  @ram_bank_size 0x2000

  def init(path \\ nil) do
    path = if is_nil(path) do
      IO.puts("Using default cart path: #{@path}")
      @path
    else
      IO.puts("Using cart path: #{path}")
      path
    end

    data = File.read!(path)
    {mbc_type, mbc} = init_mbc(data)
    rom = init_rom(data)
    ram = init_ram(data)

    cartridge(mbc_type: mbc_type, mbc: mbc, rom: rom, ram: ram)
  end

  def init_mbc(data) do
    case :binary.at(data, @cart_type_addr) do
      0x00 ->
        {:nombc, nil}
      x when x in 0x01..0x03 ->
        {:mbc1, Mbc1.init()}
      x when x in 0x0f..0x13 ->
        {:mbc3, Mbc3.init()}
      x ->
        raise "cart_type = 0x#{Utils.to_hex(x)} is not implemented"
    end
  end

  def init_rom(data) do
    memory = TupleMemory.init(data)
    case :binary.at(data, @rom_size_addr) do
      x when x in 0x00..0x08 ->
        memory
      size ->
        raise "rom_size = 0x#{Utils.to_hex(size)} is not implemented"
    end
  end

  def init_ram(data) do
    case :binary.at(data, @ram_size_addr) do
      0x00 ->
        cart_type = :binary.at(data, @cart_type_addr)
        if (cart_type == 0x5) or (cart_type == 0x6) do
          # Mbc2 has 512kb of 4bits RAM even if ram_size value is 0
          RWMemory.init_array(0x200, 1, :cartram)
        else
          nil
        end
      0x01 ->
        # Not documented (supposedly has 8kb RAM?)
        RWMemory.init_array(@ram_bank_size, 1, :cartram)
      0x02 ->
        RWMemory.init_array(@ram_bank_size, 1, :cartram)
      0x03 ->
        RWMemory.init_array(@ram_bank_size, 4, :cartram)
      0x04 ->
        RWMemory.init_array(@ram_bank_size, 16, :cartram)
      0x05 ->
        RWMemory.init_array(@ram_bank_size, 8, :cartram)
      size ->
        raise "ram_size = 0x#{Utils.to_hex(size)} is not implemented"
    end
  end

  def read_rom_low(cartridge(mbc_type: :nombc, mbc: mbc, rom: rom) = _cart, addr) do
    NoMbc.read_rom_low(mbc, rom, addr)
  end
  def read_rom_low(cartridge(mbc_type: :mbc1, mbc: mbc, rom: rom) = _cart, addr) do
    Mbc1.read_rom_low(mbc, rom, addr)
  end
  def read_rom_low(cartridge(mbc_type: :mbc3, mbc: mbc, rom: rom) = _cart, addr) do
    Mbc3.read_rom_low(mbc, rom, addr)
  end

  def read_rom_high(cartridge(mbc_type: :nombc, mbc: mbc, rom: rom) = _cart, addr) do
    NoMbc.read_rom_high(mbc, rom, addr)
  end
  def read_rom_high(cartridge(mbc_type: :mbc1, mbc: mbc, rom: rom) = _cart, addr) do
    Mbc1.read_rom_high(mbc, rom, addr)
  end
  def read_rom_high(cartridge(mbc_type: :mbc3, mbc: mbc, rom: rom) = _cart, addr) do
    Mbc3.read_rom_high(mbc, rom, addr)
  end

  def read_binary_rom_low(cartridge(mbc_type: :nombc, mbc: mbc, rom: rom) = _cart, addr, len) do
    NoMbc.read_binary_rom_low(mbc, rom, addr, len)
  end
  def read_binary_rom_low(cartridge(mbc_type: :mbc1, mbc: mbc, rom: rom) = _cart, addr, len) do
    Mbc1.read_binary_rom_low(mbc, rom, addr, len)
  end
  def read_binary_rom_low(cartridge(mbc_type: :mbc3, mbc: mbc, rom: rom) = _cart, addr, len) do
    Mbc3.read_binary_rom_low(mbc, rom, addr, len)
  end

  def read_binary_rom_high(cartridge(mbc_type: :nombc, mbc: mbc, rom: rom) = _cart, addr, len) do
    NoMbc.read_binary_rom_high(mbc, rom, addr, len)
  end
  def read_binary_rom_high(cartridge(mbc_type: :mbc1, mbc: mbc, rom: rom) = _cart, addr, len) do
    Mbc1.read_binary_rom_high(mbc, rom, addr, len)
  end
  def read_binary_rom_high(cartridge(mbc_type: :mbc3, mbc: mbc, rom: rom) = _cart, addr, len) do
    Mbc3.read_binary_rom_high(mbc, rom, addr, len)
  end

  def read_ram(cartridge(mbc_type: :nombc, mbc: mbc, ram: ram) = _cart, addr) do
    NoMbc.read_ram(mbc, ram, addr)
  end
  def read_ram(cartridge(mbc_type: :mbc1, mbc: mbc, ram: ram) = _cart, addr) do
    Mbc1.read_ram(mbc, ram, addr)
  end
  def read_ram(cartridge(mbc_type: :mbc3, mbc: mbc, ram: ram) = _cart, addr) do
    Mbc3.read_ram(mbc, ram, addr)
  end

  def write_ram(cartridge(mbc_type: :nombc, mbc: mbc, ram: ram) = _cart, addr, value) do
    NoMbc.write_ram(mbc, ram, addr, value)
  end
  def write_ram(cartridge(mbc_type: :mbc1, mbc: mbc, ram: ram) = _cart, addr, value) do
    Mbc1.write_ram(mbc, ram, addr, value)
  end
  def write_ram(cartridge(mbc_type: :mbc3, mbc: mbc, ram: ram) = _cart, addr, value) do
    Mbc3.write_ram(mbc, ram, addr, value)
  end

  def set_bank_control(cartridge(mbc_type: :nombc, mbc: mbc, rom: rom, ram: ram) = _cart, addr, value) do
    NoMbc.set_bank_control(mbc, rom, ram, addr, value)
  end
  def set_bank_control(cartridge(mbc_type: :mbc1, mbc: mbc, rom: rom, ram: ram) = _cart, addr, value) do
    Mbc1.set_bank_control(mbc, rom, ram, addr, value)
  end
  def set_bank_control(cartridge(mbc_type: :mbc3, mbc: mbc, rom: rom, ram: ram) = _cart, addr, value) do
    Mbc3.set_bank_control(mbc, rom, ram, addr, value)
  end
end
