defmodule Gameboy.PPU do
  use Bitwise
  alias Gameboy.Memory
  alias Gameboy.PPU

  defstruct vram: struct(Memory),
            oam: struct(Memory),
            mode: :oamsearch,
            lcdc: 0x00,
            lcds: 0x00,
            scy: 0x00,
            scx: 0x00,
            ly: 0x00,
            lyc: 0x00,
            bgp: 0x00



  @vram_size 0x4000
  @oam_size 0x100
  @vram_mask 0x1fff
  @byte_mask 0xff

  def init do
    vram = Memory.init(@vram_size)
    oam = Memory.init(@oam_size)
    %PPU{vram: vram, oam: oam}
  end

  def read_vram(%PPU{vram: vram} = ppu, addr), do: Memory.read(vram, addr &&& @vram_mask)

  def write_vram(%PPU{vram: vram} = ppu, addr, value) do
    put_in(ppu.vram, Memory.write(vram, addr &&& @vram_mask, value))
  end

  def bg_palette(%PPU{bgp: bgp} = ppu), do: bgp

  def set_bg_palette(%PPU{} = ppu, value), do: put_in(ppu.bgp, value &&& 0xff)
end
