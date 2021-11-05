defmodule Gameboy.Interrupts do
  use Bitwise
  alias Gameboy.Interrupts
  alias Gameboy.Utils

  def init do
    {0x00, 0x00}
  end

  def interrupt_enable({enable, _} = _intr), do: enable
  def set_interrupt_enable({_, flag} = _intr, value), do: {value &&& 0b11111, flag}

  def interrupt_flag({_, flag} = _intr), do: flag
  def set_interrupt_flag({enable, _} = _intr, value), do: {enable, value &&& 0b11111}

  @vblank_bit 0b1
  @stat_bit 0b10
  @timer_bit 0b100
  @serial_bit 0b1000
  @joypad_bit 0b10000

  def vblank, do: @vblank_bit
  def stat, do: @stat_bit
  def timer, do: @timer_bit
  def serial, do: @serial_bit
  def joypad, do: @joypad_bit

  @intr_table 0..0b11_1111_1111
  |> Enum.map(fn x ->
    enable = x >>> 5
    flag = x &&& 0b1_1111
    cond do
      ((enable &&& 0b1) != 0) and ((flag &&& 0b1) != 0) ->
        {0x40, 0b0000_0001}
      ((enable &&& 0b10) != 0) and ((flag &&& 0b10) != 0) ->
        {0x48, 0b0000_0010}
      ((enable &&& 0b100) != 0) and ((flag &&& 0b100) != 0) ->
        {0x50, 0b0000_0100}
      ((enable &&& 0b1000) != 0) and ((flag &&& 0b1000) != 0) ->
        {0x58, 0b0000_1000}
      ((enable &&& 0b10000) != 0) and ((flag &&& 0b10000) != 0) ->
        {0x60, 0b0001_0000}
      true ->
        nil
    end
  end)
  |> List.to_tuple()

  def check({enable, flag} = _intr) do
    # Check if any enabled interrupt is requested
    # Interrupt priority: vblank > stat > timer > serial > joypad
    elem(@intr_table, (enable <<< 5) ||| flag)
  end

  def request(intr, 0), do: intr
  def request({enable, flag} = _intr, req) do
    {enable, flag ||| req}
  end

  def acknowledge({enable, flag} = _intr, mask) do
    {enable, flag - mask}
  end
end
