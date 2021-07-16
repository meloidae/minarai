defmodule Gameboy.Ppu do
  use Bitwise
  alias Gameboy.Memory
  alias Gameboy.Ppu

  defmodule Gameboy.Ppu.Fetcher do
    alias Gameboy.Ppu.Fetcher
    alias Gameboy.Ppu
    defstruct counter: 0,
              mode: :read_tile_id,
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

    def start(fetcher, map_addr, tile_line) do
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
              ready: false

    def init do
      # buffer = :array.new([size: @screen_width * @screen_height, fixed: true, default: 0])
      buffer = []
      %Screen{buffer: buffer, ready: false}
    end

    # screen buffer using list
    def write(%Screen{buffer: buffer} = screen, value), do: %{screen | buffer: [value | buffer]}
    def vblank(screen), do: %{screen | ready: true}

    # screen buffer using array
    # def write(%Screen{index: index, buffer: buffer} = screen, value) do
    #   new_buffer = :array.set(index, value, buffer)
    #   %{screen | index: index + 1, buffer: new_buffer}
    # end

    # def vblank(%Screen{index: index} = screen), do: put_in(screen.index, 0)
  end

  alias Gameboy.Ppu.Fetcher
  alias Gameboy.Ppu.Screen

  defstruct vram: struct(Memory),
            oam: struct(Memory),
            mode: :oam_search,
            counter: 0,
            x: 0,
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
    %Ppu{vram: vram, oam: oam, counter: @oam_search_cycles, fetcher: fetcher, screen: screen}
  end

  def read_vram(%Ppu{vram: vram} = ppu, addr), do: Memory.read(vram, addr &&& @vram_mask)

  def write_vram(%Ppu{vram: vram} = ppu, addr, value) do
    put_in(ppu.vram, Memory.write(vram, addr &&& @vram_mask, value))
  end

  def bg_palette(%Ppu{bgp: bgp} = ppu), do: bgp

  def set_bg_palette(%Ppu{} = ppu, value), do: put_in(ppu.bgp, value &&& 0xff)


  def read_tile_line(:low, ppu, %Fetcher{tile_id: tile_id, tile_line: tile_line} = fetcher) do
    # Tile's data takes 16 bytes
    base_addr = 0x8000 + (tile_id * 16)
    addr = base_addr + (tile_line * 2)

    data = read_vram(ppu, addr)
    Enum.map(7..0, fn i -> (data >>> i) &&& 0x1 end)
  end

  def read_tile_line(:high, ppu, %Fetcher{tile_id: tile_id, tile_line: tile_line} = fetcher) do
    # Tile's data takes 16 bytes
    base_addr = 0x8000 + (tile_id * 16)
    addr = base_addr + (tile_line * 2)

    data = read_vram(ppu, addr + 1)
    Enum.map(7..0, fn i -> (data >>> i) &&& 0x1 end)
  end

  def fetcher_cycle(%Ppu{vram: vram} = ppu, %Fetcher{mode: mode, counter: counter} = fetcher) do
    new_counter = counter + 1
    if new_counter < 2 do
      %{fetcher | counter: new_counter}
    else
      case mode do
        :read_tile_id ->
          tile_id = read_vram(ppu, fetcher.map_addr + fetcher.tile_index)
          %{fetcher | mode: :read_tile_data_low, tile_id: tile_id, counter: 0}
        :read_tile_data_low ->
          pixel_data = read_tile_line(:low, ppu, fetcher)
          %{fetcher | mode: :read_tile_data_high, pixel_data_low: pixel_data, counter: 0}
        :read_tile_data_high ->
          pixel_data = read_tile_line(:high, ppu, fetcher)
          %{fetcher | mode: :push_fifo, pixel_data_high: pixel_data, counter: 0}
        :push_fifo ->
          if fetcher.fifo_size <= 8 do
            # Push pixels to the queue if there are <= 8 pixels in the queue
            new_fifo = Stream.zip(fetcher.pixel_data_high, fetcher.pixel_data_low)
                       |> Enum.reduce(fetcher.fifo, fn p, q -> :queue.in(p, q) end)
            # Move to next tile (tile_index++)
            %{fetcher | mode: :read_tile_id,
                        fifo: new_fifo,
                        fifo_size: fetcher.fifo_size + 8,
                        tile_index: fetcher.tile_index + 1,
                        counter: 0}
          else
            %{fetcher | counter: 0}
          end
      end
    end
  end

  def fetcher_pop(%Fetcher{fifo: fifo, fifo_size: fifo_size} = fetcher) do
    {{:value, value}, new_fifo} = :queue.out(fifo)
    {value, %{fetcher | fifo: new_fifo, fifo_size: fifo_size - 1}}
  end

  def cycle(ppu), do: do_cycle(ppu, 4)

  defp do_cycle(ppu, 0), do: ppu

  defp do_cycle(ppu, n) do
    new_ppu = t_cycle(ppu)
    do_cycle(new_ppu, n - 1)
  end

  # Do one T-cycle (not M-Cycle)
  defp t_cycle(%Ppu{counter: counter, mode: mode, ly: ly, x: x, fetcher: fetcher} = ppu) do
    new_counter = counter + 1
    case mode do
      :oam_search -> # Mode 2
        # Scanning OAM takes 40 cycles
        if new_counter == 40 do
          # Set up pixel fetcher
          tile_line = rem(ly, 8)
          row_addr = 0x9800 + (div(ly, 8) * 32)
          new_fetcher = Fetcher.start(fetcher, row_addr, tile_line)
          %{ppu | mode: :pixel_transfer, counter: new_counter, x: 0, fetcher: new_fetcher}
        else
          %{ppu | counter: new_counter}
        end
      :pixel_transfer -> # Mode 3
        # Do fetcher stuff
        new_fetcher = fetcher_cycle(ppu, fetcher)
        # Only pop if fifo has more than 8 pixels
        if new_fetcher.fifo_size <= 8 do
          %{ppu | counter: new_counter, fetcher: new_fetcher}
        else
          # Pop pixel from fifo and print it to screen
          {pixel_color, new_fetcher} = fetcher_pop(new_fetcher)
          # Put pixel to screen
          screen = Screen.write(ppu.screen, pixel_color)
          new_x = x + 1
          # Do scanline stuff
          if new_x == 160 do
            %{ppu | mode: :hblank, counter: new_counter, x: new_x, fetcher: new_fetcher, screen: screen}
          else
            %{ppu | counter: new_counter, x: new_x, fetcher: new_fetcher, screen: screen}
          end
        end
      :hblank -> # Mode 0
        # Full scanline takes 456 cycles
        if new_counter == 456 do
          new_ly = ly + 1
          if new_ly == 144 do
            screen = Screen.vblank(ppu.screen)
            %{ppu | mode: :vblank, counter: 0, ly: new_ly, screen: screen}
          else
            %{ppu | mode: :oam_search, counter: 0, ly: new_ly}
          end
        else
          %{ppu | counter: new_counter}
        end
      :vblank -> # Mode 1
        if new_counter == 456 do
          new_ly = ly + 1
          if new_ly == 153 do
            %{ppu | mode: :oam_search, counter: 0, ly: 0}
          else
            %{ppu | counter: 0, ly: new_ly}
          end
        else
          %{ppu | counter: new_counter}
        end
    end
  end

  # Screen buffer using list
  def screen_buffer(ppu), do: Stream.map(ppu.screen.buffer, fn p -> color(p) end)

  def screen_buffer_ready(ppu), do: ppu.screen.ready

  def flush_screen_buffer(ppu) do
    %{ppu | screen: Screen.init()}
  end

  # Screen buffer using array
  # def screen_buffer(%Ppu{screen: screen} = ppu) do
  #   :array.to_list(screen.buffer)
  #   |> Stream.map(fn p -> color(p) end)
  # end

  def color({1, 1}), do: {15, 65, 15}
  def color({1, 0}), do: {48, 98, 48}
  def color({0, 1}), do: {139, 172, 15}
  def color({0, 0}), do: {155, 188, 15}

end
