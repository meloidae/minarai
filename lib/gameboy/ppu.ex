defmodule Gameboy.PPU do
  alias Gameboy.Memory
  alias Gameboy.PPU

  defstruct vram: struct(Memory), oam: struct(Memory)

  @vram_size 0x4000
  @oam_size 0x100

  def init do
    vram = Memory.init(@vram_size)
    oam = Memory.init(@oam_size)
    %PPU{vram: vram, oam: oam}
  end
end
