defmodule Gameboy.Ppu do
  use Bitwise
  alias Gameboy.Memory
  alias Gameboy.Ppu
  alias Gameboy.Utils.Fifo

  defmodule Gameboy.Ppu.Fetcher do
    alias Gameboy.Ppu.Fetcher
    alias Gameboy.Ppu
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

  defmodule Gameboy.Ppu.Screen do
    alias Gameboy.Ppu.Screen

    @screen_width 160
    @screen_height 144

    defstruct index: 0,
              buffer: nil,
              enabled: false,
              ready: false

    @color {<<155, 188, 15>>, <<139, 172, 15>>, <<48, 98, 48>>, <<15, 65, 15>>}
    @empty_buffer 1..@screen_width * @screen_height
                  |> Enum.reduce([], fn _, acc -> [acc | elem(@color, 0)] end)
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

    # Screen buffer using map
    # def write(%Screen{index: index, buffer: buffer} = screen, value) do
    #   %{screen | index: index + 1, buffer: Map.put(buffer, index, value)}
    # end
    # def vblank(%Screen{index: index} = screen) do
    #   # IO.puts("Vblank")
    #   %{screen | index: 0, ready: true}
    # end
    # def flush(%Screen{} = screen), do: Map.put(screen, :ready, false)

    # Screen buffer using binary
    # def write(%Screen{buffer: buffer} = screen, value) do
    #   Map.put(screen, :buffer, buffer <> elem(@color, value))
    #   # Map.put(screen, :buffer, buffer <> color(value))
    # end
    # def vblank(screen), do: Map.put(screen, :ready, true)
    # def flush(screen) do
    #   %{screen | ready: false, buffer: <<>>}
    # end

    # Screen buffer usin iolist
    def write(%Screen{buffer: buffer} = screen, value) do
      Map.put(screen, :buffer, [buffer | elem(@color, value)])
      # Map.put(screen, :buffer, buffer <> color(value))
    end
    def vblank(screen), do: Map.put(screen, :ready, true)
    def flush(screen) do
      # Screen.init()
      %{screen | ready: false, buffer: []}
    end

  end

  defmodule Gameboy.Ppu.LcdcRegiser do
    alias Gameboy.Ppu.LcdcRegiser
    defstruct value: 0x00,
              display_enable: false

    def init(value) do
      display_enable = (value &&& (1 <<< 7)) != 0
      %LcdcRegiser{value: value, display_enable: display_enable}
    end
  end

  alias Gameboy.Ppu.Fetcher
  alias Gameboy.Ppu.Screen
  alias Gameboy.Ppu.LcdcRegiser

  defstruct vram: struct(Memory),
            oam: struct(Memory),
            mode: :oam_search,
            counter: 0,
            x: 0,
            lcdc: struct(LcdcRegiser),
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
    %Ppu{vram: vram, oam: oam, counter: @oam_search_cycles, fetcher: fetcher, screen: screen}
  end

  def read_vram(%Ppu{vram: vram} = ppu, addr, opt \\ nil), do: Memory.read(vram, addr &&& @vram_mask, opt)

  def write_vram(%Ppu{vram: vram} = ppu, addr, value) do
    Map.put(ppu, :vram, Memory.write(vram, addr &&& @vram_mask, value))
  end

  def lcd_control(%Ppu{lcdc: lcdc} = ppu), do: lcdc.value

  def set_lcd_control(%Ppu{} = ppu, value), do: Map.put(ppu, :lcdc, LcdcRegiser.init(value &&& 0xff))

  def bg_palette(%Ppu{bgp: bgp} = ppu), do: bgp

  def set_bg_palette(%Ppu{} = ppu, value), do: Map.put(ppu, :bgp, value &&& 0xff)

  def scroll_y(%Ppu{scy: scy} = ppu), do: scy
  def set_scroll_y(%Ppu{} = ppu, value), do: Map.put(ppu, :scy, value &&& 0xff)

  def scroll_x(%Ppu{scx: scx} = ppu), do: scx
  def set_scroll_x(%Ppu{} = ppu, value), do: Map.put(ppu, :scx, value &&& 0xff)

  def line_y(%Ppu{ly: ly} = ppu), do: ly
  # ly is read only
  def set_line_y(%Ppu{} = ppu, _), do: ppu

  defp parse_tile_byte(
    <<b0::size(1), b1::size(1), b2::size(1), b3::size(1),
      b4::size(1), b5::size(1), b6::size(1), b7::size(1)>>
  ) do
    # [b7, b6, b5, b4, b3, b2, b1, b0]
    [b0, b1, b2, b3, b4, b5, b6, b7]
  end

  def read_tile_line(:low, ppu, %Fetcher{tile_id: tile_id, tile_line: tile_line} = fetcher) do
    # Tile's data takes 16 bytes
    base_addr = 0x8000 + (tile_id * 16)
    addr = base_addr + (tile_line * 2)

    data = read_vram(ppu, addr, :bin)
    parse_tile_byte(data)
  end

  def read_tile_line(:high, ppu, %Fetcher{tile_id: tile_id, tile_line: tile_line} = fetcher) do
    # Tile's data takes 16 bytes
    base_addr = 0x8000 + (tile_id * 16)
    addr = base_addr + (tile_line * 2)

    data = read_vram(ppu, addr + 1, :bin)
    parse_tile_byte(data)
  end

  defp push_to_fifo([], [], fifo), do: fifo
  defp push_to_fifo([high | high_rest], [low | low_rest], fifo) do
    push_to_fifo(high_rest, low_rest, :queue.in((high <<< 1) ||| low, fifo))
  end

  def fetcher_cycle(%Ppu{} = ppu, %Fetcher{mode: :read_tile_id} = fetcher) do
    tile_id = read_vram(ppu, fetcher.map_addr + fetcher.tile_index)
    %{fetcher | mode: :read_tile_data_low, tile_id: tile_id}
  end

  def fetcher_cycle(%Ppu{} = ppu, %Fetcher{mode: :read_tile_data_low} = fetcher) do
    pixel_data = read_tile_line(:low, ppu, fetcher)
    %{fetcher | mode: :read_tile_data_high, pixel_data_low: pixel_data}
  end

  def fetcher_cycle(%Ppu{} = ppu, %Fetcher{mode: :read_tile_data_high} = fetcher) do
    pixel_data = read_tile_line(:high, ppu, fetcher)
    %{fetcher | mode: :push_fifo, pixel_data_high: pixel_data}
  end

  def fetcher_cycle(%Ppu{} = ppu, %Fetcher{mode: :push_fifo} = fetcher) do
    if fetcher.fifo_size <= 8 do
      # Push pixels to the queue if there are <= 8 pixels in the queue
      new_fifo = push_to_fifo(fetcher.pixel_data_high, fetcher.pixel_data_low, fetcher.fifo)
      # Move to next tile (tile_index++)
      %{fetcher | mode: :read_tile_id,
                  fifo: new_fifo,
                  fifo_size: fetcher.fifo_size + 8,
                  tile_index: fetcher.tile_index + 1
      }
    else
      fetcher
    end
  end

  # def fetcher_cycle(%Ppu{} = ppu, %Fetcher{mode: mode} = fetcher) do
  #   case mode do
  #     :read_tile_id ->
  #       tile_id = read_vram(ppu, fetcher.map_addr + fetcher.tile_index)
  #       %{fetcher | mode: :read_tile_data_low, tile_id: tile_id}
  #     :read_tile_data_low ->
  #       pixel_data = read_tile_line(:low, ppu, fetcher)
  #       %{fetcher | mode: :read_tile_data_high, pixel_data_low: pixel_data}
  #     :read_tile_data_high ->
  #       pixel_data = read_tile_line(:high, ppu, fetcher)
  #       %{fetcher | mode: :push_fifo, pixel_data_high: pixel_data}
  #     :push_fifo ->
  #       if fetcher.fifo_size <= 8 do
  #         # Push pixels to the queue if there are <= 8 pixels in the queue
  #         new_fifo = push_to_fifo(fetcher.pixel_data_high, fetcher.pixel_data_low, fetcher.fifo)
  #         # Move to next tile (tile_index++)
  #         %{fetcher | mode: :read_tile_id,
  #                     fifo: new_fifo,
  #                     fifo_size: fetcher.fifo_size + 8,
  #                     tile_index: fetcher.tile_index + 1
  #         }
  #       else
  #         fetcher
  #       end
  #   end
  # end

  def fetcher_pop(%Fetcher{fifo: fifo, fifo_size: fifo_size} = fetcher) do
    {{:value, value}, new_fifo} = :queue.out(fifo)
    {value, %{fetcher | fifo: new_fifo, fifo_size: fifo_size - 1}}
  end

  def cycle(ppu), do: do_cycle(ppu, 4)

  def do_cycle(ppu, 0), do: ppu

  def do_cycle(ppu, n) do
    do_cycle(t_cycle(ppu), n - 1)
  end

  # Do one T-cycle (not M-Cycle)
  defp t_cycle(%Ppu{screen: screen, lcdc: lcdc} = ppu) do
    case {screen.enabled, lcdc.display_enable} do
      {true, true} -> # Display is already enabled & display is on
        do_t_cycle(ppu)
      {true, false} -> # Disable display & reset ppu states
        %{ppu | ly: 0, x: 0, screen: Screen.disable(screen)}
      {false, true} -> # Enable display & run ppu cycle
        ppu = %{ppu | mode: :oam_search, screen: Screen.enable(screen)}
        do_t_cycle(ppu)
      {false, false} -> # Do nothing
        ppu
    end
  end

  defp do_t_cycle(%Ppu{counter: counter, mode: mode} = ppu) do
    new_counter = counter + 1
    case mode do
      :oam_search -> # Mode 2
        cycle_oam_search(ppu, new_counter)
      :pixel_transfer -> # Mode 3
        cycle_pixel_transfer(ppu, new_counter)
      :hblank -> # Mode 0
        cycle_hblank(ppu, new_counter)
      :vblank -> # Mode 1
        cycle_vblank(ppu, new_counter)
    end
  end

  defp cycle_oam_search(%Ppu{scy: scy, ly: ly, fetcher: fetcher} = ppu, counter) do
    # Scanning OAM takes 40 cycles
    if counter == 40 do
      # Set up pixel fetcher
      y = scy + ly
      tile_line = rem(y, 8)
      row_addr = 0x9800 + (div(y, 8) * 32)
      new_fetcher = Fetcher.start(fetcher, row_addr, tile_line)
      %{ppu | mode: :pixel_transfer, counter: counter, x: 0, fetcher: new_fetcher}
    else
      Map.put(ppu, :counter, counter)
    end
  end

  defp cycle_pixel_transfer(%Ppu{x: x, fetcher: fetcher, screen: screen} = ppu, counter) do
    new_fetcher = if rem(counter, 2) == 0, do: fetcher_cycle(ppu, fetcher), else: fetcher
    # Only pop if fifo has more than 8 pixels
    if new_fetcher.fifo_size <= 8 do
      %{ppu | counter: counter, fetcher: new_fetcher}
    else
      # Pop pixel from fifo and print it to screen
      {pixel, new_fetcher} = fetcher_pop(new_fetcher)
      # Put pixel to screen
      palette_color = (ppu.bgp >>> (pixel * 2)) &&& 0x3
      screen = Screen.write(screen, palette_color)
      new_x = x + 1
      # Do scanline stuff
      if new_x == 160 do
        %{ppu | mode: :hblank, counter: counter, x: new_x, fetcher: new_fetcher, screen: screen}
      else
        %{ppu | counter: counter, x: new_x, fetcher: new_fetcher, screen: screen}
      end
    end
  end

  def cycle_hblank(%Ppu{ly: ly, screen: screen} = ppu, counter) do
    # Full scanline takes 456 cycles
    if counter == 456 do
      new_ly = ly + 1
      if new_ly == 144 do
        %{ppu | mode: :vblank, counter: 0, ly: new_ly, screen: Screen.vblank(screen)}
      else
        %{ppu | mode: :oam_search, counter: 0, ly: new_ly}
      end
    else
      Map.put(ppu, :counter, counter)
    end
  end

  def cycle_vblank(%Ppu{ly: ly} = ppu, counter) do
    if counter == 456 do
      new_ly = ly + 1
      if new_ly == 153 do
        %{ppu | mode: :oam_search, counter: 0, ly: 0}
      else
        %{ppu | counter: 0, ly: new_ly}
      end
    else
      Map.put(ppu, :counter, counter)
    end
  end

  def screen_buffer_ready(ppu), do: ppu.screen.ready

  # Screen buffer using map
  # def screen_buffer(%Ppu{screen: screen} = ppu) do
  #   screen.buffer
  #   |> Stream.map(fn {i, p} -> {i, color(p)} end)
  # end
  # def flush_screen_buffer(ppu), do: put_in(ppu.screen.ready, false)

  # Screen buffer using binary
  # def screen_buffer(%Ppu{screen: screen} = ppu), do: screen.buffer
  # def flush_screen_buffer(%Ppu{screen: screen} = ppu) do
  #   Map.put(ppu, :screen, Screen.flush(screen))
  # end

  # Screen buffer using iolist
  def screen_buffer(%Ppu{screen: screen} = ppu), do: screen.buffer |> IO.iodata_to_binary()
  def flush_screen_buffer(%Ppu{screen: screen} = ppu) do
    Map.put(ppu, :screen, Screen.flush(screen))
  end

  # def color({1, 1}), do: {15, 65, 15}
  # def color({1, 0}), do: {48, 98, 48}
  # def color({0, 1}), do: {139, 172, 15}
  # def color({0, 0}), do: {155, 188, 15}
  # def color(0b11), do: {15, 65, 15}
  # def color(0b10), do: {48, 98, 48}
  # def color(0b01), do: {139, 172, 15}
  # def color(0b00), do: {155, 188, 15}


end
