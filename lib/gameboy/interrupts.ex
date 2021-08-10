defmodule Gameboy.Interrupts do
  use Bitwise
  alias Gameboy.Interrupts
  # defstruct enable: nil,
  #           flag: nil

  @enable_index 1
  @flag_index 2
  def init do
    :atomics.new(2, [signed: false])
  end

  # def interrupt_enable(interrupts), do: interrupts.enable
  # def interrupt_flag(interrupts), do: interrupts.flag

  def interrupt_enable(intr), do: :atomics.get(intr, @enable_index)
  def set_interrupt_enable(intr, value), do: :atomics.put(intr, @enable_index, value)

  def interrupt_flag(intr), do: :atomics.get(intr, @flag_index)
  def set_interrupt_flag(intr, value), do: :atomics.put(intr, @flag_index, value)

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

  def check(intr) do
    # Check if any enabled interrupt is requested
    # Interrupt priority: vblank > stat > timer > serial > joypad
    enable = interrupt_enable(intr)
    flag = interrupt_flag(intr)
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

  def request(intr, :vblank) do
    flag = :atomics.get(intr, @flag_index)
    if !elem(@vblank, flag), do: :atomics.add(intr, @flag_index, 0b0000_0001)
  end

  def request(intr, :stat) do
    flag = :atomics.get(intr, @flag_index)
    if !elem(@stat, flag), do: :atomics.add(intr, @flag_index, 0b0000_0010)
  end

  def request(intr, :timer) do
    flag = :atomics.get(intr, @flag_index)
    if !elem(@timer, flag), do: :atomics.add(intr, @flag_index, 0b0000_0100)
  end

  def request(intr, :serial) do
    flag = :atomics.get(intr, @flag_index)
    if !elem(@serial, flag), do: :atomics.add(intr, @flag_index, 0b0000_1000)
  end

  def request(intr, :joypad) do
    flag = :atomics.get(intr, @flag_index)
    if !elem(@joypad, flag), do: :atomics.add(intr, @flag_index, 0b0001_0000)
  end


  def acknowledge(intr, mask) do
    :atomics.sub(intr, @flag_index, mask)
  end
end
