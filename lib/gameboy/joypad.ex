defmodule Gameboy.Joypad do
  use Bitwise
  alias Gameboy.Joypad
  alias Gameboy.Interrupts

  # Use an 8-bit register to store states of 8 keys
  @start 0b1000_0000
  @select 0b0100_0000
  @b_button 0b0010_0000
  @a_button 0b0001_0000
  @down 0b0000_1000
  @up 0b0000_0100
  @left 0b0000_0010
  @right 0b0000_0001

  # Whether selected layout is directionals, buttons, or neither
  # Directionals have precedence here, but that may not be accurate
  @selected_layout 0..0xff
  |> Enum.map(fn x ->
    cond do
      (x &&& 0b00_01_0000) === 0 ->
        :direction
      (x &&& 0b00_10_0000) === 0 ->
        :button
      true ->
        nil
    end
  end)
  |> List.to_tuple()

  def init do
    reg = 0b0000_1111
    keys = 0b1111_1111
    {reg, keys}
  end


  key_names = [:start, :select, :b, :a, :down, :up, :left, :right]
  key_bytes = [@start, @select, @b_button, @a_button, @down, @up, @left, @right]
  key_type = List.duplicate(:button, 4) ++ List.duplicate(:direction, 4)
  # When a key is pressed
  for {name, bits, type} <- Enum.zip([key_names, key_bytes, key_type]) do
    reset = ~~~bits &&& 0xff
    if type === :button do
      def keydown({reg, keys} = _joypad, unquote(name)) do
        keys = keys &&& unquote(reset)
        if elem(@selected_layout, reg) === :button do
          {{(reg &&& 0b0011_0000) ||| (keys >>> 4), keys}, Interrupts.joypad()}
        else
          {{reg, keys}, Interrupts.joypad()}
        end
      end
    else
      def keydown({reg, keys} = _joypad, unquote(name)) do
        keys = keys &&& unquote(reset)
        if elem(@selected_layout, reg) === :direction do
          {{(reg &&& 0b0011_0000) ||| (keys &&& 0x0f), keys}, Interrupts.joypad()}
        else
          {{reg, keys}, Interrupts.joypad()}
        end
      end
    end
  end
  # When a key is released
  for {name, bits, type} <- Enum.zip([key_names, key_bytes, key_type]) do
    if type === :button do
      def keyup({reg, keys} = _joypad, unquote(name)) do
        keys = keys ||| unquote(bits)
        if elem(@selected_layout, reg) === :button do
          {(reg &&& 0b0011_0000) ||| (keys >>> 4), keys}
        else
          {reg, keys}
        end
      end
    else
      def keyup({reg, keys} = _joypad, unquote(name)) do
        keys = keys |||  unquote(bits)
        if elem(@selected_layout, reg) === :direction do
          {(reg &&& 0b0011_0000) ||| (keys &&& 0x0f), keys}
        else
          {reg, keys}
        end
      end
    end
  end

  def get({reg, _keys} = _joypad), do: reg
  def set({reg, keys} = _joypad, value) do
    value = value &&& 0b0011_0000
    reg = case elem(@selected_layout, value) do
      :direction ->
        value ||| (keys &&& 0x0f)
      :button ->
        value ||| (keys >>> 4)
      nil ->
        value ||| 0b1111
    end
    {reg, keys}
  end
end
