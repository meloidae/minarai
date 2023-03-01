defmodule Gameboy.Hardware do
  import Bitwise
  alias Gameboy.Hardware
  alias Gameboy.Bootrom
  alias Gameboy.Cartridge
  # alias Gameboy.SimplePpu, as: Ppu
  alias Gameboy.RecordPpu, as: Ppu
  alias Gameboy.Wram
  alias Gameboy.Hram
  alias Gameboy.Apu
  alias Gameboy.Timer
  alias Gameboy.Interrupts
  alias Gameboy.Serial
  alias Gameboy.Dma
  alias Gameboy.Joypad
  alias Gameboy.Utils

  require Record

  Record.defrecordp(:hardware, 
                    bootrom: nil,
                    cart: nil,
                    ppu: nil, 
                    wram: nil,
                    hram: nil,
                    apu: nil,
                    timer: nil,
                    intr: nil,
                    dma: nil,
                    serial: nil,
                    joypad: nil,
                    counter: 0)

  @high_addr 0..0xffff |> Enum.map(fn x -> (x >>> 8) &&& 0xff end) |> List.to_tuple()
  @low_addr 0..0xffff |> Enum.map(fn x -> x &&& 0xff end) |> List.to_tuple()
  @cycles_per_frame 17556

  def synced_read_high(hw, addr), do: synced_read(hw, 0xff00 ||| addr)
  def synced_write_high(hw, addr, data), do: synced_write(hw, 0xff00 ||| addr, data)
  def sync_cycle(hw) do
    cycle(hw)
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
    joypad = Joypad.init()

    hardware(
      bootrom: bootrom,
      cart: cart,
      ppu: ppu,
      wram: wram,
      hram: hram,
      apu: apu,
      timer: timer,
      intr: intr,
      dma: dma,
      serial: %Serial{},
      joypad: joypad
    )
  end

  def keydown(hardware(joypad: joypad, intr: intr) = hw, key_name) do
    {joypad, req} = Joypad.keydown(joypad, key_name)
    intr = Interrupts.request(intr, req)
    hardware(hw, joypad: joypad, intr: intr)
  end

  def keyup(hardware(joypad: joypad) = hw, key_name) do
    hardware(hw, joypad: Joypad.keyup(joypad, key_name))
  end

  def check_interrupt(hardware(intr: intr) = _hw) do
    Interrupts.check(intr)
  end

  def acknowledge_interrupt(hardware(intr: intr) = hw, intr_mask) do
    intr = Interrupts.acknowledge(intr, intr_mask)
    hardware(hw, intr: intr)
  end

  def get_counter(hardware(counter: counter) = _hw), do: counter
  def set_counter(hw, counter) do
    hardware(hw, counter: counter)
  end

  def get_cart(hardware(cart: cart) = _hw), do: cart
  def get_bootrom(hardware(bootrom: bootrom) = _hw), do: bootrom

  defp _read(hardware(bootrom: true = bootrom) = hw, addr, 0x00) do
    hw = cycle(hw)
    {Bootrom.read(bootrom, addr), hw}
  end
  for high <- 0..0xff do
    cond do
      high <= 0x3f ->
        defp _read(hw, addr, unquote(high)) do
          hw = cycle(hw)
          {Cartridge.read_rom_low(hardware(hw, :cart), addr), hw}
        end
      high <= 0x7f ->
        defp _read(hw, addr, unquote(high)) do
          hw = cycle(hw)
          {Cartridge.read_rom_high(hardware(hw, :cart), addr), hw}
        end
      high <= 0x9f ->
        defp _read(hw, addr, unquote(high)) do
          hw = cycle(hw)
          {Ppu.read_vram(hardware(hw, :ppu), addr), hw}
        end
      high <= 0xbf ->
        defp _read(hw, addr, unquote(high)) do
          hw = cycle(hw)
          {Cartridge.read_ram(hardware(hw, :cart), addr), hw}
        end
      high <= 0xcf ->
        defp _read(hw, addr, unquote(high)) do
          hw = cycle(hw)
          {Wram.read_low(hardware(hw, :wram), addr), hw}
        end
      high <= 0xdf ->
        defp _read(hw, addr, unquote(high)) do
          hw = cycle(hw)
          {Wram.read_high(hardware(hw, :wram), addr), hw}
        end
      high <= 0xef ->
        defp _read(hw, addr, unquote(high)) do
          hw = cycle(hw)
          {Wram.read_low(hardware(hw, :wram), addr), hw}
        end
      high <= 0xfd ->
        defp _read(hw, addr, unquote(high)) do
          hw = cycle(hw)
          {Wram.read_high(hardware(hw, :wram), addr), hw}
        end
      high == 0xfe ->
        defp _read(hw, addr, unquote(high)) do
          low = addr &&& 0xff
          if low <= 0x9f do
            # oam
            hw = cycle(hw)
            {Ppu.read_oam(hardware(hw, :ppu), low), hw}
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
    _read(hw, addr, high_addr)
  end

  for low <- 0..0xff do
    case low do
      0x00 -> 
        defp _read_ff(hw, _addr, unquote(low)) do
          hw = cycle(hw)
          {Joypad.get(hardware(hw, :joypad)), hw}
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
          hw = cycle(hw)
          {Interrupts.interrupt_flag(hardware(hw, :intr)), hw}
        end
      0x40 ->
        defp _read_ff(hw, _addr, unquote(low)) do
          hw = cycle(hw)
          {Ppu.lcd_control(hardware(hw, :ppu)), hw}
        end
      0x41 ->
        defp _read_ff(hw, _addr, unquote(low)) do
          hw = cycle(hw)
          {Ppu.lcd_status(hardware(hw, :ppu)), hw}
        end
      0x42 ->
        defp _read_ff(hw, _addr, unquote(low)) do
          hw = cycle(hw)
          {Ppu.scroll_y(hardware(hw, :ppu)), hw}
        end
      0x43 ->
        defp _read_ff(hw, _addr, unquote(low)) do
          hw = cycle(hw)
          {Ppu.scroll_x(hardware(hw, :ppu)), hw}
        end
      0x44 ->
        defp _read_ff(hw, _addr, unquote(low)) do
          hw = cycle(hw)
          {Ppu.line_y(hardware(hw, :ppu)), hw}
        end
      0x45 ->
        defp _read_ff(hw, _addr, unquote(low)) do
          hw = cycle(hw)
          {Ppu.line_y_compare(hardware(hw, :ppu)), hw}
        end
      0x46 ->
        defp _read_ff(_hw, addr, unquote(low)) do
          raise "Read from oam data transfer at #{Utils.to_hex(addr)} is unimplemented"
        end
      0x47 ->
        defp _read_ff(hw, _addr, unquote(low)) do
          hw = cycle(hw)
          {Ppu.bg_palette(hardware(hw, :ppu)), hw}
        end
      0x48 ->
        defp _read_ff(hw, _addr, unquote(low)) do
          hw = cycle(hw)
          {Ppu.ob_palette0(hardware(hw, :ppu)), hw}
        end
      0x49 ->
        defp _read_ff(hw, _addr, unquote(low)) do
          hw = cycle(hw)
          {Ppu.ob_palette1(hardware(hw, :ppu)), hw}
        end
      0x4a ->
        defp _read_ff(hw, _addr, unquote(low)) do
          hw = cycle(hw)
          {Ppu.window_y(hardware(hw, :ppu)), hw}
        end
      0x4b ->
        defp _read_ff(hw, _addr, unquote(low)) do
          hw = cycle(hw)
          {Ppu.window_x(hardware(hw, :ppu)), hw}
        end
      0xff ->
        defp _read_ff(hw, _addr, unquote(low)) do
          hw = cycle(hw)
          {Interrupts.interrupt_enable(hardware(hw, :intr)), hw}
        end
      x when 0x80 <= x and x <= 0xfe ->
        defp _read_ff(hw, addr, unquote(low)) do
          hw = cycle(hw)
          {Hram.read(hardware(hw, :hram), addr), hw}
        end
      x when 0x10 <= x and x <= 0x26 ->
        defp _read_ff(hw, addr, unquote(low)) do
          hw = cycle(hw)
          {Apu.read(hardware(hw, :apu), addr), hw}
        end
      x when 0x30 <= x and x <= 0x3f ->
        defp _read_ff(hw, addr, unquote(low)) do
          hw = cycle(hw)
          {Apu.read(hardware(hw, :apu), addr), hw}
        end
      _ ->
        defp _read_ff(hw, addr, unquote(low)) do
          IO.warn("Read from #{Utils.to_hex(addr)} is not supported")
          {0xff, cycle(hw)}
        end
    end
  end

  defp read_ff(hw, addr) do
    # low = addr &&& 0xff
    low = elem(@low_addr, addr)
    _read_ff(hw, addr, low)
  end

  for high <- 0..0xff do
    cond do
      high <= 0x7f ->
        defp _write(hw, addr, value, unquote(high)) do
          hw = cycle(hw)
          hardware(hw, cart: Cartridge.set_bank_control(hardware(hw, :cart), addr, value))
        end
      high <= 0x9f ->
        defp _write(hw, addr, value, unquote(high)) do
          hw = cycle(hw)
          Ppu.write_vram(hardware(hw, :ppu), addr, value)
          hw
        end
      high <= 0xbf ->
        defp _write(hw, addr, value, unquote(high)) do
          hw = cycle(hw)
          hardware(hw, cart: Cartridge.write_ram(hardware(hw, :cart), addr, value))
        end
      high <= 0xcf ->
        defp _write(hw, addr, value, unquote(high)) do
          hw = cycle(hw)
          Wram.write_low(hardware(hw, :wram), addr, value)
          hw
        end
      high <= 0xdf ->
        defp _write(hw, addr, value, unquote(high)) do
          hw = cycle(hw)
          Wram.write_high(hardware(hw, :wram), addr, value)
          hw
        end
      high <= 0xef ->
        defp _write(hw, addr, value, unquote(high)) do
          hw = cycle(hw)
          Wram.write_low(hardware(hw, :wram), addr, value)
          hw
        end
      high <= 0xfd ->
        defp _write(hw, addr, value, unquote(high)) do
          hw = cycle(hw)
          Wram.write_high(hardware(hw, :wram), addr, value)
          hw
        end
      high == 0xfe ->
        defp _write(hw, addr, value, unquote(high)) do
          low = addr &&& 0xff
          if low <= 0x9f do
            # oam
            hw = cycle(hw)
            hardware(hw, ppu: Ppu.write_oam(hardware(hw, :ppu), low, value))
          else
            # Ignore write to unsuable address and issue warning
            # Maybe implement oam corruption bug?
            IO.warn("Write to unusable address #{Utils.to_hex(addr)}")
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

  defp write_ff(hw, addr, value) do
    case addr &&& 0xff do
      0x00 -> 
        memory_cycle(hw, fn hw -> hardware(hw, joypad: Joypad.set(hardware(hw, :joypad), value)) end)
      0x01 ->
        # IO.puts("addr = #{Utils.to_hex(addr)}, value = #{Utils.to_hex(value)}")
        memory_cycle(hw, fn hw -> hardware(hw, serial: Serial.set_serial_data(hardware(hw, :serial), value)) end)
      0x02 ->
        memory_cycle(hw, fn hw -> hardware(hw, serial: Serial.set_serial_control(hardware(hw, :serial), value)) end)
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
          hardware(hw, intr: Interrupts.set_interrupt_flag(hardware(hw, :intr), value))
        end)
      0x40 ->
        memory_cycle(hw, fn hw -> hardware(hw, ppu: Ppu.set_lcd_control(hardware(hw, :ppu), value)) end)
      0x41 ->
        memory_cycle(hw, fn hw -> hardware(hw, ppu: Ppu.set_lcd_status(hardware(hw, :ppu), value)) end)
      0x42 ->
        memory_cycle(hw, fn hw -> hardware(hw, ppu: Ppu.set_scroll_y(hardware(hw, :ppu), value)) end)
      0x43 ->
        memory_cycle(hw, fn hw -> hardware(hw, ppu: Ppu.set_scroll_x(hardware(hw, :ppu), value)) end)
      0x44 ->
        memory_cycle(hw, fn hw -> hardware(hw, ppu: Ppu.set_line_y(hardware(hw, :ppu), value)) end)
      0x45 ->
        memory_cycle(hw, fn hw -> hardware(hw, ppu: Ppu.set_line_y_compare(hardware(hw, :ppu), value)) end)
      0x46 ->
        memory_cycle(hw, fn hw -> hardware(hw, dma: Dma.request(hardware(hw, :dma), value)) end)
      0x47 ->
        memory_cycle(hw, fn hw -> hardware(hw, ppu: Ppu.set_bg_palette(hardware(hw, :ppu), value)) end)
      0x48 ->
        memory_cycle(hw, fn hw -> hardware(hw, ppu: Ppu.set_ob_palette0(hardware(hw, :ppu), value)) end)
      0x49 ->
        memory_cycle(hw, fn hw -> hardware(hw, ppu: Ppu.set_ob_palette1(hardware(hw, :ppu), value)) end)
      0x4a ->
        memory_cycle(hw, fn hw -> hardware(hw, ppu: Ppu.set_window_y(hardware(hw, :ppu), value)) end)
      0x4b ->
        memory_cycle(hw, fn hw -> hardware(hw, ppu: Ppu.set_window_x(hardware(hw, :ppu), value)) end)
      0x50 ->
        memory_cycle(hw, fn hw -> hardware(hw, bootrom: Bootrom.set_enable(hardware(hw, :bootrom), value)) end)
      0xff ->
        memory_cycle(hw, fn hw ->
          hardware(hw, intr: Interrupts.set_interrupt_enable(hardware(hw, :intr), value))
        end)
      x when 0x80 <= x and x <= 0xfe ->
        # memory_cycle(hw, fn hw -> Map.put(hw, :hram, Hram.write(hw.hram, addr, value)) end)
        hw = cycle(hw)
        Hram.write(hardware(hw, :hram), addr, value)
        hw
      x when 0x10 <= x and x <= 0x26 ->
        # memory_cycle(hw, fn hw -> hardware(hw, apu: Apu.write(hardware(hw, :apu), addr, value)) end)
        hw = cycle(hw)
        Apu.write(hardware(hw, :apu), addr, value)
        hw
      x when 0x30 <= x and x <= 0x3f ->
        # memory_cycle(hw, fn hw -> hardware(hw, apu: Apu.write(hardware(hw, :apu), addr, value)) end)
        hw = cycle(hw)
        Apu.write(hardware(hw, :apu), addr, value)
        hw
      _ ->
        IO.warn("Write to #{Utils.to_hex(addr)} is not supported")
        cycle(hw)
    end
  end

  for high <- 0..0xdf do
    cond do
      high <= 0x3f ->
        defp dma_read(hw, addr, unquote(high)) do
          Cartridge.read_binary_rom_low(hardware(hw, :cart), addr, 0xa0)
        end
      high <= 0x7f ->
        defp dma_read(hw, addr, unquote(high)) do
          Cartridge.read_binary_rom_high(hardware(hw, :cart), addr, 0xa0)
        end
      high <= 0x9f ->
        defp dma_read(hw, addr, unquote(high)) do
          Ppu.read_binary_vram(hardware(hw, :ppu), addr, 0xa0)
        end
      high <= 0xbf ->
        defp dma_read(_hw, addr, unquote(high)) do
          raise "dma read from ram at #{Utils.to_hex(addr)} is unimplemented"
        end
      high <= 0xcf ->
        defp dma_read(hw, addr, unquote(high)) do
          Wram.read_binary_low(hardware(hw, :wram), addr, 0xa0)
        end
      high <= 0xdf ->
        defp dma_read(hw, addr, unquote(high)) do
          Wram.read_binary_high(hardware(hw, :wram), addr, 0xa0)
        end
    end
  end

  defp dma_read(_hw, addr, _high) do
    raise "dma read from #{Utils.to_hex(addr)} is not supported"
  end

  defp timestamp() do
    counter = Process.get(:stats_counter)
    if counter != nil do
      if rem(counter, @cycles_per_frame) == 0 do
        Utils.store_timestamp()
      end
      Process.put(:stats_counter, counter + 1)
    end
  end

  defp memory_cycle(hw, memory_fn) do
    hw = cycle(hw)
    memory_fn.(hw)
  end

  # DMA is requested
  defp timer_read_cycle(hardware(dma: %{requested: true} = dma, ppu: ppu, timer: timer, intr: intr, counter: counter) = hw, timer_fn) do
    timestamp()
    # oam
    dma = Dma.acknowledge_request(dma)
    addr = Dma.address(dma)
    data = dma_read(hw, addr, elem(@high_addr, addr))
    ppu = Ppu.oam_dma_transfer(ppu, data, 0xa0)
    # ppu
    {ppu, ppu_req} = Ppu.cycle(ppu)
    # timer
    {value, timer, timer_req} = timer_fn.(timer)
    req = ppu_req ||| timer_req
    if req != 0 do
      intr = Interrupts.request(intr, req)
      {value, hardware(hw, ppu: ppu, timer: timer, dma: dma, intr: intr, counter: counter + 1)}
    else
      {value, hardware(hw, ppu: ppu, timer: timer, dma: dma, counter: counter + 1)}
    end
  end
  # No DMA
  defp timer_read_cycle(hardware(dma: _, ppu: ppu, timer: timer, intr: intr, counter: counter) = hw, timer_fn) do
    timestamp()
    # ppu
    {ppu, ppu_req} = Ppu.cycle(ppu)
    # timer
    {value, timer, timer_req} = timer_fn.(timer)
    req = ppu_req ||| timer_req
    if req != 0 do
      intr = Interrupts.request(intr, req)
      {value, hardware(hw, ppu: ppu, timer: timer, intr: intr, counter: counter + 1)}
    else
      {value, hardware(hw, ppu: ppu, timer: timer, counter: counter + 1)}
    end
  end

  # DMA is requested
  defp timer_write_cycle(hardware(dma: %{requested: true} = dma, ppu: ppu, timer: timer, intr: intr, counter: counter) = hw, timer_fn) do
    timestamp()
    # oam
    dma = Dma.acknowledge_request(dma)
    addr = Dma.address(dma)
    data = dma_read(hw, addr, elem(@high_addr, addr))
    ppu = Ppu.oam_dma_transfer(ppu, data, 0xa0)
    # ppu
    {ppu, ppu_req} = Ppu.cycle(ppu)
    # timer
    {timer, timer_req} = timer_fn.(timer)
    req = ppu_req ||| timer_req
    if req !== 0 do
      intr = Interrupts.request(intr, req)
      hardware(hw, ppu: ppu, timer: timer, dma: dma, intr: intr, counter: counter + 1)
    else
      hardware(hw, ppu: ppu, timer: timer, dma: dma, counter: counter + 1)
    end
  end
  # No DMA
  defp timer_write_cycle(hardware(dma: _, ppu: ppu, timer: timer, intr: intr, counter: counter) = hw, timer_fn) do
    timestamp()
    # ppu
    {ppu, ppu_req} = Ppu.cycle(ppu)
    # timer
    {timer, timer_req} = timer_fn.(timer)
    req = ppu_req ||| timer_req
    if req !== 0 do
      intr = Interrupts.request(intr, req)
      hardware(hw, ppu: ppu, timer: timer, intr: intr, counter: counter + 1)
    else
      hardware(hw, ppu: ppu, timer: timer, counter: counter + 1)
    end
  end

  # DMA is requested
  defp cycle(hardware(dma: %{requested: true} = dma, ppu: ppu, timer: timer, intr: intr, counter: counter) = hw) do
    timestamp()
    # oam
    dma = Dma.acknowledge_request(dma)
    addr = Dma.address(dma)
    data = dma_read(hw, addr, elem(@high_addr, addr))
    ppu = Ppu.oam_dma_transfer(ppu, data, 0xa0)
    # ppu
    {ppu, ppu_req} = Ppu.cycle(ppu)
    # timer
    {timer, timer_req} = Timer.cycle(timer)
    req = ppu_req ||| timer_req
    if req !== 0 do
      intr = Interrupts.request(intr, req)
      hardware(hw, ppu: ppu, timer: timer, dma: dma, intr: intr, counter: counter + 1)
    else
      hardware(hw, ppu: ppu, timer: timer, dma: dma, counter: counter + 1)
    end
  end
  # No DMA
  defp cycle(hardware(dma: _, ppu: ppu, timer: timer, intr: intr, counter: counter) = hw) do
    timestamp()
    # ppu
    {ppu, ppu_req} = Ppu.cycle(ppu)
    # timer
    {timer, timer_req} = Timer.cycle(timer)
    req = ppu_req ||| timer_req
    if req !== 0 do
      intr = Interrupts.request(intr, req)
      hardware(hw, ppu: ppu, timer: timer, intr: intr, counter: counter + 1)
    else
      hardware(hw, ppu: ppu, timer: timer, counter: counter + 1)
    end
  end

  def memory_write_cycle(hardware(dma: %{requested: true} = dma, ppu: ppu, timer: timer, intr: intr, counter: counter) = hw, addr, value, key) do
  end
end
