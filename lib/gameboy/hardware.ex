defmodule Gameboy.Hardware do
  use Bitwise
  alias Gameboy.Hardware
  alias Gameboy.Memory
  alias Gameboy.Bootrom
  alias Gameboy.Cartridge
  alias Gameboy.SimplePpu, as: Ppu
  alias Gameboy.Wram
  alias Gameboy.Hram
  alias Gameboy.Apu
  alias Gameboy.Timer
  alias Gameboy.Interrupts
  alias Gameboy.Serial
  alias Gameboy.Dma
  alias Gameboy.Joypad
  alias Gameboy.Utils

  defstruct bootrom: nil,
            cart: struct(Cartridge),
            ppu: struct(Ppu),
            wram: struct(Wram),
            hram: struct(Hram),
            apu: struct(Apu),
            timer: struct(Timer),
            intr: nil,
            dma: nil,
            serial: struct(Serial),
            joypad: struct(Joypad),
            counter: 0

  @high_addr 0..0xffff |> Enum.map(fn x -> (x >>> 8) &&& 0xff end) |> List.to_tuple()
  @low_addr 0..0xffff |> Enum.map(fn x -> x &&& 0xff end) |> List.to_tuple()

  def synced_read_high(hw, addr), do: synced_read(hw, 0xff00 ||| addr)
  def synced_write_high(hw, addr, data), do: synced_write(hw, 0xff00 ||| addr, data)
  def sync_cycle(hw) do
    Hardware.cycle(hw)
  end

  def init(opts \\ []) do
    bootrom = case Access.fetch(opts, :bootrom) do
      {:ok, path} ->
        Bootrom.init(path)
      _ ->
        Bootrom.init()
    end
    cart = case Access.fetch(opts, :cart) do
      {:ok, path} ->
        Cartridge.init(path)
      _ ->
        Cartridge.init()
    end
    ppu = Ppu.init()
    wram = Wram.init()
    hram = Hram.init()
    apu = Apu.init()
    timer = Timer.init()
    intr = Interrupts.init()
    dma = Dma.init()
    %Hardware{
      bootrom: bootrom,
      cart: cart,
      ppu: ppu,
      wram: wram,
      hram: hram,
      apu: apu,
      timer: timer,
      intr: intr,
      dma: dma
    }
  end

  defp _read(%Hardware{bootrom: {_, true} = bootrom} = hw, addr, 0x00) do
    memory_cycle(hw, fn hw -> {Bootrom.read(bootrom, addr), hw} end)
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
          memory_cycle(hw, fn hw -> {Cartridge.read_ram(hw.cart, addr), hw} end)
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
            memory_cycle(hw, fn hw -> {Ppu.read_oam(hw.ppu, low), hw} end)
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

  def synced_read(hw, addr) do
    high_addr = elem(@high_addr, addr)
    # high_addr = (addr >>> 8) &&& 0xff
    _read(hw, addr, high_addr)
  end

  for low <- 0..0xff do
    case low do
      0x00 -> 
        defp _read_ff(hw, addr, unquote(low)) do
          memory_cycle(hw, fn hw -> {Joypad.get(hw.joypad), hw} end)
        end
      0x01 ->
        defp _read_ff(_hw, addr, unquote(low)) do
          raise "Read from serial data at #{Utils.to_hex(addr)} is unimplemented"
        end
      0x02 ->
        defp _read_ff(_hw, addr, unquote(low)) do
          raise "Read from serial control at #{Utils.to_hex(addr)} is unimplemented"
        end
      0x04 ->
        defp _read_ff(hw, _addr, unquote(low)) do
          timer_read_cycle(hw, fn timer -> Timer.div_cycle(timer) end)
        end
      0x05 ->
        defp _read_ff(hw, _addr, unquote(low)) do
          timer_read_cycle(hw, fn timer -> Timer.tima_cycle(timer) end)
        end
      0x06 ->
        defp _read_ff(hw, _addr, unquote(low)) do
          timer_read_cycle(hw, fn timer -> Timer.tma_cycle(timer) end)
        end
      0x07 ->
        defp _read_ff(hw, _addr, unquote(low)) do
          timer_read_cycle(hw, fn timer -> Timer.tac_cycle(timer) end)
        end
      0x0f ->
        defp _read_ff(hw, _addr, unquote(low)) do
          memory_cycle(hw, fn hw -> {Interrupts.interrupt_flag(hw.intr), hw} end)
        end
      0x40 ->
        defp _read_ff(hw, _addr, unquote(low)) do
          memory_cycle(hw, fn hw -> {Ppu.lcd_control(hw.ppu), hw} end)
        end
      0x41 ->
        defp _read_ff(hw, _addr, unquote(low)) do
          memory_cycle(hw, fn hw -> {Ppu.lcd_status(hw.ppu), hw} end)
        end
      0x42 ->
        defp _read_ff(hw, _addr, unquote(low)) do
          memory_cycle(hw, fn hw -> {Ppu.scroll_y(hw.ppu), hw} end)
        end
      0x43 ->
        defp _read_ff(hw, _addr, unquote(low)) do
          memory_cycle(hw, fn hw -> {Ppu.scroll_x(hw.ppu), hw} end)
        end
      0x44 ->
        defp _read_ff(hw, _addr, unquote(low)) do
          memory_cycle(hw, fn hw -> {Ppu.line_y(hw.ppu), hw} end)
        end
      0x45 ->
        defp _read_ff(hw, _addr, unquote(low)) do
          memory_cycle(hw, fn hw -> {Ppu.line_y_compare(hw.ppu), hw} end)
        end
      0x46 ->
        defp _read_ff(_hw, addr, unquote(low)) do
          raise "Read from oam data transfer at #{Utils.to_hex(addr)} is unimplemented"
        end
      0x47 ->
        defp _read_ff(hw, _addr, unquote(low)) do
          memory_cycle(hw, fn hw -> {Ppu.bg_palette(hw.ppu), hw} end)
        end
      0x48 ->
        defp _read_ff(hw, _addr, unquote(low)) do
          memory_cycle(hw, fn hw -> {Ppu.ob_palette0(hw.ppu), hw} end)
        end
      0x49 ->
        defp _read_ff(hw, _addr, unquote(low)) do
          memory_cycle(hw, fn hw -> {Ppu.ob_palette1(hw.ppu), hw} end)
        end
      0x4a ->
        defp _read_ff(hw, _addr, unquote(low)) do
          memory_cycle(hw, fn hw -> {Ppu.window_y(hw.ppu), hw} end)
        end
      0x4b ->
        defp _read_ff(hw, _addr, unquote(low)) do
          memory_cycle(hw, fn hw -> {Ppu.window_x(hw.ppu), hw} end)
        end
      0xff ->
        defp _read_ff(hw, _addr, unquote(low)) do
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
          IO.warn("Read from #{Utils.to_hex(addr)} is not supported")
          {0xff, cycle(hw)}
        end
    end
  end

  def read_ff(hw, addr) do
    # low = addr &&& 0xff
    low = elem(@low_addr, addr)
    _read_ff(hw, addr, low)
  end


  # defp _write(hw, addr, value, 0x00) when hw.bootrom.active do
  #   memory_cycle(hw, fn hw -> Map.put(hw, :bootrom, Bootrom.write(hw.bootrom, addr, value)) end)
  # end

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
          memory_cycle(hw, fn hw -> Map.put(hw, :cart, Cartridge.write_ram(hw.cart, addr, value)) end)
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
            memory_cycle(hw, fn hw -> Map.put(hw, :ppu, Ppu.write_oam(hw.ppu, low, value)) end)
          else
            # Ignore write to unsuable address and issue warning
            # Maybe implement oam corruption bug?
            IO.warn("Write to unsuable address #{Utils.to_hex(addr)}")
            cycle(hw)
          end
        end
      true -> #0xff
        defp _write(hw, addr, value, unquote(high)) do
          # IO.puts("addr = #{Utils.to_hex(addr)}")
          write_ff(hw, addr, value)
        end
    end
  end

  def synced_write(hw, addr, value) do
    high_addr = elem(@high_addr, addr)
    # high_addr = (addr >>> 8) &&& 0xff
    # IO.puts("write: addr = #{Utils.to_hex(addr)}")
    _write(hw, addr, value, high_addr)
  end

  def write_ff(hw, addr, value) do
    # IO.puts("write_ff: addr = #{Utils.to_hex(addr)}")
    case addr &&& 0xff do
      0x00 -> 
        memory_cycle(hw, fn hw -> Map.put(hw, :joypad, Joypad.set(hw.joypad, value)) end)
      0x01 ->
        # IO.puts("addr = #{Utils.to_hex(addr)}, value = #{Utils.to_hex(value)}")
        memory_cycle(hw, fn hw -> Map.put(hw, :serial, Serial.set_serial_data(hw.serial, value)) end)
      0x02 ->
        memory_cycle(hw, fn hw -> Map.put(hw, :serial, Serial.set_serial_control(hw.serial, value)) end)
      0x04 ->
        timer_write_cycle(hw, fn timer -> Timer.set_div_cycle(timer) end)
      0x05 ->
        timer_write_cycle(hw, fn timer -> Timer.set_tima_cycle(timer, value) end)
      0x06 ->
        timer_write_cycle(hw, fn timer -> Timer.set_tma_cycle(timer, value) end)
      0x07 ->
        timer_write_cycle(hw, fn timer -> Timer.set_tac_cycle(timer, value) end)
      0x0f ->
        memory_cycle(hw, fn hw ->
          Map.put(hw, :intr, Interrupts.set_interrupt_flag(hw.intr, value))
        end)
      0x40 ->
        memory_cycle(hw, fn hw -> Map.put(hw, :ppu, Ppu.set_lcd_control(hw.ppu, value)) end)
      0x41 ->
        memory_cycle(hw, fn hw -> Map.put(hw, :ppu, Ppu.set_lcd_status(hw.ppu, value)) end)
      0x42 ->
        memory_cycle(hw, fn hw -> Map.put(hw, :ppu, Ppu.set_scroll_y(hw.ppu, value)) end)
      0x43 ->
        memory_cycle(hw, fn hw -> Map.put(hw, :ppu, Ppu.set_scroll_x(hw.ppu, value)) end)
      0x44 ->
        memory_cycle(hw, fn hw -> Map.put(hw, :ppu, Ppu.set_line_y(hw.ppu, value)) end)
      0x45 ->
        memory_cycle(hw, fn hw -> Map.put(hw, :ppu, Ppu.set_line_y_compare(hw.ppu, value)) end)
      0x46 ->
        memory_cycle(hw, fn hw -> Map.put(hw, :dma, Dma.request(hw.dma, value)) end)
      0x47 ->
        memory_cycle(hw, fn hw -> Map.put(hw, :ppu, Ppu.set_bg_palette(hw.ppu, value)) end)
      0x48 ->
        memory_cycle(hw, fn hw -> Map.put(hw, :ppu, Ppu.set_ob_palette0(hw.ppu, value)) end)
      0x49 ->
        memory_cycle(hw, fn hw -> Map.put(hw, :ppu, Ppu.set_ob_palette1(hw.ppu, value)) end)
      0x4a ->
        memory_cycle(hw, fn hw -> Map.put(hw, :ppu, Ppu.set_window_y(hw.ppu, value)) end)
      0x4b ->
        memory_cycle(hw, fn hw -> Map.put(hw, :ppu, Ppu.set_window_x(hw.ppu, value)) end)
      0x50 ->
        memory_cycle(hw, fn hw -> Map.put(hw, :bootrom, Bootrom.set_enable(hw.bootrom, value)) end)
        # raise "Write to disable bootrom at #{Utils.to_hex(addr)} is unimplemented"
      0xff ->
        memory_cycle(hw, fn hw ->
          Map.put(hw, :intr, Interrupts.set_interrupt_enable(hw.intr, value))
        end)
      x when 0x80 <= x and x <= 0xfe ->
        memory_cycle(hw, fn hw -> Map.put(hw, :hram, Hram.write(hw.hram, addr, value)) end)
      x when 0x10 <= x and x <= 0x26 ->
        memory_cycle(hw, fn hw -> Map.put(hw, :apu, Apu.write(hw.apu, addr, value)) end)
      x when 0x30 <= x and x <= 0x3f ->
        memory_cycle(hw, fn hw -> Map.put(hw, :apu, Apu.write(hw.apu, addr, value)) end)
      _ ->
        IO.warn("Write to #{Utils.to_hex(addr)} is not supported")
        cycle(hw)
    end
  end

  for high <- 0..0xdf do
    cond do
      high <= 0x3f ->
        defp dma_read(hw, addr, unquote(high)) do
          Cartridge.read_binary_rom_low(hw.cart, addr, 0xa0)
        end
      high <= 0x7f ->
        defp dma_read(hw, addr, unquote(high)) do
          Cartridge.read_binary_rom_high(hw.cart, addr, 0xa0)
        end
      high <= 0x9f ->
        defp dma_read(hw, addr, unquote(high)) do
          Ppu.read_binary_vram(hw.ppu, addr, 0xa0)
        end
      high <= 0xbf ->
        defp dma_read(_hw, addr, unquote(high)) do
          raise "dma read from ram at #{Utils.to_hex(addr)} is unimplemented"
        end
      high <= 0xcf ->
        defp dma_read(hw, addr, unquote(high)) do
          Wram.read_binary_low(hw.wram, addr, 0xa0)
        end
      high <= 0xdf ->
        defp dma_read(hw, addr, unquote(high)) do
          Wram.read_binary_high(hw.wram, addr, 0xa0)
        end
    end
  end

  defp dma_read(_hw, addr, _high) do
    raise "dma read from #{Utils.to_hex(addr)} is not supported"
  end

  def memory_cycle(hw, memory_fn) do
    hw = cycle(hw)
    memory_fn.(hw)
  end

  defp timer_read_cycle(hw, timer_fn) do
    # oam
    {ppu, dma} = if hw.dma.requested do
      dma = Dma.acknowledge_request(hw.dma)
      addr = Dma.address(dma)
      data = dma_read(hw, addr, elem(@high_addr, addr))
      {Ppu.oam_dma_transfer(hw.ppu, data, 0xa0), dma}
    else
      {hw.ppu, hw.dma}
    end
    # ppu
    {ppu, ppu_req} = Ppu.cycle(ppu)
    # timer
    {value, timer, timer_req} = timer_fn.(hw.timer)
    intr = Interrupts.request(hw.intr, ppu_req ||| timer_req)
    {value, %{hw | ppu: ppu, timer: timer, dma: dma, intr: intr, counter: hw.counter + 4}}
  end

  defp timer_write_cycle(hw, timer_fn) do
    # oam
    {ppu, dma} = if hw.dma.requested do
      dma = Dma.acknowledge_request(hw.dma)
      addr = Dma.address(dma)
      data = dma_read(hw, addr, elem(@high_addr, addr))
      {Ppu.oam_dma_transfer(hw.ppu, data, 0xa0), dma}
    else
      {hw.ppu, hw.dma}
    end
    # ppu
    {ppu, ppu_req} = Ppu.cycle(ppu)
    # timer
    {timer, timer_req} = timer_fn.(hw.timer)
    intr = Interrupts.request(hw.intr, ppu_req ||| timer_req)
    %{hw | ppu: ppu, timer: timer, dma: dma, intr: intr, counter: hw.counter + 4}
  end

  # DMA is requested
  def cycle(%{dma: %{requested: true} = dma, ppu: ppu, timer: timer, intr: intr, counter: counter} = hw) do
    # oam
    dma = Dma.acknowledge_request(dma)
    addr = Dma.address(dma)
    data = dma_read(hw, addr, elem(@high_addr, addr))
    ppu = Ppu.oam_dma_transfer(ppu, data, 0xa0)
    # ppu
    {ppu, ppu_req} = Ppu.cycle(ppu)
    # timer
    {timer, timer_req} = Timer.cycle(timer)
    intr = Interrupts.request(intr, ppu_req ||| timer_req)
    %{hw | ppu: ppu, timer: timer, dma: dma, intr: intr, counter: counter + 4}
  end
  # No DMA
  def cycle(%{ppu: ppu, timer: timer, intr: intr, counter: counter} = hw) do
    # ppu
    {ppu, ppu_req} = Ppu.cycle(ppu)
    # timer
    {timer, timer_req} = Timer.cycle(timer)
    intr = Interrupts.request(intr, ppu_req ||| timer_req)
    %{hw | ppu: ppu, timer: timer, intr: intr, counter: counter + 4}
  end
end
