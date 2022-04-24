defmodule Mbc3Test do
  use ExUnit.Case
  use Bitwise
  alias Gameboy.MutableCartridge.Mbc3
  alias Gameboy.TupleMemory
  alias Gameboy.EtsMemory, as: RWMemory

  @bank_size 0x4000
  @rom_size @bank_size * 64
  @ram_banks 4

  defp get_mbc_state(mbc), do: :ets.lookup(mbc, :mbc_state) |> hd()
  defp get_rom do
    1..@rom_size
    |> Enum.map(fn _ -> 0 end)
    |> IO.iodata_to_binary()
    |> TupleMemory.init()
  end
  defp get_rom(data) do
    IO.iodata_to_binary(data)
    |> TupleMemory.init()
  end

  test "init mbc3" do
    mbc = Mbc3.init()
    expected = {:mbc_state, 0x4000, 0x00, false, 0x00, 0x00, 0x00, 0x00, 0x00, nil}
    result = get_mbc_state(mbc)
    assert result == expected
  end

  test "set_bank_control mbc3 ram_enable" do
    mbc = Mbc3.init()
    rom = get_rom()
    ram = RWMemory.init_array(@bank_size, @ram_banks, :cartram)

    # Set ram_rtc_enable to true
    addr = 0x1fff
    expected = {:mbc_state, 0x4000, 0x00, true, 0x00, 0x00, 0x00, 0x00, 0x00, nil}
    Mbc3.set_bank_control(mbc, rom, ram, addr, 0xca)
    result = get_mbc_state(mbc)
    assert result == expected

    # Set ram_rtc_enable to false
    expected = {:mbc_state, 0x4000, 0x00, false, 0x00, 0x00, 0x00, 0x00, 0x00, nil}
    Mbc3.set_bank_control(mbc, rom, ram, addr, 0x01)
    result = get_mbc_state(mbc)
    assert result == expected
  end

  test "set_bank_control mbc3 ROM bank" do
    mbc = Mbc3.init()
    rom = get_rom()
    ram = RWMemory.init_array(@bank_size, @ram_banks, :cartram)

    # Set ROM bank number to 0x02
    addr = 0x3fff
    expected = {:mbc_state, 0x8000, 0x00, false, 0x00, 0x00, 0x00, 0x00, 0x00, nil}
    Mbc3.set_bank_control(mbc, rom, ram, addr, 0x02)
    result = get_mbc_state(mbc)
    assert result == expected

    # Try to set ROM bank number to 0x00 (should be changed to 0x01 instead)
    expected = {:mbc_state, 0x4000, 0x00, false, 0x00, 0x00, 0x00, 0x00, 0x00, nil}
    Mbc3.set_bank_control(mbc, rom, ram, addr, 0x00)
    result = get_mbc_state(mbc)
    assert result == expected
  end

  test "set_bank_control mbc3 RAM bank or RTC register" do
    mbc = Mbc3.init()
    rom = get_rom()
    ram = RWMemory.init_array(@bank_size, @ram_banks, :cartram)

    # Set RAM bank number to 0x02
    addr = 0x5fff
    expected = {:mbc_state, 0x4000, 0x02, false, 0x00, 0x00, 0x00, 0x00, 0x00, nil}
    Mbc3.set_bank_control(mbc, rom, rom, addr, 0x02)
    result = get_mbc_state(mbc)
    assert result == expected

    # Try to set RAM bank number to 0x05 (should be ignored)
    Mbc3.set_bank_control(mbc, rom, ram, addr, 0x05)
    result = get_mbc_state(mbc)
    assert result == expected

    # Set RAM bank number to 0x0c
    expected = {:mbc_state, 0x4000, 0x0c, false, 0x00, 0x00, 0x00, 0x00, 0x00, nil}
    Mbc3.set_bank_control(mbc, rom, rom, addr, 0x0c)
    result = get_mbc_state(mbc)
    assert result == expected
  end

  test "set_bank_control mbc3 latch clock" do
    mbc = Mbc3.init()
    rom = get_rom()
    ram = RWMemory.init_array(@bank_size, @ram_banks, :cartram)

    # Set latch clock to 0, then 1 (should end up as 1)
    addr = 0x6000
    expected = {:mbc_state, 0x4000, 0x00, false, 0x00, 0x00, 0x00, 0x00, 0x00, 0x1}
    Mbc3.set_bank_control(mbc, rom, ram, addr, 0x00)
    Mbc3.set_bank_control(mbc, rom, ram, addr, 0x01)
    result = get_mbc_state(mbc)
    assert result == expected

    # Set latch clock to 0, then 2 (non 0->1 sequence should end up in nil)
    expected = {:mbc_state, 0x4000, 0x00, false, 0x00, 0x00, 0x00, 0x00, 0x00, nil}
    Mbc3.set_bank_control(mbc, rom, ram, addr, 0x00)
    Mbc3.set_bank_control(mbc, rom, ram, addr, 0x02)
    result = get_mbc_state(mbc)
    assert result == expected

    # Set latch clock to 1 without setting it to 0 first (should result in nil)
    Mbc3.set_bank_control(mbc, rom, ram, addr, 0x01)
    result = get_mbc_state(mbc)
    assert result == expected
  end

  test "read_rom_low mbc3" do
    mbc = Mbc3.init()
    data = 0..@rom_size - 1
           |> Enum.map(fn
             0x2003 -> 0x1
             _ -> 0x0
           end)
    rom = get_rom(data)

    # Retrieve non-zero
    addr = 0x2003
    expected = 0x1
    result = Mbc3.read_rom_low(mbc, rom, addr)
    assert result == expected

    # Retrieve zero
    addr = 0x2004
    expected = 0x0
    result = Mbc3.read_rom_low(mbc, rom, addr)
    assert result == expected
  end

  test "read_rom_high mbc3" do
    mbc = Mbc3.init()
    data = 0..@rom_size - 1
           |> Enum.map(fn
             0x4004 -> 0x1
             0x9020 -> 0x1
             _ -> 0x0
           end)
    rom = get_rom(data)
    ram = RWMemory.init_array(@bank_size, @ram_banks, :cartram)

    # Retrive 1st non-zero from bank
    addr = 0x0004
    expected = 0x1
    result = Mbc3.read_rom_high(mbc, rom, addr)
    assert result == expected

    # Switch to 2nd bank and retrive non-zero
    Mbc3.set_bank_control(mbc, rom, ram, 0x3fff, 0x2)
    addr = 0x1020
    result = Mbc3.read_rom_high(mbc, rom, addr)
    assert result == expected
  end

  test "ram mbc3" do
    mbc = Mbc3.init()
    rom = get_rom()
    ram = RWMemory.init_array(@bank_size, @ram_banks, :cartram)

    # Try to write without enabling ram (attempted write is ignored)
    addr = 0x0004
    expected = 0x0
    Mbc3.write_ram(mbc, ram, addr, 0x01)
    result = Mbc3.read_ram(mbc, ram, addr)
    assert result == expected

    # Write after enabling ram
    Mbc3.set_bank_control(mbc, rom, ram, 0x1fff, 0x0a)
    expected = 0x1
    Mbc3.write_ram(mbc, ram, addr, 0x01)
    result = Mbc3.read_ram(mbc, ram, addr)
    assert result == expected

    # Switch ram bank and write
    addr = 0x1043
    # Switch to bank 3
    Mbc3.set_bank_control(mbc, rom, ram, 0x5fff, 0x03)
    Mbc3.write_ram(mbc, ram, addr, 0x01)
    # Back to bank 0
    Mbc3.set_bank_control(mbc, rom, ram, 0x5fff, 0x00)
    expected = 0x0
    result = Mbc3.read_ram(mbc, ram, addr)
    assert result == expected
    # Switch to bank 3
    expected = 0x01
    Mbc3.set_bank_control(mbc, rom, ram, 0x5fff, 0x03)
    result = Mbc3.read_ram(mbc, ram, addr)
    assert result == expected

    # Switch to rtc register and write (addr is ignored for read/write to rtc registers)
    Mbc3.set_bank_control(mbc, rom, ram, 0x5fff, 0x08)
    addr = 0x1300
    expected = 0x1
    Mbc3.write_ram(mbc, ram, addr, 0x01)
    addr = 0x1489
    result = Mbc3.read_ram(mbc, ram, addr)
    assert result == expected
  end
end
