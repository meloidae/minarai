defmodule Gameboy.Interrupts do
  use Bitwise
  alias Gameboy.Interrupts
  alias Gameboy.Utils

  def init do
    0x00
  end

  def interrupt_enable(intr), do: intr >>> 5
  # Keep lower 5 bits (=flag)
  def set_interrupt_enable(intr, value), do: ((value &&& 0b11111) <<< 5) ||| (intr &&& 0b11111)

  def interrupt_flag(intr), do: intr &&& 0b11111
  # Keep higher 5 bits (=enable)
  def set_interrupt_flag(intr, value), do: (intr &&& 0b11_1110_0000 ||| value &&& 0b11111)

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

  # Interrupt priority: vblank > stat > timer > serial > joypad
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

  def check(intr) do
    # Check if any enabled interrupt is requested
    elem(@intr_table, intr)
  end

  def request(intr, 0), do: intr
  def request(intr, req) do
    # Lower 5 bits is flag
    intr ||| req
  end

  def acknowledge(intr, mask) do
    # Lower 5 bits is flag
    intr - mask
  end
end
