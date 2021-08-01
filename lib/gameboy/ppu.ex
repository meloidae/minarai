defmodule Gameboy.Ppu do
  use Bitwise
  alias Gameboy.Memory
  alias Gameboy.Ppu


  defmodule Fetcher do

    defstruct mode: :read_tile_id,
              fifo: nil,
              fifo_size: 0,
              tile_id: 0,
              tile_index: 0,
              map_addr: 0,
              tile_line: 0,
              pixel_data_low: nil,
              pixel_data_high: nil

    def init do
      fifo = :queue.new()
      %Fetcher{fifo: fifo}
    end

    def start(%Fetcher{fifo: fifo} = fetcher, map_addr, tile_line) do
      # Reset fifo
      fifo = :queue.new()
      %{fetcher | mode: :read_tile_id, fifo: fifo, fifo_size: 0, tile_index: 0, map_addr: map_addr, tile_line: tile_line}
    end
  end

  defmodule Screen do

    @screen_width 160
    @screen_height 144

    defstruct buffer: nil,
              # index: 0,
              enabled: false,
              ready: false

    @color {<<155, 188, 15>>, <<139, 172, 15>>, <<48, 98, 48>>, <<15, 65, 15>>}
    # @empty_buffer 1..@screen_width * @screen_height
    #               |> Enum.reduce([], fn _, acc -> [acc | elem(@color, 0)] end)
    def init do
      # Buffer using map
      # buffer = 0..@screen_width * @screen_height - 1
      #          |> Enum.reduce(%{}, fn i, m -> Map.put(m, i, 0) end)
      # Buffer using binary
      # buffer = <<>>
      # Buffer using iolist
      buffer = []
      # Buffer for testing no ppu loop situation
      # buffer = @empty_buffer
      # Buffer using ets
      # :ets.new(:screen_table, [:ordered_set, :protected, :named_table])
      # %Screen{ready: false}
      # Buffer (pid)
      # {:ok, buffer} = ScreenServer.start_link()
      %Screen{buffer: buffer, ready: false}
    end

    # def color(0b11), do: <<15, 65, 15>>
    # def color(0b10), do: <<48, 98, 48>>
    # def color(0b01), do: <<139, 172, 15>>
    # def color(0b00), do: <<155, 188, 15>>

    # Disable
    def disable(screen), do: Map.put(screen, :enabled, false)
    # Enable
    def enable(screen), do: Map.put(screen, :enabled, true)

    # Screen buffer using binary
    # def write(%Screen{buffer: buffer} = screen, value) do
    #   Map.put(screen, :buffer, buffer <> elem(@color, value))
    #   # Map.put(screen, :buffer, buffer <> color(value))
    # end
    # def vblank(screen), do: Map.put(screen, :ready, true)
    # def flush(screen) do
    #   %{screen | ready: false, buffer: <<>>}
    # end

    # Screen buffer using iolist
    def write(%Screen{buffer: buffer} = screen, value) do
      # Map.put(screen, :buffer, [buffer | elem(@color, value)])
      Map.put(screen, :buffer, [elem(@color, value) | buffer])
    end
    def vblank(screen), do: Map.put(screen, :ready, true)
    # def hblank(screen), do: Map.put(screen, :buffer, screen.buffer |> IO.iodata_to_binary())
    def flush(screen) do
      %{screen | ready: false, buffer: []}
    end

    # Screen buffer using ets
    # def write(%Screen{index: index} = screen, value) do
    #   :ets.insert(:screen_table, {index, elem(@color, value)})
    #   Map.put(screen, :index, index + 1)
    # end
    # def vblank(screen), do: Map.put(screen, :ready, true)
    # def flush(screen) do
    #   %{screen | ready: false, index: 0}
    # end
    
    # def write(%Screen{buffer: buffer} = _screen, value) do
    #   ScreenServer.write(buffer, elem(@color, value))
    # end
    # def vblank(screen), do: Map.put(screen, :ready, true)
    # def flush(%Screen{buffer: buffer} = screen) do
    #   # ScreenServer.flush(buffer)
    #   Map.put(screen, :ready, false)
    # end

  end

  # defmodule LcdcRegiser do
  #   defstruct value: 0x00,
  #             display_enable: false

  #   def init(value) do
  #     display_enable = (value &&& (1 <<< 7)) != 0
  #     %LcdcRegiser{value: value, display_enable: display_enable}
  #   end
  # end

  alias Gameboy.Ppu.Fetcher
  alias Gameboy.Ppu.Screen
  # alias Gameboy.Ppu.LcdcRegiser

  @display_enable 0..255 |> Enum.map(fn x -> (x &&& (1 <<< 7)) != 0 end) |> List.to_tuple()
  defstruct vram: struct(Memory),
            oam: struct(Memory),
            mode: :oam_search,
            counter: 0,
            x: 0,
            # lcdc: struct(LcdcRegiser),
            lcdc: 0x00,
            lcds: 0x00,
            scy: 0x00,
            scx: 0x00,
            ly: 0x00,
            lyc: 0x00,
            bgp: 0x00,
            fetcher: struct(Fetcher),
            screen: struct(Screen)

  @vram_size 0x4000
  @oam_size 0x100
  @vram_mask 0x1fff
  @byte_mask 0xff

  @oam_search_cycles 20
  @drawing_cycles 43
  @hblank_cycles 51
  @vblank_cycles 114

  def init do
    vram = Memory.init(@vram_size)
    oam = Memory.init(@oam_size)
    fetcher = Fetcher.init()
    screen = Screen.init()
    %Ppu{vram: vram, oam: oam, counter: 0, fetcher: fetcher, screen: screen}
  end

  # def read_vram(%Ppu{vram: vram} = _ppu, addr, opt \\ nil), do: Memory.read(vram, addr &&& @vram_mask, opt)
  def read_vram(%Ppu{vram: vram} = _ppu, addr), do: Memory.read(vram, addr &&& @vram_mask)

  def write_vram(%Ppu{vram: vram} = ppu, addr, value) do
    Map.put(ppu, :vram, Memory.write(vram, addr &&& @vram_mask, value))
  end

  # def lcd_control(%Ppu{lcdc: lcdc} = _ppu), do: lcdc.value
  def lcd_control(%Ppu{lcdc: lcdc} = _ppu), do: lcdc

  # def set_lcd_control(%Ppu{} = ppu, value), do: Map.put(ppu, :lcdc, LcdcRegiser.init(value &&& 0xff))
  def set_lcd_control(%Ppu{} = ppu, value), do: Map.put(ppu, :lcdc, value &&& 0xff)

  def bg_palette(%Ppu{bgp: bgp} = ppu), do: bgp

  def set_bg_palette(%Ppu{} = ppu, value), do: Map.put(ppu, :bgp, value &&& 0xff)

  def scroll_y(%Ppu{scy: scy} = ppu), do: scy
  def set_scroll_y(%Ppu{} = ppu, value), do: Map.put(ppu, :scy, value &&& 0xff)

  def scroll_x(%Ppu{scx: scx} = ppu), do: scx
  def set_scroll_x(%Ppu{} = ppu, value), do: Map.put(ppu, :scx, value &&& 0xff)

  def line_y(%Ppu{ly: ly} = ppu), do: ly
  # ly is read only
  def set_line_y(%Ppu{} = ppu, _), do: ppu

  @tile_byte 0..255
  |> Enum.map(fn x ->
    <<b0::size(1), b1::size(1), b2::size(1), b3::size(1),
      b4::size(1), b5::size(1), b6::size(1), b7::size(1)>> = <<x>>
    [b0, b1, b2, b3, b4, b5, b6, b7]
  end)
  |> List.to_tuple()

  # defp parse_tile_byte(
  #   <<b0::size(1), b1::size(1), b2::size(1), b3::size(1),
  #     b4::size(1), b5::size(1), b6::size(1), b7::size(1)>>
  # ) do
  #   # [b7, b6, b5, b4, b3, b2, b1, b0]
  #   [b0, b1, b2, b3, b4, b5, b6, b7]
  # end

  def read_tile_line_low(ppu, fetcher) do
    # Tile's data takes 16 bytes
    # base_addr = 0x8000 + (fetcher.tile_id * 16)
    # addr = base_addr + (fetcher.tile_line * 2)
    # addr = 0x8000 + (fetcher.tile_id * 16) + (fetcher.tile_line * 2)
    addr = 0x8000 + (fetcher.tile_id * 16) + (fetcher.tile_line * 2)

    # data = read_vram(ppu, addr, :bin)
    # parse_tile_byte(data)
    data = read_vram(ppu, addr)
    elem(@tile_byte, data)
  end

  def read_tile_line_high(ppu, fetcher) do
    # Tile's data takes 16 bytes
    # base_addr = 0x8000 + (fetcher.tile_id * 16)
    # addr = base_addr + (fetcher.tile_line * 2)
    addr = 0x8000 + (fetcher.tile_id * 16) + (fetcher.tile_line * 2)

    # data = read_vram(ppu, addr + 1, :bin)
    # parse_tile_byte(data)
    data = read_vram(ppu, addr + 1)
    elem(@tile_byte, data)
  end

  defp push_to_fifo([], [], fifo), do: fifo
  defp push_to_fifo([high | high_rest], [low | low_rest], fifo) do
    # push_to_fifo(high_rest, low_rest, :queue.in(high + low, fifo))
    push_to_fifo(high_rest, low_rest, :queue.in((high <<< 1) ||| low, fifo))
  end
  # ets fifo
  # defp push_to_fifo([], []), do: nil
  # defp push_to_fifo([high | high_rest], [low | low_rest]) do
  #   Gameboy.Fifo.push((high <<< 1) ||| low)
  #   push_to_fifo(high_rest, low_rest)
  # end

  def fetcher_cycle(%Ppu{} = ppu, %Fetcher{mode: :read_tile_id} = fetcher) do
    tile_id = read_vram(ppu, fetcher.map_addr + fetcher.tile_index)
    %{fetcher | mode: :read_tile_data_low, tile_id: tile_id}
  end

  def fetcher_cycle(%Ppu{} = ppu, %Fetcher{mode: :read_tile_data_low} = fetcher) do
    pixel_data = read_tile_line_low(ppu, fetcher)
    %{fetcher | mode: :read_tile_data_high, pixel_data_low: pixel_data}
  end

  def fetcher_cycle(%Ppu{} = ppu, %Fetcher{mode: :read_tile_data_high} = fetcher) do
    pixel_data = read_tile_line_high(ppu, fetcher)
    %{fetcher | mode: :push_fifo, pixel_data_high: pixel_data}
  end

  def fetcher_cycle(%Ppu{} = _ppu, %Fetcher{mode: :push_fifo} = fetcher) do
    if fetcher.fifo_size <= 8 do
      # Push pixels to the queue if there are <= 8 pixels in the queue
      # new_fifo = push_to_fifo(fetcher.pixel_data_high, fetcher.pixel_data_low, fetcher.fifo)
      # push_to_fifo(fetcher.pixel_data_high, fetcher.pixel_data_low)
      # Move to next tile (tile_index++)
      %{fetcher | mode: :read_tile_id,
                  fifo: push_to_fifo(fetcher.pixel_data_high, fetcher.pixel_data_low, fetcher.fifo),
                  fifo_size: fetcher.fifo_size + 8,
                  tile_index: fetcher.tile_index + 1
      }
    else
      fetcher
    end
  end

  def fetcher_pop(%Fetcher{fifo: fifo, fifo_size: fifo_size} = fetcher) do
    {{:value, value}, new_fifo} = :queue.out(fifo)
    {value, %{fetcher | fifo: new_fifo, fifo_size: fifo_size - 1}}
  end
  # ets fifo
  # def fetcher_pop(%Fetcher{fifo_size: fifo_size} = fetcher) do
  #   value = Gameboy.Fifo.pop()
  #   {value, %{fetcher | fifo_size: fifo_size - 1}}
  # end

  # def cycle(ppu), do: do_cycle(ppu, 4)

  # def do_cycle(ppu, 0), do: ppu

  # def do_cycle(ppu, n) do
  #   do_cycle(t_cycle(ppu), n - 1)
  # end
  def cycle(ppu) do
    # case {ppu.lcdc.display_enable, ppu.screen.enabled} do
    case {elem(@display_enable, ppu.lcdc), ppu.screen.enabled} do
      {true, true} -> # Display is already enabled & display is on
        do_cycle(ppu)
      {true, _} -> # Enable display & run ppu cycle
        ppu = %{ppu | mode: :oam_search, screen: Screen.enable(ppu.screen)}
        do_cycle(ppu)
      {false, true} -> # Disable display & reset ppu states
        %{ppu | ly: 0, x: 0, screen: Screen.disable(ppu.screen)}
      _ -> # Do nothing
        ppu
    end
  end


  # defp do_cycle(%Ppu{mode: mode} = ppu) do
  #   case mode do
  #     :oam_search -> # Mode 2
  #       cycle_oam_search(ppu)
  #     :pixel_transfer -> # Mode 3
  #       cycle_pixel_transfer(ppu)
  #     :hblank -> # Mode 0
  #       cycle_hblank(ppu)
  #     :vblank -> # Mode 1
  #       cycle_vblank(ppu)
  #   end
  # end
  defp do_cycle(%Ppu{mode: :oam_search} = ppu), do: cycle_oam_search(ppu)
  defp do_cycle(%Ppu{mode: :pixel_transfer} = ppu), do: cycle_pixel_transfer(ppu)
  defp do_cycle(%Ppu{mode: :hblank} = ppu), do: cycle_hblank(ppu)
  defp do_cycle(%Ppu{mode: :vblank} = ppu), do: cycle_vblank(ppu)

  # defp cycle_oam_search(%Ppu{scy: scy, ly: ly, fetcher: fetcher} = ppu, counter) do
  #   # Scanning OAM takes 40 cycles
  #   if counter == 80 do
  #     # Set up pixel fetcher
  #     y = scy + ly
  #     tile_line = rem(y, 8)
  #     # tile_line = rem(y, 8) * 2
  #     row_addr = 0x9800 + (div(y, 8) * 32)
  #     new_fetcher = Fetcher.start(fetcher, row_addr, tile_line)
  #     %{ppu | mode: :pixel_transfer, counter: counter, x: 0, fetcher: new_fetcher}
  #   else
  #     Map.put(ppu, :counter, counter)
  #   end
  # end
  defp cycle_oam_search(%Ppu{scy: scy, ly: ly, fetcher: fetcher} = ppu) do
    counter = ppu.counter + 4
    # Scanning OAM takes 40 cycles
    if counter == 80 do
      # Set up pixel fetcher
      y = scy + ly
      tile_line = rem(y, 8)
      # tile_line = rem(y, 8) * 2
      row_addr = 0x9800 + (div(y, 8) * 32)
      new_fetcher = Fetcher.start(fetcher, row_addr, tile_line)
      %{ppu | mode: :pixel_transfer, counter: counter, x: 0, fetcher: new_fetcher}
    else
      Map.put(ppu, :counter, counter)
    end
  end

  @even_table 0..456 |> Enum.map(fn x -> rem(x, 2) == 0 end) |> List.to_tuple()
  @multiple_of_four_table 0..456 |> Enum.map(fn x -> rem(x, 4) == 0 end) |> List.to_tuple()
  # @leq_eight 0..16 |> Enum.map(fn x -> x <= 8 end) |> List.to_tuple()
  defp cycle_pixel_transfer(%Ppu{fetcher: fetcher} = ppu) do
    counter = ppu.counter + 1
    new_fetcher = if elem(@even_table, counter), do: fetcher_cycle(ppu, fetcher), else: fetcher
    # Only pop if fifo has more than 8 pixels
    # ppu = if new_fetcher.fifo_size <= 8 do
    ppu = if new_fetcher.fifo_size <= 8 do
      %{ppu | counter: counter, fetcher: new_fetcher}
    else
      # Pop pixel from fifo and print it to screen
      {pixel, new_fetcher} = fetcher_pop(new_fetcher)
      # Put pixel to screen
      palette_color = (ppu.bgp >>> (pixel * 2)) &&& 0x3
      screen = Screen.write(ppu.screen, palette_color)
      new_x = ppu.x + 1
      # Do scanline stuff
      if new_x == 160 do
        counter = counter + 4 - rem(counter, 4)
        %{ppu | mode: :hblank, counter: counter, x: new_x, fetcher: new_fetcher, screen: screen}
      else
        %{ppu | counter: counter, x: new_x, fetcher: new_fetcher, screen: screen}
      end
    end
    if elem(@multiple_of_four_table, ppu.counter), do: ppu, else: cycle_pixel_transfer(ppu)
  end


  # defp cycle_pixel_transfer(%Ppu{fetcher: fetcher} = ppu) do
  #   counter = ppu.counter + 1
  #   new_fetcher = if rem(counter, 2) == 0, do: fetcher_cycle(ppu, fetcher), else: fetcher
  #   # Only pop if fifo has more than 8 pixels
  #   ppu = if new_fetcher.fifo_size <= 8 do
  #     %{ppu | counter: counter, fetcher: new_fetcher}
  #   else
  #     # Pop pixel from fifo and print it to screen
  #     {pixel, new_fetcher} = fetcher_pop(new_fetcher)
  #     # Put pixel to screen
  #     palette_color = (ppu.bgp >>> (pixel * 2)) &&& 0x3
  #     Screen.write(ppu.screen, palette_color)
  #     new_x = ppu.x + 1
  #     # Do scanline stuff
  #     if new_x == 160 do
  #       # IO.puts("Before hblank: #{counter} cycles")
  #       counter = counter + 4 - rem(counter, 4)
  #       %{ppu | mode: :hblank, counter: counter, x: new_x, fetcher: new_fetcher}
  #     else
  #       %{ppu | counter: counter, x: new_x, fetcher: new_fetcher}
  #     end
  #   end
  #   if rem(ppu.counter, 4) == 0, do: ppu, else: cycle_pixel_transfer(ppu)
  # end

  # @even_table 0..456 |> Enum.map(fn x -> rem(x, 2) == 0 end) |> List.to_tuple()
  # @multiple_of_four_table 0..456 |> Enum.map(fn x -> rem(x, 4) == 0 end) |> List.to_tuple()
  # defp cycle_pixel_transfer(%Ppu{fetcher: fetcher} = ppu) do
  #   counter = ppu.counter + 1

  #   ppu = if fetcher.fifo_size <= 8 do
  #     Map.put(ppu, :counter, counter)
  #   else
  #     {pixel, new_fetcher} = fetcher_pop(fetcher)
  #     palette_color = (ppu.bgp >>> (pixel * 2)) &&& 0x3
  #     screen = Screen.write(ppu.screen, palette_color)
  #     new_x = ppu.x + 1
  #     if new_x == 160 do
  #       counter = counter + 4 - rem(counter, 4)
  #       %{ppu | mode: :hblank, counter: counter, x: new_x, fetcher: new_fetcher, screen: screen}
  #     else
  #       %{ppu | counter: counter, x: new_x, fetcher: new_fetcher, screen: screen}
  #     end
  #   end

  #   if elem(@multiple_of_four_table, ppu.counter) do
  #     ppu
  #   else
  #     counter = ppu.counter + 1
  #     new_fetcher = fetcher_cycle(ppu, ppu.fetcher)
  #     ppu = if new_fetcher.fifo_size <= 8 do
  #       %{ppu | counter: counter, fetcher: new_fetcher}
  #     else
  #       {pixel, new_fetcher} = fetcher_pop(new_fetcher)
  #       palette_color = (ppu.bgp >>> (pixel * 2)) &&& 0x3
  #       screen = Screen.write(ppu.screen, palette_color)
  #       new_x = ppu.x + 1
  #       if new_x == 160 do
  #         counter = counter + 4 - rem(counter, 4)
  #         %{ppu | mode: :hblank, counter: counter, x: new_x, fetcher: new_fetcher, screen: screen}
  #       else
  #         %{ppu | counter: counter, x: new_x, fetcher: new_fetcher, screen: screen}
  #       end
  #     end
  #     if elem(@multiple_of_four_table, ppu.counter), do: ppu, else: cycle_pixel_transfer(ppu)
  #   end
  # end

  # defp cycle_hblank(%Ppu{ly: ly} = ppu, counter) do
  #   # Full scanline takes 456 cycles
  #   IO.puts("Hblank counter: #{counter}")
  #   if counter == 456 do
  #     new_ly = ly + 1
  #     if new_ly == 144 do
  #       # %{ppu | mode: :vblank, counter: 0, ly: new_ly, screen: Screen.vblank(screen)}
  #       # Delay vblank timing
  #       %{ppu | mode: :vblank, counter: 0, ly: new_ly}
  #     else
  #       %{ppu | mode: :oam_search, counter: 0, ly: new_ly}
  #     end
  #   else
  #     Map.put(ppu, :counter, counter)
  #   end
  # end

  defp cycle_hblank(%Ppu{ly: ly} = ppu) do
    counter = ppu.counter + 4
    # Full scanline takes 456 cycles
    # IO.puts("Hblank counter: #{counter}")
    if counter == 456 do
      new_ly = ly + 1
      if new_ly == 144 do
        %{ppu | mode: :vblank, counter: 0, ly: new_ly, screen: Screen.vblank(ppu.screen)}
        # Delay vblank timing
        # %{ppu | mode: :vblank, counter: 0, ly: new_ly}
      else
        %{ppu | mode: :oam_search, counter: 0, ly: new_ly}
      end
    else
      Map.put(ppu, :counter, counter)
    end
  end

  # defp cycle_vblank(%Ppu{ly: ly, screen: screen} = ppu, counter) do
  #   if counter == 456 do
  #     new_ly = ly + 1
  #     if new_ly == 153 do
  #       # %{ppu | mode: :oam_search, counter: 0, ly: 0}
  #       # Delay vblank timing
  #       %{ppu | mode: :oam_search, counter: 0, ly: 0, screen: Screen.vblank(screen)}
  #     else
  #       %{ppu | counter: 0, ly: new_ly}
  #     end
  #   else
  #     Map.put(ppu, :counter, counter)
  #   end
  # end

  defp cycle_vblank(%Ppu{ly: ly, screen: screen} = ppu) do
    counter = ppu.counter + 4
    if counter == 456 do
      new_ly = ly + 1
      if new_ly == 153 do
        %{ppu | mode: :oam_search, counter: 0, ly: 0}
        # Delay vblank timing
        # %{ppu | mode: :oam_search, counter: 0, ly: 0, screen: Screen.vblank(screen)}
      else
        %{ppu | counter: 0, ly: new_ly}
      end
    else
      Map.put(ppu, :counter, counter)
    end
  end

  def screen_buffer_ready(ppu), do: ppu.screen.ready

  # Screen buffer using binary
  # def screen_buffer(%Ppu{screen: screen} = ppu), do: screen.buffer
  # def flush_screen_buffer(%Ppu{screen: screen} = ppu) do
  #   Map.put(ppu, :screen, Screen.flush(screen))
  # end

  # Screen buffer using iolist
  def screen_buffer(%Ppu{screen: screen} = _ppu), do: screen.buffer |> IO.iodata_to_binary()
  def flush_screen_buffer(%Ppu{screen: screen} = ppu) do
    Map.put(ppu, :screen, Screen.flush(screen))
  end

end
