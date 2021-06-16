defmodule Gameboy.Hardware do
  use Bitwise
  alias Gameboy.Hardware
  alias Gameboy.Memory
  alias Gameboy.Bootrom
  alias Gameboy.PPU

  defstruct bootrom: struct(Bootrom),
            cart: struct(Memory),
            wram: struct(Memory),
            ppu: struct(PPU),
            hram: struct(Memory),
            timer: 0,
            interrupts: 0

  defimpl Gameboy.HardwareInterface, for: Hardware do
    def synced_read(hw, addr) do
      Hardware.read(hw, addr)
    end
    def synced_read_high(hw, addr), do: synced_read(hw, 0xff00 &&& addr)
    def synced_write(hw, addr, data) do
      hw
    end
    def synced_write_high(hw, addr, data), do: synced_write(hw, 0xff00 &&& addr, data)
    def sync_cycle(hw) do
      hw
    end
  end

  def init() do
    bootrom = Bootrom.init()
    ppu = PPU.init()
    %Hardware{bootrom: bootrom, ppu: ppu}
  end

  def read(%Hardware{} = hw, addr) do
    high = (addr >>> 8) &&& 0xff
    cond do
      high == 0x00 and hw.bootrom.active ->
        machine_cycle(:memory, hw, fn hw -> {Bootrom.read(hw.bootrom, addr), hw} end)
      high <= 0x3f -> 
        # cartridge rom high
        raise "Read from cartridge rom (low) at #{addr} is unimplemtend"
      high <= 0x7f ->
        # cartridge rom low
        raise "Read from cartridge rom (high) at #{addr} is unimplemtend"
      high <= 0x9f ->
        # vram
        raise "Read from vram at #{addr} is unimplemtend"
      high <= 0xbf ->
        # cartridge ram
        raise "Read from ram at #{addr} is unimplemtend"
      high <= 0xcf ->
        # low wram
        raise "Read from wram (low) at #{addr} is unimplemtend"
      high <= 0xdf ->
        # high wram
        raise "Read from wram (high) at #{addr} is unimplemtend"
      high <= 0xef ->
        # low wram (again)
        raise "Read from echo wram (low) at #{addr} is unimplemtend"
      high <= 0xfd ->
        # high ram (again)
        raise "Read from echo wram (high) at #{addr} is unimplemtend"
      high == 0xfe ->
        low = addr &&& 0xff
        if low <= 0x9f do
          # oam
          raise "Read from oam at #{addr} is unimplemtend"
        else
          # unusable memory
          raise "Read from usuable memory at #{addr}"
        end
      true -> #0xff
        # 
    end
  end

  def write(%Hardware{} = hw, addr) do
  end


  def machine_cycle(:memory, hw, memory_fn) do
    hw = machine_cycle(nil, hw, nil)
    memory_fn.(hw)
  end

  defp machine_cycle(:timer, hw) do
    # oam
    # ppu
    # timer
  end

  def machine_cycle(_, hw, _) do
    # oam
    # ppu
    # timer
    hw
  end

end
