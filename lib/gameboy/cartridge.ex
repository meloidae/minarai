defmodule Gameboy.Cartridge do
  use Bitwise
  alias Gameboy.Cartridge
  alias Gameboy.Memory
  alias Gameboy.Utils
  alias Gameboy.TupleMemory
  alias Gameboy.EtsMemory, as: RWMemory
  alias Gameboy.PtMemory

  defstruct mbc: :nombc,
            rom: nil,
            ram: nil

  # @path "roms/Upwell.gb"
  # @path "roms/flappyboy.gb"
  # @path "roms/2048.gb"
  # @path "roms/carazu.gb"
  # @path "roms/SIKAKUJOSIKBJ3J.gb"
  @path "roms/POKEMON_YELLOW.sgb"
  # @path "roms/tests/blargg/cpu_instrs/cpu_instrs.gb"
  # @path "roms/tests/blargg/instr_timing/instr_timing.gb"
  # @path "roms/tests/blargg/mem_timing/mem_timing.gb"
  # @path "roms/tests/blargg/halt_bug.gb"

  # @path "roms/tests/mooneye-gb/acceptance/jp_timing.gb"
  # @path "roms/tests/mooneye-gb/acceptance/add_sp_e_timing.gb"
  # @path "roms/tests/mooneye-gb/acceptance/bits/reg_f.gb"
  # @path "roms/tests/mooneye-gb/acceptance/if_ie_registers.gb"
  # @path "roms/tests/mooneye-gb/acceptance/timer/tima_reload.gb"
  # @path "roms/tests/mooneye-gb/acceptance/boot_regs-dmg0.gb"

  @cart_type 0x0147
  @rom_size 0x0148
  @ram_size 0x0149
  @bank_size 0x4000
  @bank_mask 0x3fff

  @rom_bank_low_mask 0x1f
  @rom_bank_high_mask 0x60
  @ram_bank_mask 0x03

  @mbc1_bank1_mask 0x1f
  @mbc1_bank2_mask 0x03
  @mbc1_mode_mask 0x01


  def init(path \\ nil) do
    path = if is_nil(path) do
      IO.puts("Using default cart path: #{@path}")
      @path
    else
      IO.puts("Using cart path: #{path}")
      path
    end

    data = File.read!(path)
    memory = %Memory{data: data}
    mbc = case Memory.read(memory, @cart_type) do
      0x00 ->
        %{type: :nombc}
      x when x in 0x01..0x03 ->
        %{type: :mbc1, mode: :simple_rom_bank, bank1: 0x01, bank2: 0x00, rom: {0x0000, 0x4000}, ram: 0x00, ram_enable: false}
      x when x in 0x0f..0x13 ->
        %{type: :mbc3, rom: 0x4000, ram: 0x00, ram_rtc_enable: false, rtc_s: 0x00, rtc_m: 0x00, rtc_h: 0x00, rtc_dl: 0x00, rtc_dh: 0x00, latch_clock: nil}
      x ->
        raise "cart_type = 0x#{Utils.to_hex(x)} is not implemented"
    end
    rom = init_rom(memory)
    ram = init_ram(mbc, memory)
    IO.puts("Cartridge mbc: #{inspect(mbc)}")
    IO.puts("ROM banks: #{div(tuple_size(rom), @bank_size)}")
    # IO.puts("ROM banks: #{div(tuple_size(:persistent_term.get(rom)), @bank_size)}")
    # IO.puts("RAM banks: #{if ram == nil, do: "nil", else: map_size(ram)}")
    %Cartridge{mbc: mbc, rom: rom, ram: ram}
  end

  def init_rom(%{data: data} = rom_memory) do
    tuple_memory = TupleMemory.init(data)
    case Memory.read(rom_memory, @rom_size) do
      x when x in 0x00..0x08 ->
        tuple_memory
      size ->
        raise "rom_size = 0x#{Utils.to_hex(size)} is not implemented"
    end
  end

  defp init_ram(mbc, rom_memory) do
    case Memory.read(rom_memory, @ram_size) do
      0x00 ->
        # mbc2 has internal ram even when rom_size is 0x00, but ignore that for now
        # %{memory: Memory.init_memory_array(0x2000, 1), is_enabled: true}
        nil
      0x01 -> # 2kb ram
        RWMemory.init_array(0x0800, 1, :cartram)
      0x02 ->
        RWMemory.init_array(@bank_size, 1, :cartram)
      0x03 ->
        RWMemory.init_array(@bank_size, 4, :cartram)
      0x04 ->
        RWMemory.init_array(@bank_size, 16, :cartram)
      0x05 ->
        RWMemory.init_array(@bank_size, 8, :cartram)
    end
  end

  def read_rom_low(%{mbc: %{type: :nombc}, rom: rom}, addr) do
    # No Mbc, so just read from specified address
    TupleMemory.read(rom, addr)
  end
  def read_rom_low(%{mbc: %{type: :mbc1, rom: {low_offset, _high_offset}}, rom: rom}, addr) do
    TupleMemory.read(rom, low_offset ||| (addr &&& @bank_mask))
  end
  def read_rom_low(%{mbc: %{type: :mbc3}, rom: rom}, addr) do
    TupleMemory.read(rom, addr)
  end

  def read_rom_high(%{mbc: %{type: :nombc}, rom: rom}, addr) do
    TupleMemory.read(rom, addr)
  end
  def read_rom_high(%{mbc: %{type: :mbc1, rom: {_low_offset, high_offset}}, rom: rom}, addr) do
    TupleMemory.read(rom, high_offset ||| (addr &&& @bank_mask))
  end
  def read_rom_high(%{mbc: %{type: :mbc3, rom: offset}, rom: rom}, addr) do
    TupleMemory.read(rom, offset ||| (addr &&& @bank_mask))
  end


  def read_binary_rom_low(%{mbc: mbc, rom: rom, ram: ram} = cart, addr, len) do
    case mbc do
      %{type: :nombc} -> # No Mbc, so just read from specified address
        TupleMemory.read_binary(rom, addr, len)
      %{type: :mbc1, rom: {low_offset, _high_offset}} ->
        TupleMemory.read_binary(rom, low_offset ||| (addr &&& @bank_mask), len)
      %{type: :mbc3} ->
        TupleMemory.read_binary(rom, addr, len)
      _ ->
        raise "Read binary rom low for mbc #{inspect(mbc)} is unimplemented"
    end
  end

  def read_binary_rom_high(%{mbc: mbc, rom: rom} = cart, addr, len) do
    case mbc do
      %{type: :nombc} -> # No Mbc, so just read from specified address
        TupleMemory.read_binary(rom, addr, len)
      %{type: :mbc1, rom: {_low_offset, high_offset}} ->
        TupleMemory.read_binary(rom, high_offset ||| (addr &&& @bank_mask), len)
      %{type: :mbc3, rom: offset} ->
        TupleMemory.read_binary(rom, offset ||| (addr &&& @bank_mask), len)
      _ ->
        raise "Read binary rom high for mbc #{inspect(mbc)} is unimplemented"
    end
  end

  def read_ram(%{mbc: %{type: :nombc}, ram: ram}, addr) do
    RWMemory.read_array(ram, 0x0, addr &&& @bank_mask)
  end
  # MBC1
  def read_ram(%{mbc: %{type: :mbc1, ram: bank}, ram: ram}, addr) do
    RWMemory.read_array(ram, bank, addr &&& @bank_mask)
  end
  # MBC3
  def read_ram(%{mbc: %{type: :mbc3, ram: 0x08, rtc_s: value}}, _addr), do: value
  def read_ram(%{mbc: %{type: :mbc3, ram: 0x09, rtc_m: value}}, _addr), do: value
  def read_ram(%{mbc: %{type: :mbc3, ram: 0x0a, rtc_h: value}}, _addr), do: value
  def read_ram(%{mbc: %{type: :mbc3, ram: 0x0b, rtc_dl: value}}, _addr), do: value
  def read_ram(%{mbc: %{type: :mbc3, ram: 0x0c, rtc_dh: value}}, _addr), do: value
  def read_ram(%{mbc: %{type: :mbc3, ram: bank}, ram: ram}, addr) do
    RWMemory.read_array(ram, bank, addr &&& @bank_mask)
  end

  def write_ram(%{mbc: %{type: :nombc}, ram: ram} = cart, addr, value) do
    # How to enable write with no mbc?
    # put_in(cart.ram.memory, Memory.write_array(ram.memory, 0x0, addr &&& @bank_mask, value))
    RWMemory.write_array(ram, 0x0, addr &&& @bank_mask, value)
    cart
  end
  # MBC1
  def write_ram(%{mbc: %{type: :mbc1, ram_enable: false}} = cart, _addr, _value), do: cart
  def write_ram(%{mbc: %{type: :mbc1, ram_enable: true, ram: bank}, ram: ram} = cart, addr, value) do
    # put_in(cart.ram.memory, Memory.write_array(ram.memory, bank, addr &&& (ram.memory[0].size - 1), value))
    RWMemory.write_array(ram, bank, addr &&& @bank_mask, value)
    cart
  end
  # MBC3
  def write_ram(%{mbc: %{type: :mbc3, ram_rtc_enable: false}} = cart, _addr, _value), do: cart
  def write_ram(%{mbc: %{type: :mbc3, ram_rtc_enable: true, ram: 0x08}} = cart, _addr, value) do
    put_in(cart.mbc.rtc_s, value)
  end
  def write_ram(%{mbc: %{type: :mbc3, ram_rtc_enable: true, ram: 0x09}} = cart, _addr, value) do
    put_in(cart.mbc.rtc_m, value)
  end
  def write_ram(%{mbc: %{type: :mbc3, ram_rtc_enable: true, ram: 0x0a}} = cart, _addr, value) do
    put_in(cart.mbc.rtc_h, value)
  end
  def write_ram(%{mbc: %{type: :mbc3, ram_rtc_enable: true, ram: 0x0b}} = cart, _addr, value) do
    put_in(cart.mbc.rtc_dl, value)
  end
  def write_ram(%{mbc: %{type: :mbc3, ram_rtc_enable: true, ram: 0x0c}} = cart, _addr, value) do
    put_in(cart.mbc.rtc_dh, value)
  end
  def write_ram(%{mbc: %{type: :mbc3, ram_rtc_enable: true, ram: bank}, ram: ram} = cart, addr, value) do
    # put_in(cart.ram.memory, Memory.write_array(ram.memory, bank, addr &&& (ram.memory[0].size - 1), value))
    RWMemory.write_array(ram, bank, addr &&& @bank_mask, value)
    cart
  end

  def set_bank_control(%{mbc: %{type: :nombc}} = cart, _addr, _value), do: cart

  def set_bank_control(%{mbc: %{type: :mbc1} = mbc} = cart, addr, value) do
    mbc = cond do
      addr <= 0x1fff -> # RAM enable
        # Any value with 0xa in lower 4 bit enables RAM
        Map.put(mbc, :ram_enable, (value &&& 0x0a) != 0)
      addr <= 0x3fff -> # ROM bank number
        bank1 = value &&& @mbc1_bank1_mask
        # If writing 0x00 is attempted, make it 0x01
        bank1 = if bank1 == 0x00, do: 0x01, else: bank1
        put_in(cart.mbc.bank1, bank1)
        |> mbc1_set_bank()
      addr <= 0x5fff -> # RAM bank number or upper bits of ROM bank number
        put_in(cart.mbc.bank2, value &&& @mbc1_bank2_mask)
        |> mbc1_set_bank()
      true -> # Banking mode select
        mode = if (value &&& @mbc1_mode_mask) != 0, do: :advanced_rom_or_ram_bank, else: :simple_rom_bank
        put_in(cart.mbc.mode, mode)
        |> mbc1_set_bank()
    end
    Map.put(cart, :mbc, mbc)
  end

  def set_bank_control(%{mbc: %{type: :mbc3} = mbc} = cart, addr, value) do
    mbc = cond do
      addr <= 0x1fff -> # RAM enable
        # Any value with 0xa in lower 4 bit enables RAM & RTC registers
        Map.put(mbc, :ram_rtc_enable, (value &&& 0x0a) != 0)
      addr <= 0x3fff -> # ROM bank number (lower 7 bits)
        bank = if value == 0x00, do: 0x01, else: value &&& 0x7f
        offset = bank * 0x4000
        Map.put(mbc, :rom, offset)
      addr <= 0x5fff -> # RAM bank number or RTC register select
        cond do
          value <= 0x3 -> # Change RAM bank number for values 0x00-0x03
            Map.put(mbc, :ram, value)
          0x08 <= value and value <= 0x0c -> # Select RTC register
            Map.put(mbc, :ram, value)
          true ->
            mbc
        end
      true -> # Latch clock
        latch_clock = mbc.latch_clock
        case value do
          0x00 ->
            Map.put(mbc, :latch_clock, 0x00)
          0x01 ->
            if latch_clock == 0 do
              # TODO: latch clock data to RTC registers
              Map.put(mbc, :latch_clock, 0x01)
            else
              Map.put(mbc, :latch_clock, nil)
            end
          _ ->
            Map.put(mbc, :latch_clock, nil)
        end
    end
    Map.put(cart, :mbc, mbc)
  end

  defp mbc1_set_bank(%{mbc: %{mode: mode, bank1: bank1, bank2: bank2} = mbc, rom: rom, ram: ram} = cart) do
    rom_high = (((bank2 <<< 5) ||| bank1) * 0x4000) &&& (tuple_size(rom) - 1) 
    {rom_low, ram_bank} = if mode == :simple_rom_bank do
        # Only does regular rom banking
        {0x0000, 0x00}
    else
        # 0x0000-0x3ffff of ROM & RAM is affected by bank2
        {((bank2 <<< 5) * 0x4000) &&& (tuple_size(rom) - 1), bank2 &&& (Memory.array_size(ram.memory) - 1)}
    end
    %{mbc | rom: {rom_low, rom_high}, ram: ram_bank}
  end

end
