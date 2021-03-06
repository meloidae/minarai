defmodule Gameboy.SimplePpu do
  use Bitwise
  alias Gameboy.Memory
  # alias Gameboy.MapMemory
  alias Gameboy.EtsMemory, as: RWMemory
  # alias Gameboy.AtomicsMemory, as: RWMemory
  alias Gameboy.SimplePpu, as: Ppu
  alias Gameboy.Interrupts

  @vram_size 0x4000
  @oam_size 0xa0
  @vram_mask 0x1fff

  @oam_search_cycles 20
  @pixel_transfer_cycles 43
  @hblank_cycles 51
  @vblank_cycles 114

  defstruct vram: nil,
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
            buffer: [],
            scanline_args: nil

  @display_enable 0..0xff |> Enum.map(fn x -> (x &&& (1 <<< 7)) != 0 end) |> List.to_tuple()
  @window_tile_map_addr 0..0xff |> Enum.map(fn x ->
    if (x &&& (1 <<< 6)) != 0, do: 0x1c00, else: 0x1800
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
  @bg_win_enable 0..0xff |> Enum.map(fn x -> (x &&& 1) != 0 end) |> List.to_tuple()

  @screen_height 144
  @n_scanline_args 9  # Accounts for lcdc, scy, scx, ly, wy, wx, bgp, obp0, obp1

  def init do
    # vram = Memory.init(@vram_size)
    # vram = MapMemory.init(@vram_size)
    vram = RWMemory.init(@vram_size, :vram)
    oam = Memory.init(@oam_size)
    args = init_scanline_args()
    # :persistent_term.put(:scanline_args, args)
    # :persistent_term.put(:vram, vram)
    %Ppu{vram: vram, oam: oam, scanline_args: args}
  end

  def init_scanline_args do
    :atomics.new(@screen_height * @n_scanline_args,  [signed: false])
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
      # Memory.read(vram, addr &&& @vram_mask)
      # MapMemory.read(vram, addr &&& @vram_mask)
      RWMemory.read(vram, addr &&& @vram_mask)
    end
  end

  defp read_binary_vram(%Ppu{vram: vram} = _ppu, addr, len) do
    # Memory.read_binary(vram, addr &&& @vram_mask, len)
    # MapMemory.read_binary(vram, addr &&& @vram_mask, len)
    RWMemory.read_binary(vram, addr &&& @vram_mask, len)
  end

  def write_vram(%Ppu{mode: mode, vram: vram} = ppu, addr, value) do
    if mode == :pixel_transfer do
      # vram is not accessible during pixel transfer (mode 3)
      ppu
    else 
      # Map.put(ppu, :vram, Memory.write(vram, addr &&& @vram_mask, value))
      # Map.put(ppu, :vram, MapMemory.write(vram, addr &&& @vram_mask, value))
      RWMemory.write(vram, addr &&& @vram_mask, value)
      ppu
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

  def bg_palette(%Ppu{bgp: bgp} = _ppu), do: bgp

  def set_bg_palette(%Ppu{} = ppu, value), do: Map.put(ppu, :bgp, value &&& 0xff)

  def ob_palette0(ppu), do: ppu.obp0
  def set_ob_palette0(ppu, value), do: Map.put(ppu, :obp0, value)
  def ob_palette1(ppu), do: ppu.obp1
  def set_ob_palette1(ppu, value), do: Map.put(ppu, :obp1, value)

  def scroll_y(%Ppu{scy: scy} = _ppu), do: scy
  def set_scroll_y(%Ppu{} = ppu, value), do: Map.put(ppu, :scy, value &&& 0xff)

  def scroll_x(%Ppu{scx: scx} = _ppu), do: scx
  def set_scroll_x(%Ppu{} = ppu, value), do: Map.put(ppu, :scx, value &&& 0xff)

  def line_y(%Ppu{ly: ly} = _ppu), do: ly
  # ly is read only
  def set_line_y(ppu, _), do: ppu

  def line_y_compare(%Ppu{lyc: lyc} = _ppu), do: lyc
  def set_line_y_compare(%Ppu{} = ppu, value), do: Map.put(ppu, :lyc, value &&& 0xff)

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

  def cycle(ppu) do
    if elem(@display_enable, ppu.lcdc), do: do_cycle(ppu), else: {ppu, 0}
  end

  defp do_cycle(%Ppu{counter: counter} = ppu) when counter > 1, do: {Map.put(ppu, :counter, counter - 1), 0}
  defp do_cycle(%Ppu{counter: _, mode: :oam_search} = ppu) do
    {%{ppu | mode: :pixel_transfer, counter: @pixel_transfer_cycles}, 0}
  end
  defp do_cycle(%Ppu{counter: _, mode: :pixel_transfer, lcds: lcds, buffer: buffer} = ppu) do
    pixels = draw_scanline(ppu)
    req = if elem(@hblank_stat, lcds), do: Interrupts.stat(), else: 0
    # {%{ppu | mode: :hblank, counter: @hblank_cycles, buffer: [buffer | pixels]}, req}
    {%{ppu | mode: :hblank, counter: @hblank_cycles, buffer: [pixels | buffer]}, req}
  end
  defp do_cycle(%Ppu{counter: _, mode: :hblank, lcds: lcds, ly: ly, lyc: lyc} = ppu) do
    new_ly = ly + 1
    if new_ly == 144 do
      req = Interrupts.vblank()
      req = if elem(@vblank_stat, lcds), do: Interrupts.stat() ||| req, else: req
      req = if elem(@lyc_stat, lcds) and new_ly === lyc, do: Interrupts.stat() ||| req, else: req
      # vblank(ppu)
      task = vblank_task(ppu)
      # {%{ppu | mode: :vblank, counter: @vblank_cycles, ly: new_ly}, req}
      {%{ppu | mode: :vblank, counter: @vblank_cycles, ly: new_ly, buffer: task}, req}
    else
      req = if elem(@oam_stat, lcds), do: Interrupts.stat(), else: 0
      req = if elem(@lyc_stat, lcds) and new_ly === lyc, do: Interrupts.stat() ||| req, else: req
      {%{ppu | mode: :oam_search, counter: @oam_search_cycles, ly: new_ly}, req}
    end
  end
  defp do_cycle(%Ppu{counter: _, mode: :vblank, lcds: lcds, ly: ly, lyc: lyc} = ppu) do
    new_ly = ly + 1
    if new_ly == 153 do
      req = if elem(@oam_stat, lcds), do: Interrupts.stat(), else: 0
      req = if elem(@lyc_stat, lcds) and new_ly === lyc, do: Interrupts.stat() ||| req, else: req
      render(ppu)
      # vblank_await_all(ppu)
      {%{ppu | mode: :oam_search, counter: @oam_search_cycles, ly: 0, buffer: []}, req}
    else
      req = if elem(@lyc_stat, lcds) and new_ly === lyc, do: Interrupts.stat(), else: 0
      {%{ppu | counter: @vblank_cycles, ly: new_ly}, req}
    end
  end

  # def update(%Ppu{mode: :oam_search} = ppu) do
  #   {Map.put(ppu, :mode, :pixel_transfer), 0, @pixel_transfer_cycles}
  # end
  # def update(%Ppu{mode: :pixel_transfer, lcds: lcds, buffer: buffer} = ppu) do
  #   pixels = draw_scanline(ppu)
  #   req = if elem(@hblank_stat, lcds), do: Interrupts.stat(), else: 0
  #   {%{ppu | mode: :hblank, buffer: [buffer | pixels]}, req, @hblank_cycles}
  # end
  # def update(%Ppu{mode: :hblank, lcds: lcds, ly: ly, lyc: lyc} = ppu) do
  #   new_ly = ly + 1
  #   if new_ly == 144 do
  #     req = Interrupts.vblank()
  #     req = if elem(@vblank_stat, lcds), do: Interrupts.stat() ||| req, else: req
  #     req = if elem(@lyc_stat, lcds) and new_ly === lyc, do: Interrupts.stat() ||| req, else: req
  #     vblank(ppu)
  #     {%{ppu | mode: :vblank, ly: new_ly}, req, @vblank_cycles}
  #   else
  #     req = if elem(@oam_stat, lcds), do: Interrupts.stat(), else: 0
  #     req = if elem(@lyc_stat, lcds) and new_ly === lyc, do: Interrupts.stat() ||| req, else: req
  #     {%{ppu | mode: :oam_search, ly: new_ly}, req, @oam_search_cycles}
  #   end
  # end
  # def update(%Ppu{mode: :vblank, lcds: lcds, ly: ly, lyc: lyc} = ppu) do
  #   new_ly = ly + 1
  #   if new_ly == 153 do
  #     req = if elem(@oam_stat, lcds), do: Interrupts.stat(), else: 0
  #     req = if elem(@lyc_stat, lcds) and new_ly === lyc, do: Interrupts.stat() ||| req, else: req
  #     {%{ppu | mode: :oam_search, ly: 0, buffer: []}, req, @oam_search_cycles}
  #   else
  #     req = if elem(@lyc_stat, lcds) and new_ly === lyc, do: Interrupts.stat(), else: 0
  #     {Map.put(ppu, :ly, new_ly), req, @vblank_cycles}
  #   end
  # end

  @tile_bytes 0..0xffff
  |> Enum.map(fn x ->
    <<l0::size(1), l1::size(1), l2::size(1), l3::size(1),
      l4::size(1), l5::size(1), l6::size(1), l7::size(1),
      h0::size(1), h1::size(1), h2::size(1), h3::size(1),
      h4::size(1), h5::size(1), h6::size(1), h7::size(1)>> = <<x::integer-size(16)>>
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

  # @tiles_per_row 20
  # @color {<<155, 188, 15>>, <<139, 172, 15>>, <<48, 98, 48>>, <<15, 65, 15>>}
  @color {<<0xe0, 0xf0, 0xe7>>, <<0x8b, 0xa3, 0x94>>, <<0x55, 0x64, 0x5a>>, <<0x34, 0x3d, 0x37>>}
  # @color {[0xe0, 0xf0, 0xe7], [0x8b, 0xa3, 0x94], [0x55, 0x64, 0x5a], [0x34, 0x3d, 0x37]}
  @tile_id_8800 0..0xff
  |> Enum.map(fn x -> if x < 0x80, do: x, else: x - 256 end)
  |> List.to_tuple()

  @off_color 0..0xff
  |> Enum.map(fn x -> x &&& 0x03 end)
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


  defp reduce_with_index([], _, acc, _), do: acc
  defp reduce_with_index([h | t], index, acc, reduce_fn) do
    reduce_with_index(t, index + 1, reduce_fn.(h, index, acc), reduce_fn)
  end

  # defp chunk(<<>>, acc), do: Enum.reverse(acc)
  # defp chunk(<<y, x, t, f, rest::binary>>, acc), do: chunk(rest, [{y, x, t, f} | acc])

  # defp chunk_filter(<<>>, acc, _filter_fn), do: Enum.reverse(acc)
  # defp chunk_filter(<<y, x, t, f, rest::binary>>, acc, filter_fn) do
  #   if filter_fn.(y) do
  #     chunk_filter(rest, [{y, x, t, f} | acc], filter_fn)
  #   else
  #     chunk_filter(rest, acc, filter_fn)
  #   end
  # end

  defp filter_oam_y(oam_data, ly, sprite_size), do: filter_oam_y(oam_data, ly, sprite_size, 0, [])
  defp filter_oam_y(<<>>, _ly, _sprite_size, _count, acc), do: acc
  defp filter_oam_y(<<_, _, _, _, _::binary>>, _ly, _sprite_size, 10, acc), do: acc
  defp filter_oam_y(<<y, x, t, f, rest::binary>>, ly, sprite_size, count, acc) do
    if ((ly - y + 16) &&& 0xff) < sprite_size do
      filter_oam_y(rest, ly, sprite_size, count + 1, [{y, x, t, f} | acc])
    else
      filter_oam_y(rest, ly, sprite_size, count, acc)
    end
  end

  defp filter_oam_x(oam_list), do: filter_oam_x(oam_list, 0, [])
  defp filter_oam_x([], _count, acc), do: acc
  defp filter_oam_x([{_, x, _, _} = sprite | rest], count, acc) do
    if x > 0 and x < 168 do
      filter_oam_x(rest, count + 1, [{sprite, count} | acc])
    else
      filter_oam_x(rest, count, acc)
    end
  end

  defp get_sprite_map(oam_data, vram, lcdc, ly, obp0, obp1) do
  # defp get_sprite_map(%Ppu{oam: %{data: oam_data}, vram: vram, lcdc: lcdc, ly: ly, obp0: obp0, obp1: obp1} = _ppu) do
    sprite_size = elem(@obj_size, lcdc)
    # Memory.read_binary(oam, 0, @oam_size)
    oam_data
    # |> chunk_filter([], fn y -> ((ly - y + 16) &&& 0xff) < sprite_size end)
    # |> Enum.take(10)
    |> filter_oam_y(ly, sprite_size)
    |> filter_oam_x()
    # |> Enum.filter(fn {_, x, _, _} ->
    #   x > 0 and x < 168
    # end)
    # |> Enum.with_index()
    |> Enum.sort(fn {{_, x0, _, _}, i0}, {{_, x1, _, _}, i1} -> 
      (x0 < x1) or (x0 === x1 and i0 > i1)
    end)
    |> Enum.reduce(%{}, fn {{y, x, tile_id, flags}, _}, acc ->
      palette = if elem(@palette_flag, flags), do: obp1, else: obp0
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
        # elem(@tile_bytes_rev, Memory.read_int(vram, (tile_id * 16) + (line * 2), 16))
        # elem(@tile_bytes_rev, MapMemory.read_short(vram, (tile_id * 16) + (line * 2)))
        elem(@tile_bytes_rev, RWMemory.read_short(vram, (tile_id * 16) + (line * 2)))
      else
        # elem(@tile_bytes, Memory.read_int(vram, (tile_id * 16) + (line * 2), 16))
        # elem(@tile_bytes, MapMemory.read_short(vram, (tile_id * 16) + (line * 2)))
        elem(@tile_bytes, RWMemory.read_short(vram, (tile_id * 16) + (line * 2)))
      end
      |> reduce_with_index(0, acc, fn p, i, m ->
        if p === 0 do
          m
        else
          color = (palette >>> (p * 2)) &&& 0x3
          Map.put(m, (x + i - 8) &&& 0xff, {color, prioritize_bg})
        end
      end)
    end)
  end

  defp put_args(ref, lcdc, scy, scx, ly, wy, wx, bgp, obp0, obp1) do
    offset = ly * @n_scanline_args + 1
    :atomics.put(ref, offset, lcdc)
    :atomics.put(ref, offset + 1, scy)
    :atomics.put(ref, offset + 2, scx)
    :atomics.put(ref, offset + 3, ly)
    :atomics.put(ref, offset + 4, wy)
    :atomics.put(ref, offset + 5, wx)
    :atomics.put(ref, offset + 6, bgp)
    :atomics.put(ref, offset + 7, obp0)
    :atomics.put(ref, offset + 8, obp1)
  end

  defp draw_scanline(%Ppu{oam: %{data: oam_data}, vram: vram, lcdc: lcdc, scy: scy, scx: scx, ly: ly, wy: wy, wx: wx, bgp: bgp, obp0: obp0, obp1: obp1, scanline_args: args} = _ppu) do
    # scanline(oam_data, vram, lcdc, scy, scx, ly, wy, wx, bgp, obp0, obp1)
    put_args(args, lcdc, scy, scx, ly, wy, wx, bgp, obp0, obp1)
    oam_data
    # fn -> scanline(oam_data, vram, lcdc, scy, scx, ly, wy, wx, bgp, obp0, obp1) end
    # fn -> scanline_with_args(oam_data, ly) end
    # Task.async(fn -> scanline_with_args(oam_data, ly) end)
  end
  # defp draw_scanline(ppu) do
    # scanline(ppu)
    # MinaraiNif.scanline(ppu.vram.data,
    #   ppu.oam.data,
    #   ppu.lcdc,
    #   ppu.ly,
    #   ppu.scy,
    #   ppu.scx,
    #   ppu.bgp,
    #   ppu.obp0,
    #   ppu.obp1)
  # end

  def zip_map([], _, acc, _), do: Enum.reverse(acc)
  def zip_map([_ | _], [], acc, _), do: Enum.reverse(acc)
  def zip_map([h1 | t1], [h2 | t2], acc, map_fn) do
    zip_map(t1, t2, [map_fn.(h1, h2) | acc], map_fn)
  end

  def zip_map_iolist([], _, acc, _), do: acc
  def zip_map_iolist([_ | _], [], acc, _), do: acc
  def zip_map_iolist([h1 | t1], [h2 | t2], acc, map_fn) do
    zip_map_iolist(t1, t2, [acc | map_fn.(h1, h2)], map_fn)
  end

  @tile_indexes 0..31
  |> Enum.map(fn start ->
    Enum.map(0..19, fn x ->
      (start + x) &&& 0x1f
    end)
  end)
  |> List.to_tuple()

  @tile_indexes_extra 0..31
  |> Enum.map(fn start ->
    Enum.map(0..20, fn x ->
      (start + x) &&& 0x1f
    end)
  end)
  |> List.to_tuple()

  @win_tile_indexes 0..20 |> Enum.to_list()

  defp scanline_with_args(oam_data, row, vram, ref) do
    # vram = :vram
    # vram = :persistent_term.get(:vram)
    # ref = :persistent_term.get(:scanline_args)
    offset = row * @n_scanline_args + 1
    lcdc = :atomics.get(ref, offset)
    scy = :atomics.get(ref, offset + 1)
    scx = :atomics.get(ref, offset + 2)
    ly = :atomics.get(ref, offset + 3)
    wy = :atomics.get(ref, offset + 4)
    wx = :atomics.get(ref, offset + 5)
    bgp = :atomics.get(ref, offset + 6)
    obp0 = :atomics.get(ref, offset + 7)
    obp1 = :atomics.get(ref, offset + 8)
    scanline(oam_data, vram, lcdc, scy, scx, ly, wy, wx, bgp, obp0, obp1)
  end

  defp scanline(oam_data, vram, lcdc, scy, scx, ly, wy, wx, bgp, obp0, obp1) do
    sprites = if elem(@obj_enable, lcdc) do
      get_sprite_map(oam_data, vram, lcdc, ly, obp0, obp1)
    else
      %{}
    end
    n_sp = map_size(sprites)

    if elem(@bg_win_enable, lcdc) do
      y = (scy + ly) &&& 0xff
      bg_tile_line = rem(y, 8) * 2
      bg_row_addr = elem(@bg_tile_map_addr, lcdc) + (div(y, 8) * 32)
      bg_tile_index = div(scx, 8) &&& 0x1f
      scx_offset = rem(scx, 8)

      bg_tile_fn = if elem(@tile_data_addr, lcdc) do
        # 0x8000 address mode
        fn tile_id -> elem(@tile_bytes, RWMemory.read_short(vram, (tile_id * 16) + bg_tile_line)) end
      else
        # 0x8800 address mode
        fn tile_id ->
          elem(@tile_bytes, RWMemory.read_short(vram, 0x1000 + (elem(@tile_id_8800, tile_id) * 16) + bg_tile_line))
        end
      end

      bg_indexes = if scx_offset === 0 do
        elem(@tile_indexes, bg_tile_index)
      else
        elem(@tile_indexes_extra, bg_tile_index)
      end

      bg_row = RWMemory.read_range(vram, bg_row_addr, 32)
               |> List.to_tuple()
      
      if elem(@window_enable, lcdc) and ly >= wy and wy <= 143 and wx >= 0 and wx <= 166 do
        win_y = (ly - wy) &&& 0xff
        win_x = wx - 7
        win_row_addr = elem(@window_tile_map_addr, lcdc) + (div(win_y, 8) * 32)
        win_tile_line = rem(win_y, 8) * 2
        win_row = RWMemory.read_range(vram, win_row_addr, 32)
                  |> List.to_tuple()
        win_tile_fn = if elem(@tile_data_addr, lcdc) do
          # 0x8000 address mode
          fn tile_id -> elem(@tile_bytes, RWMemory.read_short(vram, (tile_id * 16) + win_tile_line)) end
        else
          # 0x8800 address mode
          fn tile_id ->
            elem(@tile_bytes, RWMemory.read_short(vram, 0x1000 + (elem(@tile_id_8800, tile_id) * 16) + win_tile_line))
          end
        end
        win_indexes = @win_tile_indexes
        mix(-scx_offset, win_x, bg_indexes, bg_row, bg_tile_fn, win_indexes, win_row, win_tile_fn, sprites, n_sp, bgp)
      else
        mix_no_win(-scx_offset, bg_indexes, bg_row, bg_tile_fn, sprites, n_sp, bgp)
      end
    else
      mix_no_bg_win(sprites, n_sp)
    end
  end


  @screen_width 160
  defp mix(x, win_x, bg_indexes, bg_row, bg_tile_fn, win_indexes, win_row, win_tile_fn, sprites, n_sp, bgp) do
    # Entry point
    [h_bg | rest_bg] = bg_indexes
    mix_pre_win(x, win_x, bg_tile_fn.(elem(bg_row, h_bg)), rest_bg, bg_row, bg_tile_fn, win_indexes, win_row, win_tile_fn, sprites, n_sp, bgp)
  end

  defp mix_pre_win(x, win_x, [_p | rest], bg_indexes, bg_row, bg_tile_fn, win_indexes, win_row, win_tile_fn, sprites, n_sp, bgp) when x < 0 do
    # Throw away pixels while x < 0
    mix_pre_win(x + 1, win_x, rest, bg_indexes, bg_row, bg_tile_fn, win_indexes, win_row, win_tile_fn, sprites, n_sp, bgp)
  end
  defp mix_pre_win(x, win_x, bg_tile, bg_indexes, bg_row, bg_tile_fn, win_indexes, win_row, win_tile_fn, sprites, n_sp, bgp) do
    # Start mixing pixels
    _mix_pre_win(x, win_x, bg_tile, bg_indexes, bg_row, bg_tile_fn, win_indexes, win_row, win_tile_fn, sprites, n_sp, bgp, [])
  end

  defp _mix_pre_win(x, win_x, _bg_tile, _bg_indexes, _bg_row, _bg_tile_fn, win_indexes, win_row, win_tile_fn, sprites, n_sp, bgp, pixels) when win_x <= 0 do
    # Start rendering windows
    [h_win | rest_win] = win_indexes
    win_tile = win_tile_fn.(elem(win_row, h_win)) 
    win_tile = if win_x === 0, do: win_tile, else: Enum.drop(win_tile, -win_x)
    _mix(x, win_tile, rest_win, win_row, win_tile_fn, sprites, n_sp, bgp, pixels)
  end
  defp _mix_pre_win(x, win_x, [] = _bg_tile, bg_indexes, bg_row, bg_tile_fn, win_indexes, win_row, win_tile_fn, sprites, n_sp, bgp, pixels) do
    # Get a new tile when bg_tile is empty
    [h_bg | rest_bg] = bg_indexes
    _mix_pre_win(x, win_x, bg_tile_fn.(elem(bg_row, h_bg)), rest_bg, bg_row, bg_tile_fn, win_indexes, win_row, win_tile_fn, sprites, n_sp, bgp, pixels)
  end
  defp _mix_pre_win(x, win_x, [p | rest] = _bg_tile, bg_indexes, bg_row, bg_tile_fn, win_indexes, win_row, win_tile_fn, sprites, 0, bgp, pixels) do
    # No sprite pixels
    pixel = elem(@color, (bgp >>> (p * 2)) &&& 0x3)
    _mix_pre_win(x + 1, win_x - 1, rest, bg_indexes, bg_row, bg_tile_fn, win_indexes, win_row, win_tile_fn, sprites, 0, bgp, [pixels | pixel])
  end
  defp _mix_pre_win(x, win_x, [p | rest] = _bg_tile, bg_indexes, bg_row, bg_tile_fn, win_indexes, win_row, win_tile_fn, sprites, n_sp, bgp, pixels) do
    # Mix a background and sprite pixel
    case sprites do
      %{^x => {sp, true}} ->
        bg_pixel = (bgp >>> (p * 2)) &&& 0x3
        pixel = if bg_pixel === elem(@off_color, bgp), do: elem(@color, sp), else: elem(@color, bg_pixel)
        _mix_pre_win(x + 1, win_x - 1, rest, bg_indexes, bg_row, bg_tile_fn, win_indexes, win_row, win_tile_fn, sprites, n_sp - 1, bgp, [pixels | pixel])
      %{^x => {sp, _}} ->
        pixel = elem(@color, sp)
        _mix_pre_win(x + 1, win_x - 1, rest, bg_indexes, bg_row, bg_tile_fn, win_indexes, win_row, win_tile_fn, sprites, n_sp - 1, bgp, [pixels | pixel])
      _ ->
        bg_pixel = (bgp >>> (p * 2)) &&& 0x3
        pixel = elem(@color, bg_pixel)
        _mix_pre_win(x + 1, win_x - 1, rest, bg_indexes, bg_row, bg_tile_fn, win_indexes, win_row, win_tile_fn, sprites, n_sp, bgp, [pixels | pixel])
    end
  end

  defp mix_no_win(x, bg_tile_indexes, bg_tile_row, bg_tile_fn, sprites, n_sp, bgp) do
    # Entry point
    [h | rest] = bg_tile_indexes
    mix_no_win(x, bg_tile_fn.(elem(bg_tile_row, h)), rest, bg_tile_row, bg_tile_fn, sprites, n_sp, bgp)
  end
  defp mix_no_win(x, [_p | rest], bg_tile_indexes, bg_tile_row, bg_tile_fn, sprites, n_sp, bgp) when x < 0 do
    # Throw away pixels while x < 0
    mix_no_win(x + 1, rest, bg_tile_indexes, bg_tile_row, bg_tile_fn, sprites, n_sp, bgp)
  end
  defp mix_no_win(x, bg_tile, bg_tile_indexes, bg_tile_row, bg_tile_fn, sprites, n_sp, bgp) do
    # Start mixing pixels
    _mix(x, bg_tile, bg_tile_indexes, bg_tile_row, bg_tile_fn, sprites, n_sp, bgp, [])
  end

  # No background or window (sprites only)
  defp mix_no_bg_win(sprites, n_sp) do
    # Entry point
    _mix_no_bg_win(0, sprites, n_sp, elem(@color, 0), [])
  end
  defp _mix_no_bg_win(@screen_width, _sprites, _n_sp, _white_color, pixels), do: pixels
  defp _mix_no_bg_win(x, sprites, 0, white_color, pixels) do
    # No sprite pixels = just append white_color
    _mix_no_bg_win(x + 1, sprites, 0, white_color, [pixels | white_color])
  end
  defp _mix_no_bg_win(x, sprites, n_sp, white_color, pixels) do
    # Mix a pixel (white_color or sprite pixel)
    case sprites do
      %{^x => {sp, _}} ->
        pixel = elem(@color, sp)
        _mix_no_bg_win(x + 1, sprites, n_sp - 1, white_color, [pixels | pixel])
      _ ->
        _mix_no_bg_win(x + 1, sprites, n_sp, white_color, [pixels | white_color])
    end
  end

  defp _mix(@screen_width, _bg_tile, _bg_tile_indexes, _bg_tile_row, _bg_tile_fn, _sprites, _n_sp, _bgp, pixels), do: pixels
  defp _mix(x, [] = _bg_tile, bg_tile_indexes, bg_tile_row, bg_tile_fn, sprites, n_sp, bgp, pixels) do
    # Get a new tile when bg_tile is empty
    [h | rest] = bg_tile_indexes
    _mix(x, bg_tile_fn.(elem(bg_tile_row, h)), rest, bg_tile_row, bg_tile_fn, sprites, n_sp, bgp, pixels)
  end
  defp _mix(x, [p | rest] = _bg_tile, bg_tile_indexes, bg_tile_row, bg_tile_fn, sprites, 0, bgp, pixels) do
    # No sprite pixels
    bg_pixel = (bgp >>> (p * 2)) &&& 0x3
    pixel = elem(@color, bg_pixel)
    _mix(x + 1, rest, bg_tile_indexes, bg_tile_row, bg_tile_fn, sprites, 0, bgp, [pixels | pixel])
  end
  defp _mix(x, [p | rest] = _bg_tile, bg_tile_indexes, bg_tile_row, bg_tile_fn, sprites, n_sp, bgp, pixels) do
    # Mix a pixel
    case sprites do
      %{^x => {sp, true}} ->
        bg_pixel = (bgp >>> (p * 2)) &&& 0x3
        pixel = if bg_pixel === elem(@off_color, bgp), do: elem(@color, sp), else: elem(@color, bg_pixel)
        _mix(x + 1, rest, bg_tile_indexes, bg_tile_row, bg_tile_fn, sprites, n_sp - 1, bgp, [pixels | pixel])
      %{^x => {sp, _}} ->
        pixel = elem(@color, sp)
        _mix(x + 1, rest, bg_tile_indexes, bg_tile_row, bg_tile_fn, sprites, n_sp - 1, bgp, [pixels | pixel])
      _ ->
        bg_pixel = (bgp >>> (p * 2)) &&& 0x3
        pixel = elem(@color, bg_pixel)
        _mix(x + 1, rest, bg_tile_indexes, bg_tile_row, bg_tile_fn, sprites, n_sp, bgp, [pixels | pixel])
    end
  end

  defp map_rev([], acc, _), do: acc
  defp map_rev([h | t], acc, map_fn) do
    map_rev(t, [map_fn.(h) | acc], map_fn)
  end

  # defp map_rev_decr(<<>>, acc, _n, _), do: acc
  defp map_rev_decr([], acc, _n, _), do: acc
  # defp map_rev_decr(<<h::binary-size(160), t::binary>>, acc, n, map_fn) do
  defp map_rev_decr([h | t], acc, n, map_fn) do
    map_rev_decr(t, [map_fn.(h, n) | acc], n - 1, map_fn)
  end

  defp vblank(%Ppu{buffer: buffer}) do
    data = buffer |> IO.iodata_to_binary()
    send(Minarai, {:update, data})
  end

  # defp vblank_task(%Ppu{buffer: buffer}) do
  defp vblank_task(%Ppu{buffer: buffer, vram: vram, scanline_args: args}) do
    # oam_data = buffer |> IO.iodata_to_binary()
    Task.async(fn ->
      # data = map_rev(buffer, [], fn x -> x.() end) |> IO.iodata_to_binary()
      data = map_rev_decr(buffer, [], 143, fn oam, row -> scanline_with_args(oam, row, vram , args) end) |> IO.iodata_to_binary()
      send(Minarai, {:update, data})
      # IO.puts("buffer size: #{buffer |> :erlang.term_to_binary() |> :erlang.byte_size()}")
    end)
  end

  defp vblank_await_all(%Ppu{buffer: buffer}) do
    data = Task.await_many(buffer) |> IO.iodata_to_binary()
    send(Minarai, {:update, data})
  end

  defp render(%Ppu{buffer: buffer}), do: Task.await(buffer)
  # defp render(%Ppu{buffer: buffer}) do
  #   data = Task.await_many(buffer) |> IO.iodata_to_binary()
  #   send(Minarai, {:update, data})
  # end

end
