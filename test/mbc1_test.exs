defmodule Mbc1Test do
  use ExUnit.Case
  alias Gameboy.MutableCartridge.Mbc1
  alias Gameboy.TupleMemory
  alias Gameboy.EtsMemory, as: RWMemory

  @bank_size 0x4000
  @rom_size @bank_size * 64
  @ram_banks 8

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
    assert expected == result
  end

  test "set_bank_control mbc1 ram_enable" do
    mbc = Mbc1.init()
    rom = get_rom()
    ram = RWMemory.init_array(@bank_size, @ram_banks, :cartram)

    # Set ram_enable to true
    addr = 0x1fff
    expected = {:mbc_state, :simple_rom_bank, 0x01, 0x0, 0x0000, 0x4000, 0x00, true}
    Mbc1.set_bank_control(mbc, ram, rom, addr, 0xba)
    result = get_mbc_state(mbc)
    assert expected == result

    # Set ram_enable to false
    expected = {:mbc_state, :simple_rom_bank, 0x01, 0x0, 0x0000, 0x4000, 0x00, false}
    Mbc1.set_bank_control(mbc, ram, rom, addr, 0x03)
    result = get_mbc_state(mbc)
    assert expected == result
  end

  test "set_bank_control mbc1 mode" do
    mbc = Mbc1.init()
    rom = get_rom()
    ram = RWMemory.init_array(@bank_size, @ram_banks, :cartram)

    # Set mode to simple_rom_bank
    addr = 0x6000
    expected = {:mbc_state, :simple_rom_bank, 0x01, 0x0, 0x0000, 0x4000, 0x00, false}
    Mbc1.set_bank_control(mbc, rom, ram, addr, 0)
    result = get_mbc_state(mbc)
    assert expected == result

    # Set mode to advanced_or_ram_bank
    expected = {:mbc_state, :advanced_rom_or_ram_bank, 0x01, 0x0, 0x0000, 0x4000, 0x00, false}
    Mbc1.set_bank_control(mbc, rom, ram, addr, 1)
    result = get_mbc_state(mbc)
    assert expected == result
    Mbc1.set_bank_control(mbc, rom, ram, addr, 3)
    result = get_mbc_state(mbc)
    assert expected == result
  end

  test "set_bank_control mbc1 bank1" do
    mbc = Mbc1.init()
    rom = get_rom()
    ram = RWMemory.init_array(@bank_size, @ram_banks, :cartram)

    # Change bank1 to 0x03
    addr = 0x3fff
    expected = {:mbc_state, :simple_rom_bank, 0x03, 0x0, 0x0000, 0xc000, 0x00, false}
    Mbc1.set_bank_control(mbc, rom, ram, addr, 3)
    result = get_mbc_state(mbc)
    assert expected == result
  end

  test "set_bank_control mbc1 bank2" do
    mbc = Mbc1.init()
    rom = get_rom()
    ram = RWMemory.init_array(@bank_size, @ram_banks, :cartram)

    # Change bank2 to 0x01 under simple_rom_bank mode
    addr = 0x5fff
    expected = {:mbc_state, :simple_rom_bank, 0x01, 0x01, 0x0000, 0x84000, 0x00, false}
    Mbc1.set_bank_control(mbc, rom, ram, addr, 1)
    result = get_mbc_state(mbc)
    assert expected == result

    # Change mode to advanced_rom_or_ram_bank
    addr = 0x6000
    expected = {:mbc_state, :advanced_rom_or_ram_bank, 0x01, 0x01, 0x80000, 0x84000, 0x01, false}
    Mbc1.set_bank_control(mbc, rom, ram, addr, 1)
    result = get_mbc_state(mbc)
    assert expected == result
  end
end
