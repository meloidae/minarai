defmodule Gameboy.Joypad do
  use Bitwise
  alias Gameboy.Joypad
  defstruct reg: 0b00001111

  def get(%Joypad{reg: reg} = _joypad), do: reg
  def set(%Joypad{reg: reg} = joypad, value) do
    Map.put(joypad, :reg, (reg &&& 0b11001111) ||| (value &&& 0b00110000))
  end
end
