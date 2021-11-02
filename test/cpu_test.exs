defmodule CpuTest do
  use ExUnit.Case
  alias Gameboy.Cpu

  test "rlc" do
    assert Cpu.rlc_u8_byte_carry(0x80) == {0x1, true}
    assert Cpu.rlc_u8_byte_carry(0xff) == {0xff, true}
    assert Cpu.rlc_u8_byte_carry(0x00) == {0x00, false}
    assert Cpu.rlc_u8_byte_carry(0b10010001) == {0b00100011, true}
    assert Cpu.rlc_u8_byte_carry(0b01111111) == {0b11111110, false}
    assert Cpu.rlc_u8_byte_carry(0b11111110) == {0b11111101, true}
  end
end
