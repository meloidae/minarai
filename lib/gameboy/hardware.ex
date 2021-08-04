defmodule Gameboy.Hardware do
  use Bitwise
  alias Gameboy.Hardware
  alias Gameboy.Memory
  alias Gameboy.Bootrom
  alias Gameboy.Cartridge
  # alias Gameboy.Ppu
  alias Gameboy.SimplePpu, as: Ppu
  alias Gameboy.Wram
  alias Gameboy.Hram
  alias Gameboy.Apu
  alias Gameboy.Interrupts
  alias Gameboy.Utils

  defstruct bootrom: struct(Bootrom),
            cart: struct(Cartridge),
            ppu: struct(Ppu),
            wram: struct(Wram),
            hram: struct(Hram),
            apu: struct(Apu),
            timer: 0,
            intr: struct(Interrupts),
            counter: 0

  def synced_read(hw, addr) do
    Hardware.read(hw, addr)
  end
  def synced_read_high(hw, addr), do: synced_read(hw, 0xff00 ||| addr)
  def synced_write(hw, addr, data) do
    Hardware.write(hw, addr, data)
  end
  def synced_write_high(hw, addr, data), do: synced_write(hw, 0xff00 ||| addr, data)
  def sync_cycle(hw) do
    hw
  end

  def init() do
    bootrom = Bootrom.init()
    cart = Cartridge.init()
    ppu = Ppu.init()
    wram = Wram.init()
    hram = Hram.init()
    apu = Apu.init()
    %Hardware{bootrom: bootrom, cart: cart, ppu: ppu, wram: wram, hram: hram, apu: apu}
  end

  defp _read(hw, addr, 0x00) when hw.bootrom.active do
    memory_cycle(hw, fn hw -> {Bootrom.read(hw.bootrom, addr), hw} end)
  end
  for high <- 0..0xff do
    cond do
      high <= 0x3f ->
        defp _read(hw, addr, unquote(high)) do
          memory_cycle(hw, fn hw -> {Cartridge.read_rom_low(hw.cart, addr), hw} end)
        end
      high <= 0x7f ->
        defp _read(hw, addr, unquote(high)) do
          memory_cycle(hw, fn hw -> {Cartridge.read_rom_high(hw.cart, addr), hw} end)
        end
      high <= 0x9f ->
        defp _read(hw, addr, unquote(high)) do
          memory_cycle(hw, fn hw -> {Ppu.read_vram(hw.ppu, addr), hw} end)
        end
      high <= 0xbf ->
        defp _read(hw, addr, unquote(high)) do
          raise "Read from ram at #{Utils.to_hex(addr)} is unimplemented"
        end
      high <= 0xcf ->
        defp _read(hw, addr, unquote(high)) do
          memory_cycle(hw, fn hw -> {Wram.read_low(hw.wram, addr), hw} end)
        end
      high <= 0xdf ->
        defp _read(hw, addr, unquote(high)) do
          memory_cycle(hw, fn hw -> {Wram.read_high(hw.wram, addr), hw} end)
        end
      high <= 0xef ->
        defp _read(hw, addr, unquote(high)) do
          memory_cycle(hw, fn hw -> {Wram.read_low(hw.wram, addr), hw} end)
        end
      high <= 0xfd ->
        defp _read(hw, addr, unquote(high)) do
          memory_cycle(hw, fn hw -> {Wram.read_high(hw.wram, addr), hw} end)
        end
      high == 0xfe ->
        defp _read(hw, addr, unquote(high)) do
          low = addr &&& 0xff
          if low <= 0x9f do
            # oam
            raise "Read from oam at #{Utils.to_hex(addr)} is unimplemented"
          else
            # unusable memory
            raise "Read from unusable memory at #{Utils.to_hex(addr)}"
          end
        end
      true -> 
        defp _read(hw, addr, _) do
          read_ff(hw, addr)
        end
    end
  end

  @high_addr 0..0xffff |> Enum.map(fn x -> (x >>> 8) &&& 0xff end) |> List.to_tuple()
  def read(hw, addr) do
    high_addr = elem(@high_addr, addr)
    # high_addr = (addr >>> 8) &&& 0xff
    _read(hw, addr, high_addr)
  end

  for low <- 0..0xff do
    case low do
      0x00 -> 
        defp _read_ff(hw, addr, unquote(low)) do
          raise "Read from joypad at #{Utils.to_hex(addr)} is unimplemented"
        end
      0x01 ->
        defp _read_ff(hw, addr, unquote(low)) do
          raise "Read from serial data at #{Utils.to_hex(addr)} is unimplemented"
        end
      0x02 ->
        defp _read_ff(hw, addr, unquote(low)) do
          raise "Read from serial control at #{Utils.to_hex(addr)} is unimplemented"
        end
      0x04 ->
        defp _read_ff(hw, addr, unquote(low)) do
          raise "Read from div register at #{Utils.to_hex(addr)} is unimplemented"
        end
      0x05 ->
        defp _read_ff(hw, addr, unquote(low)) do
          raise "Read from tima register at #{Utils.to_hex(addr)} is unimplemented"
        end
      0x06 ->
        defp _read_ff(hw, addr, unquote(low)) do
          raise "Read from tma register at #{Utils.to_hex(addr)} is unimplemtened"
        end
      0x07 ->
        defp _read_ff(hw, addr, unquote(low)) do
          raise "Read from tac register at #{Utils.to_hex(addr)} is unimplemented"
        end
      0x0f ->
        defp _read_ff(hw, addr, unquote(low)) do
          raise "Read from interrupt flag at #{Utils.to_hex(addr)} is unimplemented"
        end
      0x40 ->
        defp _read_ff(hw, addr, unquote(low)) do
          memory_cycle(hw, fn hw -> {Ppu.lcd_control(hw.ppu), hw} end)
        end
      0x41 ->
        defp _read_ff(hw, addr, unquote(low)) do
          raise "Read from ppu lcd status at #{Utils.to_hex(addr)} is unimplemented"
        end
      0x42 ->
        defp _read_ff(hw, addr, unquote(low)) do
          memory_cycle(hw, fn hw -> {Ppu.scroll_y(hw.ppu), hw} end)
        end
      0x43 ->
        defp _read_ff(hw, addr, unquote(low)) do
          memory_cycle(hw, fn hw -> {Ppu.scroll_x(hw.ppu), hw} end)
        end
      0x44 ->
        defp _read_ff(hw, addr, unquote(low)) do
          memory_cycle(hw, fn hw -> {Ppu.line_y(hw.ppu), hw} end)
        end
      0x45 ->
        defp _read_ff(hw, addr, unquote(low)) do
          raise "Read from ppu compare line at #{Utils.to_hex(addr)} is unimplemented"
        end
      0x46 ->
        defp _read_ff(hw, addr, unquote(low)) do
          raise "Read from oam data transfer at #{Utils.to_hex(addr)} is unimplemented"
        end
      0x47 ->
        defp _read_ff(hw, addr, unquote(low)) do
          memory_cycle(hw, fn hw -> {Ppu.bg_palette(hw.ppu), hw} end)
        end
      0x48 ->
        defp _read_ff(hw, addr, unquote(low)) do
          raise "Read from ppu obj palette0 at #{Utils.to_hex(addr)} is unimplemented"
        end
      0x49 ->
        defp _read_ff(hw, addr, unquote(low)) do
          raise "Read from ppu obj palette1 at #{Utils.to_hex(addr)} is unimplemented"
        end
      0x4a ->
        defp _read_ff(hw, addr, unquote(low)) do
          raise "Read from ppu window y at #{Utils.to_hex(addr)} is unimplemented"
        end
      0x4b ->
        defp _read_ff(hw, addr, unquote(low)) do
          raise "Read from ppu window x at #{Utils.to_hex(addr)} is unimplemented"
        end
      0xff ->
        defp _read_ff(hw, addr, unquote(low)) do
          memory_cycle(hw, fn hw -> {Interrupts.interrupt_enable(hw.intr), hw} end)
        end
      x when 0x80 <= x and x <= 0xfe ->
        defp _read_ff(hw, addr, unquote(low)) do
          memory_cycle(hw, fn hw -> {Hram.read(hw.hram, addr), hw} end)
        end
      x when 0x10 <= x and x <= 0x26 ->
        defp _read_ff(hw, addr, unquote(low)) do
          memory_cycle(hw, fn hw -> {Apu.read(hw.apu, addr), hw} end)
        end
      x when 0x30 <= x and x <= 0x3f ->
        defp _read_ff(hw, addr, unquote(low)) do
          memory_cycle(hw, fn hw -> {Apu.read(hw.apu, addr), hw} end)
        end
      _ ->
        defp _read_ff(hw, addr, unquote(low)) do
          raise "Read from #{Utils.to_hex(addr)} is unimplemented"
        end
    end
  end

  def read_ff(hw, addr) do
    low = addr &&& 0xff
    _read_ff(hw, addr, low)
  end


  defp _write(hw, addr, value, 0x00) when hw.bootrom.active do
    memory_cycle(hw, fn hw -> Map.put(hw, :bootrom, Bootrom.write(hw.bootrom, addr, value)) end)
  end

  for high <- 0..0xff do
    cond do
      high <= 0x7f ->
        defp _write(hw, addr, value, unquote(high)) do
          memory_cycle(hw, fn hw -> Map.put(hw, :cart, Cartridge.set_bank_control(hw.cart, addr, value)) end)
        end
      high <= 0x9f ->
        defp _write(hw, addr, value, unquote(high)) do
          memory_cycle(hw, fn hw -> Map.put(hw, :ppu, Ppu.write_vram(hw.ppu, addr, value)) end)
        end
      high <= 0xbf ->
        defp _write(hw, addr, value, unquote(high)) do
          raise "Write to ram at #{Utils.to_hex(addr)} is unimplemented"
        end
      high <= 0xcf ->
        defp _write(hw, addr, value, unquote(high)) do
          memory_cycle(hw, fn hw -> Map.put(hw, :wram, Wram.write_low(hw.wram, addr, value)) end)
        end
      high <= 0xdf ->
        defp _write(hw, addr, value, unquote(high)) do
          memory_cycle(hw, fn hw -> Map.put(hw, :wram, Wram.write_high(hw.wram, addr, value)) end)
        end
      high <= 0xef ->
        defp _write(hw, addr, value, unquote(high)) do
          memory_cycle(hw, fn hw -> Map.put(hw, :wram, Wram.write_low(hw.wram, addr, value)) end)
        end
      high <= 0xfd ->
        defp _write(hw, addr, value, unquote(high)) do
          memory_cycle(hw, fn hw -> Map.put(hw, :wram, Wram.write_high(hw.wram, addr, value)) end)
        end
      high == 0xfe ->
        defp _write(hw, addr, value, unquote(high)) do
          low = addr &&& 0xff
          if low <= 0x9f do
            # oam
            raise "Write to oam at #{Utils.to_hex(addr)} is unimplemented"
          else
            # unusable memory
            raise "Write to unusable memory at #{Utils.to_hex(addr)}"
          end
        end
      true -> #0xff
        defp _write(hw, addr, value, unquote(high)) do
          write_ff(hw, addr, value)
        end
    end
  end

  def write(hw, addr, value) do
    high_addr = elem(@high_addr, addr)
    # high_addr = (addr >>> 8) &&& 0xff
    _write(hw, addr, value, high_addr)
  end

  def write_ff(hw, addr, value) do
    case addr &&& 0xff do
      0x00 -> 
        raise "Write to joypad at #{Utils.to_hex(addr)} is unimplemented"
      0x01 ->
        raise "Write to serial data at #{Utils.to_hex(addr)} is unimplemented"
      0x02 ->
        raise "Write to serial control at #{Utils.to_hex(addr)} is unimplemented"
      0x04 ->
        raise "Write to div register at #{Utils.to_hex(addr)} is unimplemented"
      0x05 ->
        raise "Write to tima register at #{Utils.to_hex(addr)} is unimplemented"
      0x06 ->
        raise "Write to tma register at #{Utils.to_hex(addr)} is unimplemtened"
      0x07 ->
        raise "Write to tac register at #{Utils.to_hex(addr)} is unimplemented"
      0x0f ->
        raise "Write to interrupt flag at #{Utils.to_hex(addr)} is unimplemented"
      0x40 ->
        memory_cycle(hw, fn hw -> Map.put(hw, :ppu, Ppu.set_lcd_control(hw.ppu, value)) end)
      0x41 ->
        raise "Write to ppu lcd status at #{Utils.to_hex(addr)} is unimplemented"
      0x42 ->
        memory_cycle(hw, fn hw -> Map.put(hw, :ppu, Ppu.set_scroll_y(hw.ppu, value)) end)
      0x43 ->
        memory_cycle(hw, fn hw -> Map.put(hw, :ppu, Ppu.set_scroll_x(hw.ppu, value)) end)
      0x44 ->
        raise "Write to ppu current line at #{Utils.to_hex(addr)} is unimplemented"
      0x45 ->
        raise "Write to ppu compare line at #{Utils.to_hex(addr)} is unimplemented"
      0x46 ->
        raise "Write to oam data transfer at #{Utils.to_hex(addr)} is unimplemented"
      0x47 ->
        memory_cycle(hw, fn hw -> Map.put(hw, :ppu, Ppu.set_bg_palette(hw.ppu, value)) end)
      0x48 ->
        raise "Write to ppu obj palette0 at #{Utils.to_hex(addr)} is unimplemented"
      0x49 ->
        raise "Write to ppu obj palette1 at #{Utils.to_hex(addr)} is unimplemented"
      0x4a ->
        raise "Write to ppu window y at #{Utils.to_hex(addr)} is unimplemented"
      0x4b ->
        raise "Write to ppu window x at #{Utils.to_hex(addr)} is unimplemented"
      0x50 ->
        memory_cycle(hw, fn hw -> Map.put(hw, :bootrom, Bootrom.set_enable(hw.bootrom, value)) end)
        # raise "Write to disable bootrom at #{Utils.to_hex(addr)} is unimplemented"
      0xff ->
        raise "Write to interrupt enable at #{Utils.to_hex(addr)} is unimplemented"
      x when 0x80 <= x and x <= 0xfe ->
        memory_cycle(hw, fn hw -> Map.put(hw, :hram, Hram.write(hw.hram, addr, value)) end)
      x when 0x10 <= x and x <= 0x26 ->
        memory_cycle(hw, fn hw -> Map.put(hw, :apu, Apu.write(hw.apu, addr, value)) end)
      x when 0x30 <= x and x <= 0x3f ->
        memory_cycle(hw, fn hw -> Map.put(hw, :apu, Apu.write(hw.apu, addr, value)) end)
      _ ->
        raise "Write to #{Utils.to_hex(addr)} is unimplemented"
    end
  end

  def memory_cycle(hw, memory_fn) do
    hw = machine_cycle(hw)
    memory_fn.(hw)
  end

  defp timer_cycle(_hw) do
    # oam
    # ppu
    # timer
  end

  def machine_cycle(%Hardware{ppu: ppu} = hw) do
    # oam
    # ppu
    ppu = Ppu.cycle(ppu)
    # timer
    %{hw | ppu: ppu, counter: hw.counter + 4}
  end

end
