defmodule NoMbcTest do
  use ExUnit.Case
  alias Gameboy.MutableCartridge.NoMbc
  alias Gameboy.EtsMemory, as: RWMemory

  @ram_bank_size 0x2000
  @ram_banks 0x4

  test "init nombc" do
    mbc = NoMbc.init()
    assert mbc == nil
  end

  test "set_bank_control nombc" do
    mbc = NoMbc.init()
    assert NoMbc.set_bank_control(mbc, nil, nil, 0x1fff, 0x01) == nil
  end

  test "ram nombc" do
    mbc = NoMbc.init()
    ram = RWMemory.init_array(@ram_bank_size, @ram_banks, :cartram)

    # Write and check value
    addr = 0x12a1
    value = 0x13
    expected = 0x13
    NoMbc.write_ram(mbc, ram, addr, value)
    result = NoMbc.read_ram(mbc, ram, addr)
    assert result == expected
  end
end
