defmodule Gameboy.SimplePpu do
  use Bitwise
  alias Gameboy.Memory
  alias Gameboy.SimplePpu, as: Ppu
  alias Gameboy.Interrupts

  defmodule Screen do

    @screen_width 160
    @screen_height 144

    defstruct buffer: nil
              # index: 0,
              # enabled: false,
              #ready: false

    # @color {<<155, 188, 15>>, <<139, 172, 15>>, <<48, 98, 48>>, <<15, 65, 15>>}
    def init do
      # Buffer using iolist
      buffer = []
      # %Screen{buffer: buffer, ready: false}
      %Screen{buffer: buffer}
    end

    def vblank(screen) do
      # send(Minarai, {:update, screen.buffer |> IO.iodata_to_binary()})
      # Map.put(screen, :ready, true)
      screen
    end
    # def hblank(screen), do: Map.put(screen, :buffer, screen.buffer |> IO.iodata_to_binary())
    def flush(screen) do
      # %{screen | ready: false, buffer: []}
      Map.put(screen, :buffer, [])
    end
  end

  @vram_size 0x4000
  @oam_size 0xa0
  @vram_mask 0x1fff
  @byte_mask 0xff

  @oam_search_cycles 20
  @pixel_transfer_cycles 43
  @hblank_cycles 51
  @vblank_cycles 114

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
            wx: 0x00,
            wy: 0x00,
            bgp: 0x00,
            obp0: 0x00,
            obp1: 0x00,
            # screen: nil
            buffer: []

  @display_enable 0..0xff |> Enum.map(fn x -> (x &&& (1 <<< 7)) != 0 end) |> List.to_tuple()
  @window_tile_map_addr 0..0xff |> Enum.map(fn x ->
    if (x &&& (1 <<< 6)) != 0, do: 0x9c00, else: 0x9800
  end)
  |> List.to_tuple()
  @window_enable 0..0xff |> Enum.map(fn x -> (x &&& (1 <<< 5)) != 0 end) |> List.to_tuple()
  @tile_data_addr 0..0xff |> Enum.map(fn x -> (x &&& (1 <<< 4)) != 0 end)
  |> List.to_tuple()
  @bg_tile_map_addr 0..0xff |> Enum.map(fn x ->
    if (x &&& (1 <<< 3)) != 0, do: 0x1c00, else: 0x1800
  end)
  |> List.to_tuple()
  @obj_size 0..0xff |> Enum.map(fn x ->
    if (x &&& (1 <<< 2)) != 0, do: 16, else: 8
  end)
  |> List.to_tuple()
  @obj_enable 0..0xff |> Enum.map(fn x -> (x &&& (1 <<< 1)) != 0 end) |> List.to_tuple()
  @bg_enable 0..0xff |> Enum.map(fn x -> (x &&& 1) != 0 end) |> List.to_tuple()

  def init do
    vram = Memory.init(@vram_size)
    oam = Memory.init(@oam_size)
    # screen = Screen.init()
    # %Ppu{vram: vram, oam: oam, counter: 0, screen: screen}
    %Ppu{vram: vram, oam: oam, counter: 0}
  end

  def read_oam(%Ppu{mode: mode, oam: oam} = _ppu, addr) do
    # oam is not accessible during pixel transfer & oam search
    if mode == :pixel_transfer or mode == :oam_search do
      0xff
    else
      Memory.read(oam, addr)
    end
  end

  def write_oam(%Ppu{mode: mode, oam: oam} = ppu, addr, value) do
    # oam is not accessible during pixel transfer & oam search
    if mode == :pixel_transfer or mode == :oam_search do
      ppu
    else
      Map.put(ppu, :oam, Memory.write(oam, addr, value))
    end
  end

  defp write_binary_oam(%Ppu{oam: oam} = ppu, addr, value, len) do
    Map.put(ppu, :oam, Memory.write_binary(oam, addr, value, len))
  end

  def read_vram(%Ppu{mode: mode, vram: vram} = _ppu, addr) do
    if mode == :pixel_transfer do
      # vram is not accessible during pixel transfer (mode 3)
      0xff
    else
      Memory.read(vram, addr &&& @vram_mask)
    end
  end

  def read_binary_vram(%Ppu{vram: vram} = _ppu, addr, len) do
    Memory.read_binary(vram, addr &&& @vram_mask, len)
  end

  defp read_range_vram(%Ppu{vram: vram} = _ppu, addr, len), do: Memory.read_range(vram, addr &&& @vram_mask, len)

  defp read_int_vram(%Ppu{vram: vram} = _ppu, addr, size), do: Memory.read_int(vram, addr &&& @vram_mask, size)

  defp read_vram_no_mask(%Ppu{vram: vram} = _ppu, addr), do: Memory.read(vram, addr)
  defp read_range_vram_no_mask(%Ppu{vram: vram} = _ppu, addr, len), do: Memory.read_range(vram, addr, len)
  defp read_int_vram_no_mask(%Ppu{vram: vram} = _ppu, addr, size), do: Memory.read_int(vram, addr, size)

  def write_vram(%Ppu{mode: mode, vram: vram} = ppu, addr, value) do
    if mode == :pixel_transfer do
      # vram is not accessible during pixel transfer (mode 3)
      ppu
    else 
      Map.put(ppu, :vram, Memory.write(vram, addr &&& @vram_mask, value))
    end
  end

  def lcd_control(%Ppu{lcdc: lcdc} = _ppu), do: lcdc

  def set_lcd_control(%Ppu{} = ppu, value), do: Map.put(ppu, :lcdc, value &&& 0xff)

  def lcd_status(%Ppu{mode: :hblank} = ppu) do
    if ppu.ly === ppu.lyc do
      ppu.lcds ||| 0b100
    else
      # Lower 3 bits are 0b000 so no point in binary or
      ppu.lcds
    end
  end
  def lcd_status(%Ppu{mode: :vblank} = ppu) do
    if ppu.ly === ppu.lyc do
      ppu.lcds ||| 0b101
    else
      ppu.lcds ||| 0b001
    end
  end
  def lcd_status(%Ppu{mode: :oam_search} = ppu) do
    if ppu.ly === ppu.lyc do
      ppu.lcds ||| 0b110
    else
      ppu.lcds ||| 0b010
    end
  end
  def lcd_status(%Ppu{mode: :pixel_transfer} = ppu) do
    if ppu.ly === ppu.lyc do
      ppu.lcds ||| 0b111
    else
      ppu.lcds ||| 0b011
    end
  end

  def set_lcd_status(ppu, value) do
    # Only bit 3-6 are writable
    Map.put(ppu, :lcds, value &&& 0b0111_1000)
  end

  def bg_palette(%Ppu{bgp: bgp} = ppu), do: bgp

  def set_bg_palette(%Ppu{} = ppu, value), do: Map.put(ppu, :bgp, value &&& 0xff)

  def ob_palette0(ppu), do: ppu.obp0
  def set_ob_palette0(ppu, value), do: Map.put(ppu, :obp0, value)
  def ob_palette1(ppu), do: ppu.obp1
  def set_ob_palette1(ppu, value), do: Map.put(ppu, :obp0, value)

  def scroll_y(%Ppu{scy: scy} = _ppu), do: scy
  def set_scroll_y(%Ppu{} = ppu, value), do: Map.put(ppu, :scy, value &&& 0xff)

  def scroll_x(%Ppu{scx: scx} = _ppu), do: scx
  def set_scroll_x(%Ppu{} = ppu, value), do: Map.put(ppu, :scx, value &&& 0xff)

  def line_y(%Ppu{ly: ly} = _ppu), do: ly
  # ly is read only
  def set_line_y(ppu, _), do: ppu

  def line_y_compare(%Ppu{lyc: lyc} = _ppu), do: lyc
  def set_line_y_compare(%Ppu{lyc: lyc} = ppu, value), do: Map.put(ppu, :lyc, value &&& 0xff)

  def window_x(%Ppu{wx: wx} = _ppu), do: wx
  def set_window_x(%Ppu{} = ppu, value), do: Map.put(ppu, :wx, value &&& 0xff)

  def window_y(%Ppu{wy: wy} = _ppu), do: wy
  def set_window_y(%Ppu{} = ppu, value), do: Map.put(ppu, :wy, value &&& 0xff)

  # Instantaneous transfer for now
  def oam_dma_transfer(ppu, data, size) do
    write_binary_oam(ppu, 0x00, data, size)
  end

  @lyc_stat 0..0xff
  |> Enum.map(fn x -> (x &&& (1 <<< 6)) != 0 end)
  |> List.to_tuple()
  @oam_stat 0..0xff
  |> Enum.map(fn x -> (x &&& (1 <<< 5)) != 0 end)
  |> List.to_tuple()
  @vblank_stat 0..0xff
  |> Enum.map(fn x -> (x &&& (1 <<< 4)) != 0 end)
  |> List.to_tuple()
  @hblank_stat 0..0xff
  |> Enum.map(fn x -> (x &&& (1 <<< 3)) != 0 end)
  |> List.to_tuple()

  def cycle(ppu, intr) do
    if elem(@display_enable, ppu.lcdc), do: do_cycle(ppu, intr), else: ppu
  end

  defp do_cycle(ppu, intr) do
    counter = ppu.counter - 1
    if counter > 0 do
      Map.put(ppu, :counter, counter)
    else
      case ppu.mode do
        :oam_search ->
          %{ppu | mode: :pixel_transfer, counter: @pixel_transfer_cycles}
        :pixel_transfer ->
          # Draw line
          # ppu = draw_scanline(ppu)
          pixels = draw_scanline(ppu)
          if elem(@hblank_stat, ppu.lcds), do: Interrupts.request(intr, :stat)
          %{ppu | mode: :hblank, counter: @hblank_cycles, buffer: [ppu.buffer | pixels]}
          # %{ppu | mode: :hblank, counter: @hblank_cycles, buffer: [pixels | ppu.buffer]}
        :hblank ->
          new_ly = ppu.ly + 1
          if new_ly == 144 do
            Interrupts.request(intr, :vblank)
            if elem(@vblank_stat, ppu.lcds), do: Interrupts.request(intr, :stat)
            if elem(@lyc_stat, ppu.lcds) and new_ly === ppu.lyc, do: Interrupts.request(intr, :stat)
            # %{ppu | mode: :vblank, counter: @vblank_cycles, ly: new_ly, screen: Screen.vblank(ppu.screen)}
            vblank(ppu)
            %{ppu | mode: :vblank, counter: @vblank_cycles, ly: new_ly}
          else
            if elem(@oam_stat, ppu.lcds), do: Interrupts.request(intr, :stat)
            if elem(@lyc_stat, ppu.lcds) and new_ly === ppu.lyc, do: Interrupts.request(intr, :stat)
            %{ppu | mode: :oam_search, counter: @oam_search_cycles, ly: new_ly}
          end
        :vblank ->
          new_ly = ppu.ly + 1
          if new_ly == 153 do
            if elem(@oam_stat, ppu.lcds), do: Interrupts.request(intr, :stat)
            if elem(@lyc_stat, ppu.lcds) and new_ly === ppu.lyc, do: Interrupts.request(intr, :stat)
            # %{ppu | mode: :oam_search, counter: @oam_search_cycles, ly: 0, screen: Screen.flush(ppu.screen)}
            %{ppu | mode: :oam_search, counter: @oam_search_cycles, ly: 0, buffer: []}
          else
            if elem(@lyc_stat, ppu.lcds) and new_ly === ppu.lyc, do: Interrupts.request(intr, :stat)
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

  @tile_bytes_rev 0..0xffff
  |> Enum.map(fn x ->
    <<l0::size(1), l1::size(1), l2::size(1), l3::size(1),
      l4::size(1), l5::size(1), l6::size(1), l7::size(1),
      h0::size(1), h1::size(1), h2::size(1), h3::size(1),
      h4::size(1), h5::size(1), h6::size(1), h7::size(1)>> = <<x::integer-size(16)>>
    [(h7 <<< 1) ||| l7, (h6 <<< 1) ||| l6, (h5 <<< 1) ||| l5, (h4 <<< 1) ||| l4,
     (h3 <<< 1) ||| l3, (h2 <<< 1) ||| l2, (h1 <<< 1) ||| l1, (h0 <<< 1) ||| l0]
  end)
  |> List.to_tuple()

  @tiles_per_row 20
  # @color {<<155, 188, 15>>, <<139, 172, 15>>, <<48, 98, 48>>, <<15, 65, 15>>}
  @color {<<0xe0, 0xf0, 0xe7>>, <<0x8b, 0xa3, 0x94>>, <<0x55, 0x64, 0x5a>>, <<0x34, 0x3d, 0x37>>}
  @tile_id_8800 0..0xff
  |> Enum.map(fn x -> if x < 0x80, do: x, else: x - 256 end)
  |> List.to_tuple()

  @off_color 0..0xff
  |> Enum.map(fn x -> (x &&& 0x03) end)
  |> List.to_tuple()

  @prioritize_bg 0..0xff
  |> Enum.map(fn x -> (x &&& (1 <<< 7)) != 0 end)
  |> List.to_tuple()

  @flip_y 0..0xff
  |> Enum.map(fn x -> (x &&& (1 <<< 6)) != 0 end)
  |> List.to_tuple()

  @flip_x 0..0xff
  |> Enum.map(fn x -> (x &&& (1 <<< 5)) != 0 end)
  |> List.to_tuple()

  @palette_flag 0..0xff
  |> Enum.map(fn x -> (x &&& (1 <<< 4)) != 0 end)
  |> List.to_tuple()


  defp get_sprite_map(%Ppu{oam: oam, vram: vram, lcdc: lcdc, ly: ly, obp0: obp0, obp1: obp1} = _ppu) do
    sprite_size = elem(@obj_size, lcdc)
    Memory.read_binary(oam, 0, @oam_size)
    |> chunk([])
    |> Stream.filter(fn {y, _, _, _} -> ((ly - y + 16) &&& 0xff) < sprite_size end)
    |> Stream.take(10)
    |> Stream.filter(fn {_, x, _, _} ->
      x > 0 and x < 168
    end)
    |> Stream.with_index()
    |> Enum.sort(fn {{_, x0, _, _}, i0}, {{_, x1, _, _}, i1} -> 
      # cond do
      #   x0 < x1 -> true
      #   x0 === x1 and i0 > i1 -> true
      #   true -> false
      # end
      (x0 < x1) or (x0 === x1 and i0 > i1)
    end)
    |> Enum.reduce(%{}, fn {{y, x, tile_id, flags}, _}, acc ->
      palette = if elem(@palette_flag, flags), do: obp1, else: obp0
      off_color = elem(@off_color, palette)
      prioritize_bg = elem(@prioritize_bg, flags)
      # Vertical flip
      line = if elem(@flip_y, flags) do
        sprite_size - ((ly - y + 16) &&& 0xff) - 1
      else
        (ly - y + 16) &&& 0xff
      end
      # If line >= 8, get pixels from the next tile (this can happen when sprite_size == 16)
      {line, tile_id} = if line >= 8, do: {line - 8, tile_id + 1}, else: {line, tile_id}
      # Horizontal flip
      if elem(@flip_x, flags) do
        elem(@tile_bytes_rev, Memory.read_int(vram, (tile_id * 16) + (line * 2), 16))
      else
        elem(@tile_bytes, Memory.read_int(vram, (tile_id * 16) + (line * 2), 16))
      end
      |> Stream.with_index()
      |> Enum.reduce(acc, fn {p, i}, m ->
        color = (palette >>> (p * 2)) &&& 0x3
        if color === off_color do
          m
        else
          Map.put(m, x + i + 8, {color, prioritize_bg})
        end
      end)
    end)
  end

  defp sprite_chunks(<<>>, _count, _size, _ly, sprites), do: sprites
  defp sprite_chunks(_, 10, _size, _ly, sprites), do: sprites
  defp sprite_chunks(<<h::binary-size(4), rest::binary>>, count, ly, size, sprites) do
    <<y, _::binary>> = h
    if ((ly - y + 16) &&& 0xff) < size do
      sprite_chunks(rest, count + 1, ly, size, [h | sprites])
    else
      sprite_chunks(rest, count, ly, size, sprites)
    end
  end

  defp chunk(<<>>, acc), do: Enum.reverse(acc)
  # defp chunk(<<h::binary-size(4), rest::binary>>, acc), do: chunk(rest, [h | acc])
  defp chunk(<<y, x, t, f, rest::binary>>, acc), do: chunk(rest, [{y, x, t, f} | acc])

  defp draw_scanline(ppu) do
    scanline(ppu)
    # scanline_task(ppu.oam.data, ppu.vram.data, ppu.lcdc, ppu.ly, ppu.scy, ppu.scx, ppu.bgp, ppu.obp0, ppu.obp1)
    # MinaraiNif.scanline(ppu.vram.data,
    #   ppu.oam.data,
    #   ppu.lcdc,
    #   ppu.ly,
    #   ppu.scy,
    #   ppu.scx,
    #   ppu.bgp,
    #   ppu.obp0,
    #   ppu.obp1)

  end

  defp scanline(ppu) do
    sprites = get_sprite_map(ppu)
    sprites_set = Map.keys(sprites)
                  |> MapSet.new()

    lcdc = ppu.lcdc
    y = ppu.scy + ppu.ly

    # Render background
    tile_line = rem(y, 8) * 2
    row_addr = elem(@bg_tile_map_addr, lcdc) + (div(y, 8) * 32)
    tile_index = div(ppu.scx, 8) &&& 0x1f
    scx_offset = rem(ppu.scx, 8)
    num_tiles = if scx_offset == 0, do: @tiles_per_row, else: @tiles_per_row + 1
    off_color = elem(@off_color, ppu.bgp)
    # x coordinates on screen
    x_coords = -scx_offset..159
         |> Enum.chunk_every(8)

    if elem(@tile_data_addr, lcdc) do
      # 0x8000 address mode
      Memory.read_range(ppu.vram, (row_addr + tile_index) &&& @vram_mask, num_tiles)
      |> Stream.zip(x_coords)
      |> Enum.map(fn {tile_id, xs} -> 
        elem(@tile_bytes, Memory.read_int(ppu.vram, (tile_id * 16) + tile_line, 16))
        |> Enum.zip(xs)
        |> Enum.map(fn {p, x} -> 
          if x < 0 do
            []
          else
            if MapSet.member?(sprites_set, x) do
              case sprites do
                %{^x => {sp, true}} ->
                  bg_pixel = (ppu.bgp >>> (p * 2)) &&& 0x3
                  if bg_pixel === off_color, do: elem(@color, sp), else: elem(@color, bg_pixel)
                %{^x => {sp, _}} ->
                  elem(@color, sp)
              end
            else
              bg_pixel = (ppu.bgp >>> (p * 2)) &&& 0x3
              elem(@color, bg_pixel)
            end
          end
        end)
      end)
    else
      # 0x8800 address mode
      Memory.read_range(ppu.vram, (row_addr + tile_index) &&& @vram_mask, num_tiles)
      |> Stream.zip(x_coords)
      |> Enum.map(fn {tile_id, xs} ->
        elem(@tile_bytes, Memory.read_int(ppu.vram, 0x1000 + (elem(@tile_id_8800, tile_id) * 16) + tile_line, 16))
        |> Enum.zip(xs)
        |> Enum.map(fn {p, x} ->
          if x < 0 do
            []
          else
            if MapSet.member?(sprites_set, x) do
              case sprites do
                %{^x => {sp, true}} ->
                  bg_pixel = (ppu.bgp >>> (p * 2)) &&& 0x3
                  if bg_pixel === off_color, do: elem(@color, sp), else: elem(@color, bg_pixel)
                %{^x => {sp, _}} ->
                  elem(@color, sp)
              end
            else
              bg_pixel = (ppu.bgp >>> (p * 2)) &&& 0x3
              elem(@color, bg_pixel)
            end
          end
        end)
      end)
    end
  end

  defp vblank(ppu) do
    # sprites = Task.await_many(ppu.sprites)
    # data = Task.await_many(ppu.buffer) |> IO.iodata_to_binary()
    data = ppu.buffer |> IO.iodata_to_binary()
    send(Minarai, {:update, data})
  end
end
