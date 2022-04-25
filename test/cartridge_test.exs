defmodule CartridgeTest do
  use ExUnit.Case
  alias Gameboy.MutableCartridge, as: Cartridge
  alias Gameboy.TupleMemory
  alias Gameboy.EtsMemory, as: RWMemory
  alias Gameboy.Mbc1

  @cart_type_addr 0x0147
  @rom_size_addr 0x0148
  @ram_size_addr 0x0149
  @bank_size 0x4000

  defp get_rom_data(opts \\ []) do
    defaults = [cart_type: 0x00, rom_size: 0x00, ram_size: 0x00, rom_banks: 2]
    options = Keyword.merge(defaults, opts)
              |> Enum.into(%{})
    %{cart_type: cart_type, rom_size: rom_size, ram_size: ram_size, rom_banks: rom_banks} = options
    0..@bank_size * rom_banks - 1
    |> Enum.map(fn
      @cart_type_addr -> cart_type
      @rom_size_addr -> rom_size
      @ram_size_addr -> ram_size
      _ -> 0x0
    end)
    |> IO.iodata_to_binary()
  end

  defp delete_ram(ram) do
    :ets.delete(ram)
  end

  test "init_mbc" do
    rom_data = get_rom_data(cart_type: 0x00)
    {mbc_type, _mbc} = Cartridge.init_mbc(rom_data)
    assert mbc_type == :nombc

    rom_data = get_rom_data(cart_type: 0x01)
    {mbc_type, _mbc} = Cartridge.init_mbc(rom_data)
    assert mbc_type == :mbc1

    rom_data = get_rom_data(cart_type: 0x0f)
    {mbc_type, _mbc} = Cartridge.init_mbc(rom_data)
    assert mbc_type == :mbc3

    rom_data = get_rom_data(cart_type: 0xff)
    assert_raise(RuntimeError, fn -> Cartridge.init_mbc(rom_data) end)
  end

  test "init_rom" do
    # Any rom_size value greater than 0x08 should raise error
    rom_data = get_rom_data(cart_type: 0x00, rom_size: 0x09, rom_banks: 4)
    assert_raise(RuntimeError, fn -> Cartridge.init_rom(rom_data) end)
    rom_data = get_rom_data(cart_type: 0x00, rom_size: 0xff, rom_banks: 4)
    assert_raise(RuntimeError, fn -> Cartridge.init_rom(rom_data) end)
  end

  test "init_ram" do
    rom_data = get_rom_data(cart_type: 0x00, ram_size: 0x00)
    ram = Cartridge.init_ram(rom_data)
    assert ram == nil

    # Special case for mbc2
    rom_data = get_rom_data(cart_type: 0x05, ram_size: 0x00)
    ram = Cartridge.init_ram(rom_data)
    assert RWMemory.array_size(ram) == 1
    delete_ram(ram)

    rom_data = get_rom_data(cart_type: 0x02, ram_size: 0x02)
    ram = Cartridge.init_ram(rom_data)
    assert RWMemory.array_size(ram) == 1
    delete_ram(ram)

    rom_data = get_rom_data(cart_type: 0x02, ram_size: 0x03)
    ram = Cartridge.init_ram(rom_data)
    assert RWMemory.array_size(ram) == 4
    delete_ram(ram)

    rom_data = get_rom_data(cart_type: 0x02, ram_size: 0x04)
    ram = Cartridge.init_ram(rom_data)
    assert RWMemory.array_size(ram) == 16
    delete_ram(ram)

    rom_data = get_rom_data(cart_type: 0x02, ram_size: 0x05)
    ram = Cartridge.init_ram(rom_data)
    assert RWMemory.array_size(ram) == 8
    delete_ram(ram)

    rom_data = get_rom_data(cart_type: 0x02, ram_size: 0xff)
    assert_raise(RuntimeError, fn -> Cartridge.init_ram(rom_data) end)
  end
end
