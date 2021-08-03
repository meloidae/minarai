defmodule Gameboy.SimplePpu do
  use Bitwise
  alias Gameboy.Memory
  alias Gameboy.SimplePpu, as: Ppu

  defmodule Screen do

    @screen_width 160
    @screen_height 144

    defstruct buffer: nil,
              index: 0,
              enabled: false,
              ready: false

    # @color {<<155, 188, 15>>, <<139, 172, 15>>, <<48, 98, 48>>, <<15, 65, 15>>}
    def init do
      # Buffer using iolist
      buffer = []
      %Screen{buffer: buffer, ready: false}
    end

    # Disable
    def disable(screen), do: Map.put(screen, :enabled, false)
    # Enable
    def enable(screen), do: Map.put(screen, :enabled, true)

    # Screen buffer using iolist
    def write(%Screen{buffer: buffer} = screen, value) do
      Map.put(screen, :buffer, [elem(@color, value) | buffer])
    end
    def vblank(screen), do: Map.put(screen, :ready, true)
    # def hblank(screen), do: Map.put(screen, :buffer, screen.buffer |> IO.iodata_to_binary())
    def flush(screen) do
      %{screen | ready: false, buffer: []}
    end
  end

  @display_enable 0..255 |> Enum.map(fn x -> (x &&& (1 <<< 7)) != 0 end) |> List.to_tuple()
  defstruct vram: struct(Memory),
            oam: struct(Memory),
            mode: :oam_search,
            counter: @oam_search_cycles,
            x: 0,
            lcdc: 0x00,
            lcds: 0x00,
            scy: 0x00,
            scx: 0x00,
            ly: 0x00,
            lyc: 0x00,
            bgp: 0x00,
            screen: nil

  @vram_size 0x4000
  @oam_size 0x100
  @vram_mask 0x1fff
  @byte_mask 0xff

  @oam_search_cycles 20
  @pixel_transfer_cycles 43
  @hblank_cycles 51
  @vblank_cycles 114

  def init do
    vram = Memory.init(@vram_size)
    oam = Memory.init(@oam_size)
    screen = Screen.init()
    %Ppu{vram: vram, oam: oam, counter: 0, screen: screen}
  end

  def read_vram(%Ppu{vram: vram} = _ppu, addr), do: Memory.read(vram, addr &&& @vram_mask)

  defp read_range_vram(%Ppu{vram: vram} = _ppu, addr, len), do: Memory.read_range(vram, addr &&& @vram_mask, len)

  defp read_int_vram(%Ppu{vram: vram} = _ppu, addr, size), do: Memory.read_int(vram, addr &&& @vram_mask, size)

  def write_vram(%Ppu{vram: vram} = ppu, addr, value) do
    Map.put(ppu, :vram, Memory.write(vram, addr &&& @vram_mask, value))
  end

  def lcd_control(%Ppu{lcdc: lcdc} = _ppu), do: lcdc

  def set_lcd_control(%Ppu{} = ppu, value), do: Map.put(ppu, :lcdc, value &&& 0xff)

  def bg_palette(%Ppu{bgp: bgp} = ppu), do: bgp

  def set_bg_palette(%Ppu{} = ppu, value), do: Map.put(ppu, :bgp, value &&& 0xff)

  def scroll_y(%Ppu{scy: scy} = ppu), do: scy
  def set_scroll_y(%Ppu{} = ppu, value), do: Map.put(ppu, :scy, value &&& 0xff)

  def scroll_x(%Ppu{scx: scx} = ppu), do: scx
  def set_scroll_x(%Ppu{} = ppu, value), do: Map.put(ppu, :scx, value &&& 0xff)

  def line_y(%Ppu{ly: ly} = ppu), do: ly
  # ly is read only
  def set_line_y(ppu, _), do: ppu

  def cycle(ppu) do
    enabled = elem(@display_enable, ppu.lcdc)
    if enabled, do: do_cycle(ppu), else: ppu
  end

  defp do_cycle(ppu) do
    counter = ppu.counter - 1
    if counter > 0 do
      Map.put(ppu, :counter, counter)
    else
      case ppu.mode do
        :oam_search ->
          %{ppu | mode: :pixel_transfer, counter: @pixel_transfer_cycles}
        :pixel_transfer ->
          # Draw line
          ppu = draw_scanline(ppu)
          %{ppu | mode: :hblank, counter: @hblank_cycles}
        :hblank ->
          new_ly = ppu.ly + 1
          if new_ly == 144 do
            %{ppu | mode: :vblank, counter: @vblank_cycles, ly: new_ly, screen: Screen.vblank(ppu.screen)}
          else
            %{ppu | mode: :oam_search, counter: @oam_search_cycles, ly: new_ly}
          end
        :vblank ->
          new_ly = ppu.ly + 1
          if new_ly == 153 do
            %{ppu | mode: :oam_search, counter: @oam_search_cycles, ly: 0}
          else
            %{ppu | counter: @vblank_cycles, ly: new_ly}
          end
      end
    end
  end

  @tile_bytes 0..0xffff
  |> Enum.map(fn x ->
    <<l0::size(1), l1::size(1), l2::size(1), l3::size(1),
      l4::size(1), l5::size(1), l6::size(1), l7::size(1),
      h0::size(1), h1::size(1), h2::size(1), h3::size(1),
      h4::size(1), h5::size(1), h6::size(1), h7::size(1)>> = <<x::integer-size(16)>>
    # [(h0 <<< 1) ||| l0, (h1 <<< 1) ||| l1, (h2 <<< 1) ||| l2, (h3 <<< 1) ||| l3,
    #  (h4 <<< 1) ||| l4, (h5 <<< 1) ||| l5, (h6 <<< 1) ||| l6, (h7 <<< 1) ||| l7]
    [(h0 <<< 1) ||| l0, (h1 <<< 1) ||| l1, (h2 <<< 1) ||| l2, (h3 <<< 1) ||| l3,
     (h4 <<< 1) ||| l4, (h5 <<< 1) ||| l5, (h6 <<< 1) ||| l6, (h7 <<< 1) ||| l7]
  end)
  |> List.to_tuple()

  @tiles_per_row 20
  @color {<<155, 188, 15>>, <<139, 172, 15>>, <<48, 98, 48>>, <<15, 65, 15>>}
  defp draw_scanline(ppu) do
    y = ppu.scy + ppu.ly
    tile_line = rem(y, 8) * 2
    row_addr = 0x9800 + (div(y, 8) * 32)
    tile_index = 0
    # Fetch all tile ids for this row
    pixels = read_range_vram(ppu, row_addr + tile_index, @tiles_per_row)
    |> Enum.map(fn tile_id ->
      elem(@tile_bytes, read_int_vram(ppu, 0x8000 + (tile_id * 16) + tile_line, 16))
      |> Enum.map(fn p -> elem(@color, (ppu.bgp >>> (p * 2)) &&& 0x3) end)
    end)
    put_in(ppu.screen.buffer, [ppu.screen.buffer | pixels])
    # palette_color = (ppu.bgp >>> (pixel * 2)) &&& 0x3
    # tile_id = read_vram(ppu, row_addr + tile_index)
    # addr = 0x8000 + (tile_id * 16) + (tile_line * 2)
  end

  def screen_buffer(%Ppu{screen: screen} = _ppu), do: screen.buffer |> IO.iodata_to_binary()
  def flush_screen_buffer(%Ppu{screen: screen} = ppu) do
    Map.put(ppu, :screen, Screen.flush(screen))
  end

end
