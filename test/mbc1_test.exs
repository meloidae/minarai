defmodule Mbc1Test do
  use ExUnit.Case
  use Bitwise
  alias Gameboy.MutableCartridge.Mbc1
  alias Gameboy.TupleMemory
  alias Gameboy.EtsMemory, as: RWMemory

  @bank_size 0x4000
  @ram_bank_size 0x2000
  @rom_size @bank_size * 64
  @ram_banks 4

  defp get_mbc_state(mbc), do: :ets.lookup(mbc, :mbc_state) |> hd()
  defp get_rom do
    1..@rom_size
    |> Enum.map(fn _ -> 0 end)
    |> IO.iodata_to_binary()
    |> TupleMemory.init()
  end

  test "init mbc1" do
    mbc = Mbc1.init()
    expected = {:mbc_state, :simple_rom_bank, 0x01, 0x0, 0x0000, 0x4000, 0x00, false}
    result = get_mbc_state(mbc)
    assert result == expected
  end

  test "set_bank_control mbc1 ram_enable" do
    mbc = Mbc1.init()
    rom = get_rom()
    ram = RWMemory.init_array(@ram_bank_size, @ram_banks, :cartram)

    # Set ram_enable to true
    addr = 0x1fff
    expected = {:mbc_state, :simple_rom_bank, 0x01, 0x0, 0x0000, 0x4000, 0x00, true}
    Mbc1.set_bank_control(mbc, ram, rom, addr, 0xba)
    result = get_mbc_state(mbc)
    assert result == expected

    # Set ram_enable to false
    expected = {:mbc_state, :simple_rom_bank, 0x01, 0x0, 0x0000, 0x4000, 0x00, false}
    Mbc1.set_bank_control(mbc, ram, rom, addr, 0x03)
    result = get_mbc_state(mbc)
    assert result == expected
  end

  test "set_bank_control mbc1 mode" do
    mbc = Mbc1.init()
    rom = get_rom()
    ram = RWMemory.init_array(@ram_bank_size, @ram_banks, :cartram)

    # Set mode to simple_rom_bank
    addr = 0x6000
    expected = {:mbc_state, :simple_rom_bank, 0x01, 0x0, 0x0000, 0x4000, 0x00, false}
    Mbc1.set_bank_control(mbc, rom, ram, addr, 0)
    result = get_mbc_state(mbc)
    assert result == expected

    # Set mode to advanced_or_ram_bank
    expected = {:mbc_state, :advanced_rom_or_ram_bank, 0x01, 0x0, 0x0000, 0x4000, 0x00, false}
    Mbc1.set_bank_control(mbc, rom, ram, addr, 1)
    result = get_mbc_state(mbc)
    assert result == expected
    Mbc1.set_bank_control(mbc, rom, ram, addr, 3)
    result = get_mbc_state(mbc)
    assert result == expected
  end

  test "set_bank_control mbc1 bank1" do
    mbc = Mbc1.init()
    rom = get_rom()
    ram = RWMemory.init_array(@ram_bank_size, @ram_banks, :cartram)

    # Change bank1 to 0x03
    addr = 0x3fff
    expected = {:mbc_state, :simple_rom_bank, 0x03, 0x0, 0x0000, 0xc000, 0x00, false}
    Mbc1.set_bank_control(mbc, rom, ram, addr, 3)
    result = get_mbc_state(mbc)
    assert result == expected
  end

  test "set_bank_control mbc1 bank2" do
    mbc = Mbc1.init()
    rom = get_rom()
    ram = RWMemory.init_array(@ram_bank_size, @ram_banks, :cartram)

    # Change bank2 to 0x01 under simple_rom_bank mode
    addr = 0x5fff
    expected = {:mbc_state, :simple_rom_bank, 0x01, 0x01, 0x0000, 0x84000, 0x00, false}
    Mbc1.set_bank_control(mbc, rom, ram, addr, 1)
    result = get_mbc_state(mbc)
    assert result == expected

    # Change mode to advanced_rom_or_ram_bank
    addr = 0x6000
    expected = {:mbc_state, :advanced_rom_or_ram_bank, 0x01, 0x01, 0x80000, 0x84000, 0x01, false}
    Mbc1.set_bank_control(mbc, rom, ram, addr, 1)
    result = get_mbc_state(mbc)
    assert result == expected
  end

  test "read_rom_low mbc1" do
    mbc = Mbc1.init()
    rom = 0..@rom_size - 1
          |> Enum.map(fn x -> x &&& 0xff end)
          |> IO.iodata_to_binary()
          |> TupleMemory.init()

    addr = 0x2024
    expected = addr &&& 0xff
    result = Mbc1.read_rom_low(mbc, rom, addr)
    assert result == expected
  end

  test "read_rom_high mbc1" do
    mbc = Mbc1.init()
    rom = 0..@rom_size - 1
          |> Enum.map(fn x -> x &&& 0xfe end)
          |> IO.iodata_to_binary()
          |> TupleMemory.init()

    addr = 0x71f1
    expected = ((addr &&& (@bank_size - 1)) ||| 0x4000) &&& 0xfe
    result = Mbc1.read_rom_high(mbc, rom, addr)
    assert result == expected
  end

  test "read_binary_rom_low mbc1" do
    mbc = Mbc1.init()
    rom = 0..@rom_size - 1
          |> Enum.map(fn x -> x &&& 0xfb end)
          |> IO.iodata_to_binary()
          |> TupleMemory.init()

    addr = 0x2089
    len = 10
    expected = addr..addr + len - 1
               |> Enum.map(fn x -> x &&& 0xfb end)
               |> IO.iodata_to_binary()
    result = Mbc1.read_binary_rom_low(mbc, rom, addr, len)
    assert result == expected
  end

  test "read_binary_rom_high mbc1" do
    mbc = Mbc1.init()
    rom = 0..@rom_size - 1
          |> Enum.map(fn x -> x &&& 0xfa end)
          |> IO.iodata_to_binary()
          |> TupleMemory.init()

    addr = 0x5093
    len = 10
    expected = addr..addr + len - 1
               |> Enum.map(fn x -> x &&& 0xfa end)
               |> IO.iodata_to_binary()
    result = Mbc1.read_binary_rom_high(mbc, rom, addr, len)
    assert result == expected
  end

  test "ram mbc1" do
    mbc = Mbc1.init()
    ram = RWMemory.init_array(@ram_bank_size, @ram_banks, :cartram)

    # Write without enabling ram
    addr = 0x12a1
    value = 0x13
    expected = 0
    Mbc1.write_ram(mbc, ram, addr, value)
    result = Mbc1.read_ram(mbc, ram, addr)
    assert result == expected

    # Write after enabling ram
    rom = get_rom()
    expected = 0x13
    Mbc1.set_bank_control(mbc, rom, ram, 0x1fff, 0x0a)
    Mbc1.write_ram(mbc, ram, addr, value)
    result = Mbc1.read_ram(mbc, ram, addr)
    assert result == expected

    # Change ram bank & read (retrieved value should be the default value = 0)
    Mbc1.set_bank_control(mbc, rom, ram, 0x6000, 0x1)
    Mbc1.set_bank_control(mbc, rom, ram, 0x4000, 0x2)
    expected = 0
    result = Mbc1.read_ram(mbc, ram, addr)
    assert result == expected

    # Switch back to previous ram bank
    Mbc1.set_bank_control(mbc, rom, ram, 0x4000, 0x0)
    expected = 0x13
    result = Mbc1.read_ram(mbc, ram, addr)
    assert result == expected
  end
end
