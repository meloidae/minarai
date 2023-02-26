defmodule Gameboy.RecordPpu do
  import Bitwise
  alias Gameboy.Memory
  # alias Gameboy.EtsMemory, as: RWMemory
  alias Gameboy.PtAtomicsMemory, as: RWMemory
  alias Gameboy.Interrupts

  # alias Gameboy.RecordPpu, as: Ppu

  require Record

  @vram_size 0x4000
  @oam_size 0xa0
  @vram_mask 0x1fff

  @oam_search_cycles 20
  @pixel_transfer_cycles 43
  @hblank_cycles 51
  @vblank_cycles 114

  Record.defrecordp(:ppu,
                    vram: nil,
                    oam: struct(Memory),
                    mode: :oam_search,
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
                    buffer: [])

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

  @screen_width 160
  @screen_height 144
  # @n_scanline_args 10  # Accounts for oam, lcdc, scy, scx, ly, wy, wx, bgp, obp0, obp1

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
  @white_color 0

  def init do
    vram = RWMemory.init(@vram_size, :vram)
    oam = Memory.init(@oam_size)
    {ppu(vram: vram, oam: oam), @oam_search_cycles}
  end

  def read_oam({ppu(mode: mode, oam: oam), _counter} = _pt, addr) do
    # oam is not accessible during pixel transfer & oam search
    if mode == :pixel_transfer or mode == :oam_search do
      0xff
    else
      Memory.read(oam, addr)
    end
  end

  def write_oam({ppu(mode: mode, oam: oam) = p, counter} = pt, addr, value) do
    # oam is not accessible during pixel transfer & oam search
    if mode == :pixel_transfer or mode == :oam_search do
      pt
    else
      {ppu(p, oam: Memory.write(oam, addr, value)), counter}
    end
  end

  defp write_binary_oam(ppu(oam: oam) = p, addr, value, len) do
    ppu(p, oam: Memory.write_binary(oam, addr, value, len))
  end

  def read_vram({ppu(mode: mode, vram: vram), _counter} = _pt, addr) do
    if mode == :pixel_transfer do
      # vram is not accessible during pixel transfer (mode 3)
      0xff
    else
      RWMemory.read(vram, addr &&& @vram_mask)
    end
  end

  def read_binary_vram({ppu(vram: vram), _counter} = _pt, addr, len) do
    RWMemory.read_binary(vram, addr &&& @vram_mask, len)
  end

  def write_vram({ppu(mode: mode, vram: vram), _counter} = p, addr, value) do
    if mode != :pixel_transfer do
      # vram is only accessible when not in pixel transfer (mode 3)
      RWMemory.write(vram, addr &&& @vram_mask, value)
    end
    p
  end

  def lcd_control({ppu(lcdc: lcdc), _counter} = _pt), do: lcdc

  def set_lcd_control({p, counter}, value), do: {ppu(p, lcdc: value &&& 0xff), counter}

  def lcd_status({ppu(mode: :hblank, ly: ly, lyc: lyc, lcds: lcds), _counter} = _p) do
    if ly === lyc do
      lcds ||| 0b100
    else
      # Lower 3 bits are 0b000 so no point in binary or
      lcds
    end
  end
  def lcd_status({ppu(mode: :vblank, ly: ly, lyc: lyc, lcds: lcds), _counter} = _p) do
    if ly === lyc do
      lcds ||| 0b101
    else
      lcds ||| 0b001
    end
  end
  def lcd_status({ppu(mode: :oam_search, ly: ly, lyc: lyc, lcds: lcds), _counter} = _p) do
    if ly === lyc do
      lcds ||| 0b110
    else
      lcds ||| 0b010
    end
  end
  def lcd_status({ppu(mode: :pixel_transfer, ly: ly, lyc: lyc, lcds: lcds), _counter} = _p) do
    if ly === lyc do
      lcds ||| 0b111
    else
      lcds ||| 0b011
    end
  end

  def set_lcd_status({p, counter}, value) do
    # Only bit 3-6 are writable
    {ppu(p, lcds: value &&& 0b0111_1000), counter}
  end

  def bg_palette({ppu(bgp: bgp), _counter} = _p), do: bgp
  def set_bg_palette({p, counter}, value), do: {ppu(p, bgp: value &&& 0xff), counter}

  def ob_palette0({ppu(obp0: obp0), _counter} = _p), do: obp0
  def set_ob_palette0({p, counter}, value), do: {ppu(p, obp0: value), counter}
  def ob_palette1({ppu(obp1: obp1), _counter} = _p), do: obp1
  def set_ob_palette1({p, counter}, value), do: {ppu(p, obp1: value), counter}

  def scroll_y({ppu(scy: scy), _counter} = _p), do: scy
  def set_scroll_y({p, counter}, value), do: {ppu(p, scy: value &&& 0xff), counter}
  def scroll_x({ppu(scx: scx), _counter} = _p), do: scx
  def set_scroll_x({p, counter}, value), do: {ppu(p, scx: value &&& 0xff), counter}

  def line_y({ppu(ly: ly), _counter} = _p), do: ly
  # Return immediately because ly is read only
  def set_line_y(p, _), do: p

  def line_y_compare({ppu(lyc: lyc), _counter} = _p), do: lyc
  def set_line_y_compare({p, counter}, value), do: {ppu(p, lyc: value &&& 0xff), counter}

  def window_x({ppu(wx: wx), _counter} = _p), do: wx
  def set_window_x({p, counter}, value), do: {ppu(p, wx: value &&& 0xff), counter}

  def window_y({ppu(wy: wy), _counter} = _p), do: wy
  def set_window_y({p, counter}, value), do: {ppu(p, wy: value &&& 0xff), counter}

  # Instantaneous transfer for now
  def oam_dma_transfer({p, counter}, data, size) do
    {write_binary_oam(p, 0x00, data, size), counter}
  end

  def cycle({ppu(lcdc: lcdc) = p, counter} = pt) do
    if elem(@display_enable, lcdc), do: do_cycle(p, counter), else: {pt, 0}
  end

  defp do_cycle(p, counter) when counter > 1, do: {{p, counter - 1}, 0}
  defp do_cycle(ppu(mode: :oam_search) = p, _counter) do
    {{ppu(p, mode: :pixel_transfer), @pixel_transfer_cycles}, 0}
  end
  defp do_cycle(ppu(mode: :pixel_transfer, lcds: lcds, buffer: buffer) = p, _counter) do
    pixels = draw_scanline_now(p)
    req = if elem(@hblank_stat, lcds), do: Interrupts.stat(), else: 0
    {{ppu(p, mode: :hblank, buffer: IO.iodata_to_binary([pixels | buffer])), @hblank_cycles}, req}
    # {ppu(p, mode: :hblank, counter: @hblank_cycles), req}
  end
  defp do_cycle(ppu(mode: :hblank, lcds: lcds, ly: ly, lyc: lyc) = p, _counter) do
    new_ly = ly + 1
    if new_ly == 144 do
      req = Interrupts.vblank()
      req = if elem(@vblank_stat, lcds), do: Interrupts.stat() ||| req, else: req
      req = if elem(@lyc_stat, lcds) and new_ly === lyc, do: Interrupts.stat() ||| req, else: req
      render(p)
      {{ppu(p, mode: :vblank, ly: new_ly, buffer: []), @vblank_cycles}, req}
    else
      req = if elem(@oam_stat, lcds), do: Interrupts.stat(), else: 0
      req = if elem(@lyc_stat, lcds) and new_ly === lyc, do: Interrupts.stat() ||| req, else: req
      {{ppu(p, mode: :oam_search, ly: new_ly), @oam_search_cycles}, req}
    end
  end
  defp do_cycle(ppu(mode: :vblank, lcds: lcds, ly: ly, lyc: lyc) = p, _counter) do
    new_ly = ly + 1
    if new_ly == 153 do
      req = if elem(@oam_stat, lcds), do: Interrupts.stat(), else: 0
      req = if elem(@lyc_stat, lcds) and new_ly === lyc, do: Interrupts.stat() ||| req, else: req
      {{ppu(p, mode: :oam_search, ly: 0, buffer: []), @oam_search_cycles}, req}
    else
      req = if elem(@lyc_stat, lcds) and new_ly === lyc, do: Interrupts.stat(), else: 0
      {{ppu(p, ly: new_ly), @vblank_cycles}, req}
    end
  end

  defp reduce_with_index([], _, acc, _), do: acc
  defp reduce_with_index([h | t], index, acc, reduce_fn) do
    reduce_with_index(t, index + 1, reduce_fn.(h, index, acc), reduce_fn)
  end

  defp filter_oam_y(oam_data, ly, obj_size), do: filter_oam_y(oam_data, ly, obj_size, 0, [])
  defp filter_oam_y(<<>>, _ly, _obj_size, _count, acc), do: acc
  defp filter_oam_y(<<_, _, _, _, _::binary>>, _ly, _obj_size, 10, acc), do: acc
  defp filter_oam_y(<<y, x, t, f, rest::binary>>, ly, obj_size, count, acc) do
    if ((ly - y + 16) &&& 0xff) < obj_size do
      filter_oam_y(rest, ly, obj_size, count + 1, [{y, x, t, f} | acc])
    else
      filter_oam_y(rest, ly, obj_size, count, acc)
    end
  end

  defp filter_oam_x(oam_list), do: filter_oam_x(oam_list, 0, [])
  defp filter_oam_x([], _count, acc), do: acc
  defp filter_oam_x([{_, x, _, _} = obj | rest], count, acc) do
    if x > 0 and x < 168 do
      filter_oam_x(rest, count + 1, [{obj, count} | acc])
    else
      filter_oam_x(rest, count, acc)
    end
  end

  defp get_object_map(oam_data, vram, lcdc, ly, obp0, obp1) do
    obj_size = elem(@obj_size, lcdc)
    oam_data
    |> filter_oam_y(ly, obj_size)
    |> filter_oam_x()
    |> Enum.sort(fn {{_, x0, _, _}, i0}, {{_, x1, _, _}, i1} -> 
      (x0 < x1) or (x0 === x1 and i0 > i1)
    end)
    |> Enum.reduce(%{}, fn {{y, x, tile_id, flags}, _}, acc ->
      palette = if elem(@palette_flag, flags), do: obp1, else: obp0
      prioritize_bg = elem(@prioritize_bg, flags)
      # Vertical flip
      line = if elem(@flip_y, flags) do
        obj_size - ((ly - y + 16) &&& 0xff) - 1
      else
        (ly - y + 16) &&& 0xff
      end
      # If line >= 8, get pixels from the next tile (this can happen when obj_size == 16)
      {line, tile_id} = if line >= 8, do: {line - 8, tile_id + 1}, else: {line, tile_id}
      # Horizontal flip
      tile_bytes = if elem(@flip_x, flags), do: @tile_bytes_rev, else: @tile_bytes
      elem(tile_bytes, RWMemory.read_short(vram, (tile_id * 16) + (line * 2)))
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

  defp draw_scanline_now(ppu(oam: %{data: oam_data}, vram: vram, lcdc: lcdc, scy: scy, scx: scx, ly: ly, wy: wy, wx: wx, bgp: bgp, obp0: obp0, obp1: obp1) = _p) do
    scanline(oam_data, vram, lcdc, scy, scx, ly, wy, wx, bgp, obp0, obp1)
  end

  defp scanline(oam_data, vram, lcdc, scy, scx, ly, wy, wx, bgp, obp0, obp1) do
    objs = if elem(@obj_enable, lcdc) do
      get_object_map(oam_data, vram, lcdc, ly, obp0, obp1)
    else
      %{}
    end
    n_obj = map_size(objs)

    if not elem(@bg_win_enable, lcdc) do
      mix_no_bg_win(objs, n_obj)
    else
      y = (scy + ly) &&& 0xff
      bg_line = rem(y, 8) * 2
      bg_row_addr = elem(@bg_tile_map_addr, lcdc) + (div(y, 8) * 32)
      bg_tile_index = div(scx, 8) &&& 0x1f
      scx_offset = rem(scx, 8)

      tile_bytes = @tile_bytes
      bg_fn = if elem(@tile_data_addr, lcdc) do
        # 0x8000 address mode
        fn tile_id -> elem(tile_bytes, RWMemory.read_short(vram, (tile_id * 16) + bg_line)) end
      else
        # 0x8800 address mode
        fn tile_id ->
          elem(tile_bytes, RWMemory.read_short(vram, 0x1000 + (elem(@tile_id_8800, tile_id) * 16) + bg_line))
        end
      end

      bg_indexes = if scx_offset === 0 do
        elem(@tile_indexes, bg_tile_index)
      else
        elem(@tile_indexes_extra, bg_tile_index)
      end

      bg_row = RWMemory.read_range(vram, bg_row_addr, 32)
               |> List.to_tuple()
      
      render_window = elem(@window_enable, lcdc) and ly >= wy and wy <= 143 and wx >= 0 and wx <= 166
      if not render_window do
        mix_no_win(-scx_offset, bg_indexes, bg_row, bg_fn, objs, n_obj, bgp)
      else
        win_y = (ly - wy) &&& 0xff
        win_x = wx - 7
        win_row_addr = elem(@window_tile_map_addr, lcdc) + (div(win_y, 8) * 32)
        win_line = rem(win_y, 8) * 2
        win_row = RWMemory.read_range(vram, win_row_addr, 32)
                  |> List.to_tuple()
        win_fn = if elem(@tile_data_addr, lcdc) do
          # 0x8000 address mode
          fn tile_id -> elem(tile_bytes, RWMemory.read_short(vram, (tile_id * 16) + win_line)) end
        else
          # 0x8800 address mode
          fn tile_id ->
            elem(tile_bytes, RWMemory.read_short(vram, 0x1000 + (elem(@tile_id_8800, tile_id) * 16) + win_line))
          end
        end
        win_indexes = @win_tile_indexes
        mix(-scx_offset, win_x, bg_indexes, bg_row, bg_fn, win_indexes, win_row, win_fn, objs, n_obj, bgp)
      end
    end
  end

  defp mix(x, win_x, bg_indexes, bg_row, bg_fn, win_indexes, win_row, win_fn, objs, n_obj, bgp) do
    # Entry point
    [h_bg | rest_bg] = bg_indexes
    mix_pre_win(x, win_x, bg_fn.(elem(bg_row, h_bg)), rest_bg, bg_row, bg_fn, win_indexes, win_row, win_fn, objs, n_obj, bgp)
  end

  defp mix_pre_win(x, win_x, [_p | rest], bg_indexes, bg_row, bg_fn, win_indexes, win_row, win_fn, objs, n_obj, bgp) when x < 0 do
    # Throw away pixels while x < 0
    mix_pre_win(x + 1, win_x, rest, bg_indexes, bg_row, bg_fn, win_indexes, win_row, win_fn, objs, n_obj, bgp)
  end
  defp mix_pre_win(x, win_x, bg_tile, bg_indexes, bg_row, bg_fn, win_indexes, win_row, win_fn, objs, n_obj, bgp) do
    # Start mixing pixels
    _mix_pre_win(x, win_x, bg_tile, bg_indexes, bg_row, bg_fn, win_indexes, win_row, win_fn, objs, n_obj, bgp, [])
  end

  defp _mix_pre_win(x, win_x, _bg_tile, _bg_indexes, _bg_row, _bg_fn, win_indexes, win_row, win_fn, objs, n_obj, bgp, pixels) when win_x <= 0 do
    # Start rendering windows
    [h_win | rest_win] = win_indexes
    win_tile = win_fn.(elem(win_row, h_win)) 
    win_tile = if win_x === 0, do: win_tile, else: Enum.drop(win_tile, -win_x)
    _mix(x, win_tile, rest_win, win_row, win_fn, objs, n_obj, bgp, pixels)
  end
  defp _mix_pre_win(x, win_x, [] = _bg_tile, bg_indexes, bg_row, bg_fn, win_indexes, win_row, win_fn, objs, n_obj, bgp, pixels) do
    # Get a new tile when bg_tile is empty
    [h_bg | rest_bg] = bg_indexes
    _mix_pre_win(x, win_x, bg_fn.(elem(bg_row, h_bg)), rest_bg, bg_row, bg_fn, win_indexes, win_row, win_fn, objs, n_obj, bgp, pixels)
  end
  defp _mix_pre_win(x, win_x, [p | rest] = _bg_tile, bg_indexes, bg_row, bg_fn, win_indexes, win_row, win_fn, objs, 0, bgp, pixels) do
    # No obj pixels
    pixel = [(bgp >>> (p * 2)) &&& 0x3]
    _mix_pre_win(x + 1, win_x - 1, rest, bg_indexes, bg_row, bg_fn, win_indexes, win_row, win_fn, objs, 0, bgp, [pixels | pixel])
  end
  defp _mix_pre_win(x, win_x, [p | rest] = _bg_tile, bg_indexes, bg_row, bg_fn, win_indexes, win_row, win_fn, objs, n_obj, bgp, pixels) do
    # Mix a background and obj pixel
    case objs do
      %{^x => {sp, true}} ->
        bg_pixel = (bgp >>> (p * 2)) &&& 0x3
        pixel = if bg_pixel === elem(@off_color, bgp), do: sp, else: bg_pixel
        pixel = [pixel]
        _mix_pre_win(x + 1, win_x - 1, rest, bg_indexes, bg_row, bg_fn, win_indexes, win_row, win_fn, objs, n_obj - 1, bgp, [pixels | pixel])
      %{^x => {sp, _}} ->
        pixel = [sp]
        _mix_pre_win(x + 1, win_x - 1, rest, bg_indexes, bg_row, bg_fn, win_indexes, win_row, win_fn, objs, n_obj - 1, bgp, [pixels | pixel])
      _ ->
        bg_pixel = (bgp >>> (p * 2)) &&& 0x3
        pixel = [bg_pixel]
        _mix_pre_win(x + 1, win_x - 1, rest, bg_indexes, bg_row, bg_fn, win_indexes, win_row, win_fn, objs, n_obj, bgp, [pixels | pixel])
    end
  end

  defp mix_no_win(x, bg_indexes, bg_row, bg_fn, objs, n_obj, bgp) do
    # Entry point
    [h | rest] = bg_indexes
    mix_no_win(x, bg_fn.(elem(bg_row, h)), rest, bg_row, bg_fn, objs, n_obj, bgp)
  end
  defp mix_no_win(x, [_p | rest], bg_indexes, bg_row, bg_fn, objs, n_obj, bgp) when x < 0 do
    # Throw away pixels while x < 0
    mix_no_win(x + 1, rest, bg_indexes, bg_row, bg_fn, objs, n_obj, bgp)
  end
  defp mix_no_win(x, bg_tile, bg_indexes, bg_row, bg_fn, objs, n_obj, bgp) do
    # Start mixing pixels
    _mix(x, bg_tile, bg_indexes, bg_row, bg_fn, objs, n_obj, bgp, [])
  end

  # No background or window (objs only)
  defp mix_no_bg_win(objs, n_obj) do
    # Entry point
    _mix_no_bg_win(0, objs, n_obj, [])
  end
  defp _mix_no_bg_win(@screen_width, _objs, _n_obj, pixels), do: pixels
  defp _mix_no_bg_win(x, objs, 0, pixels) do
    # No obj pixels = just append white_color
    _mix_no_bg_win(x + 1, objs, 0, [pixels | [@white_color]])
  end
  defp _mix_no_bg_win(x, objs, n_obj, pixels) do
    # Mix a pixel (white_color or obj pixel)
    case objs do
      %{^x => {sp, _}} ->
        pixel = [sp]
        _mix_no_bg_win(x + 1, objs, n_obj - 1, [pixels | pixel])
      _ ->
        _mix_no_bg_win(x + 1, objs, n_obj, [pixels | [@white_color]])
    end
  end

  defp _mix(@screen_width, _bg_tile, _bg_indexes, _bg_row, _bg_fn, _objs, _n_obj, _bgp, pixels), do: pixels
  defp _mix(x, [] = _bg_tile, bg_indexes, bg_row, bg_fn, objs, n_obj, bgp, pixels) do
    # Get a new tile when bg_tile is empty
    [h | rest] = bg_indexes
    _mix(x, bg_fn.(elem(bg_row, h)), rest, bg_row, bg_fn, objs, n_obj, bgp, pixels)
  end
  defp _mix(x, [p | rest] = _bg_tile, bg_indexes, bg_row, bg_fn, objs, 0, bgp, pixels) do
    # No obj pixels
    bg_pixel = (bgp >>> (p * 2)) &&& 0x3
    pixel = [bg_pixel]
    _mix(x + 1, rest, bg_indexes, bg_row, bg_fn, objs, 0, bgp, [pixels | pixel])
  end
  defp _mix(x, [p | rest] = _bg_tile, bg_indexes, bg_row, bg_fn, objs, n_obj, bgp, pixels) do
    # Mix a pixel
    case objs do
      %{^x => {sp, true}} ->
        bg_pixel = (bgp >>> (p * 2)) &&& 0x3
        pixel = if bg_pixel === elem(@off_color, bgp), do: sp, else: bg_pixel
        pixel = [pixel]
        _mix(x + 1, rest, bg_indexes, bg_row, bg_fn, objs, n_obj - 1, bgp, [pixels | pixel])
      %{^x => {sp, _}} ->
        pixel = [sp]
        _mix(x + 1, rest, bg_indexes, bg_row, bg_fn, objs, n_obj - 1, bgp, [pixels | pixel])
      _ ->
        bg_pixel = (bgp >>> (p * 2)) &&& 0x3
        pixel = [bg_pixel]
        _mix(x + 1, rest, bg_indexes, bg_row, bg_fn, objs, n_obj, bgp, [pixels | pixel])
    end
  end

  defp render(ppu(buffer: buffer)) do
    screen_data = IO.iodata_to_binary(buffer)
    send(Minarai, {:update_screen, screen_data})
  end

end
