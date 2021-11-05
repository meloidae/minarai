defmodule Gameboy.Interrupts do
  use Bitwise
  alias Gameboy.Interrupts
  alias Gameboy.Utils

  defstruct enable: 0x00,
            flag: 0x00

  def init do
    %Interrupts{enable: 0x00, flag: 0x00}
  end

  def interrupt_enable(intr), do: intr.enable
  def set_interrupt_enable(intr, value), do: Map.put(intr, :enable, value)

  def interrupt_flag(intr), do: intr.flag
  def set_interrupt_flag(intr, value), do: Map.put(intr, :flag, value)

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

  @vblank 0..0xff
  |> Enum.map(fn x -> (x &&& 0b1) != 0 end)
  |> List.to_tuple()
  @stat 0..0xff
  |> Enum.map(fn x -> (x &&& 0b10) != 0 end)
  |> List.to_tuple()
  @timer 0..0xff
  |> Enum.map(fn x -> (x &&& 0b100) != 0 end)
  |> List.to_tuple()
  @serial 0..0xff
  |> Enum.map(fn x -> (x &&& 0b1000) != 0 end)
  |> List.to_tuple()
  @joypad 0..0xff
  |> Enum.map(fn x -> (x &&& 0b10000) != 0 end)
  |> List.to_tuple()

  def check(%Interrupts{enable: enable, flag: flag} = _intr) do
    # Check if any enabled interrupt is requested
    # Interrupt priority: vblank > stat > timer > serial > joypad
    cond do
      elem(@vblank, enable) and elem(@vblank, flag) ->
        {0x40, 0b0000_0001}
      elem(@stat, enable) and elem(@stat, flag) ->
        {0x48, 0b0000_0010}
      elem(@timer, enable) and elem(@timer, flag) ->
        {0x50, 0b0000_0100}
      elem(@serial, enable) and elem(@serial, flag) ->
        {0x58, 0b0000_1000}
      elem(@joypad, enable) and elem(@joypad, flag) ->
        {0x60, 0b0001_0000}
      true ->
        nil
    end
  end

  def request(intr, 0), do: intr
  def request(%Interrupts{flag: flag} = intr, req) do
    Map.put(intr, :flag, flag ||| req)
  end

  def acknowledge(%Interrupts{flag: flag} = intr, mask) do
    Map.put(intr, :flag, flag - mask)
  end
end
