defmodule Gameboy.Test.Ppu do
  # def ppu_loop(ppu) when ppu.screen.ready, do: ppu
  def ppu_loop(ppu), do: Gameboy.Ppu.do_cycle(ppu, 70224)
end
gb = Gameboy.init()
# Turn on lcd
gb = put_in(gb.hw.ppu, Gameboy.Ppu.set_lcd_control(gb.hw.ppu, 0x91))
ppu = Gameboy.Test.Ppu.ppu_loop(gb.hw.ppu)
