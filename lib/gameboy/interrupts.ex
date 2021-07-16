defmodule Gameboy.Interrupts do
  alias Gameboy.Interrupts
  defstruct enable: 0x00,
            flag: 0x00

  def interrupt_enable(%Interrupts{enable: enable}), do: enable

  def interrupt_flag(%Interrupts{flag: flag}), do: flag
end
