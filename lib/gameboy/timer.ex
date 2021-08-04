defmodule Gameboy.Timer do
  defstruct reg_div: 0x00,
            tima: 0x00,
            tma: 0x00,
            tac: 0x00

  @timer_enable 0..0xff
            
end
