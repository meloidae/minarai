defmodule Gameboy.Cartridge do
  use Bitwise
  alias Gameboy.Cartridge
  alias Gameboy.Memory
  alias Gameboy.Utils

  defstruct mbc: :nombc,
            rom: %{memory: struct(Memory), offset: 0x4000},
            ram: %{memory: struct(Memory), offset: 0x0}

  # @path "roms/Upwell.gb"
  # @path "roms/flappyboy.gb"
  # @path "roms/2048.gb"
  # @path "roms/carazu.gb"
  @path "roms/SIKAKUJOSIKBJ3J.gb"
  # @path "roms/tests/blargg/cpu_instrs/cpu_instrs.gb"
  # @path "roms/tests/blargg/cpu_instrs/individual/01-special.gb"
  # @path "roms/tests/blargg/cpu_instrs/individual/02-interrupts.gb"
  # @path "roms/tests/blargg/cpu_instrs/individual/03-op sp,hl.gb"
  # @path "roms/tests/blargg/cpu_instrs/individual/04-op r,imm.gb"
  # @path "roms/tests/blargg/cpu_instrs/individual/05-op rp.gb"
  # @path "roms/tests/blargg/cpu_instrs/individual/06-ld r,r.gb"
  # @path "roms/tests/blargg/cpu_instrs/individual/07-jr,jp,call,ret,rst.gb"
  # @path "roms/tests/blargg/cpu_instrs/individual/08-misc instrs.gb"
  # @path "roms/tests/blargg/cpu_instrs/individual/09-op r,r.gb"
  # @path "roms/tests/blargg/cpu_instrs/individual/10-bit ops.gb"
  # @path "roms/tests/blargg/cpu_instrs/individual/11-op a,(hl).gb"

  # @path "roms/tests/mooneye-gb/acceptance/jp_timing.gb"
  # @path "roms/tests/mooneye-gb/acceptance/add_sp_e_timing.gb"
  # @path "roms/tests/mooneye-gb/acceptance/bits/reg_f.gb"
  # @path "roms/tests/mooneye-gb/acceptance/if_ie_registers.gb"
  # @path "roms/tests/mooneye-gb/acceptance/timer/div_write.gb"
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
      x when 0x01 in [0x01, 0x02, 0x03] ->
        %{type: :mbc1, mode: :simple_rom_bank, bank1: 0x01, bank2: 0x00, rom: {0x0000, 0x4000}, ram: 0x00, ram_enable: false}
      x ->
        raise "cart_type = 0x#{Utils.to_hex(x)} is not implemented"
    end
    IO.puts("Cartridge mbc: #{inspect(mbc)}")
    rom = init_rom(memory)
    ram = init_ram(mbc, memory)
    %Cartridge{mbc: mbc, rom: rom, ram: ram}
  end

  defp init_rom(rom_memory) do
    case Memory.read(rom_memory, @rom_size) do
      0x00 ->
        %{memory: rom_memory, size: 2 * @bank_size}
      0x01 ->
        %{memory: rom_memory, size: 4 * @bank_size}
      0x02 ->
        %{memory: rom_memory, size: 8 * @bank_size}
      0x03 ->
        %{memory: rom_memory, size: 16 * @bank_size}
      0x04 ->
        %{memory: rom_memory, size: 32 * @bank_size}
      0x05 ->
        %{memory: rom_memory, size: 64 * @bank_size}
      0x06 ->
        %{memory: rom_memory, size: 128 * @bank_size}
      0x07 ->
        %{memory: rom_memory, size: 256 * @bank_size}
      0x08 ->
        %{memory: rom_memory, size: 512 * @bank_size}
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
        %{memory: Memory.init_memory_array(0x0800, 1)}
      0x02 ->
        %{memory: Memory.init_memory_array(@bank_size, 1)}
      0x03 ->
        %{memory: Memory.init_memory_array(@bank_size, 4)}
      0x04 ->
        %{memory: Memory.init_memory_array(@bank_size, 16)}
      0x05 ->
        %{memory: Memory.init_memory_array(@bank_size, 8)}
    end
  end

  def read_rom_low(%{mbc: mbc, rom: rom, ram: ram} = cart, addr) do
    case mbc do
      %{type: :nombc} -> # No Mbc, so just read from specified address
        Memory.read(rom.memory, addr)
      %{type: :mbc1, rom: {low_offset, _high_offset}} ->
        Memory.read(rom.memory, low_offset ||| (addr &&& @bank_mask))
      _ ->
        raise "Read rom low for mbc #{inspect(mbc)} is unimplemented"
    end
  end

  def read_rom_high(%{mbc: mbc, rom: rom} = cart, addr) do
    case mbc do
      %{type: :nombc} -> # No Mbc, so just read from specified address
        Memory.read(rom.memory, addr)
      %{type: :mbc1, rom: {_low_offset, high_offset}} ->
        Memory.read(rom.memory, high_offset ||| (addr &&& @bank_mask))
      _ ->
        raise "Read rom high for mbc #{inspect(mbc)} is unimplemented"
    end
  end

  def read_binary_rom_low(%{mbc: mbc, rom: rom, ram: ram} = cart, addr, len) do
    case mbc do
      %{type: :nombc} -> # No Mbc, so just read from specified address
        Memory.read_binary(rom.memory, addr, len)
      %{type: :mbc1, rom: {low_offset, _high_offset}} ->
        Memory.read_binary(rom.memory, low_offset ||| (addr &&& @bank_mask), len)
      _ ->
        raise "Read binary rom low for mbc #{inspect(mbc)} is unimplemented"
    end
  end

  def read_binary_rom_high(%{mbc: mbc, rom: rom} = cart, addr, len) do
    case mbc do
      %{type: :nombc} -> # No Mbc, so just read from specified address
        Memory.read_binary(rom.memory, addr, len)
      %{type: :mbc1, rom: {_low_offset, high_offset}} ->
        Memory.read_binary(rom.memory, high_offset ||| (addr &&& @bank_mask), len)
      _ ->
        raise "Read binary rom high for mbc #{inspect(mbc)} is unimplemented"
    end
  end

  def read_ram(%{mbc: mbc, ram: ram} = cart, addr) do
    case mbc do
      %{type: :nombc} ->
        Memory.read_array(ram.memory, 0x0, addr &&& @bank_mask)
      %{type: :mbc1, ram: bank} ->
        Memory.read_array(ram.memory, bank, addr &&& (ram.memory[0].size - 1))
      _ ->
        raise "Read ram for mbc #{inspect(mbc)} is unimplemented"
    end
  end

  def write_ram(%{mbc: mbc, ram: ram} = cart, addr, value) do
    case mbc do
      %{type: :nombc} -> # How to enable write with no mbc?
        put_in(cart.ram.memory, Memory.write_array(ram.memory, 0x0, addr &&& @bank_mask, value))
      %{type: :mbc1, ram_enable: is_enabled, ram: bank} ->
        if is_enabled do
          put_in(cart.ram.memory, Memory.write_array(ram.memory, bank, addr &&& (ram.memory[0].size - 1), value))
        else # Don't modify if not enabled
          cart
        end
      _ ->
        raise "Write ram for mbc #{inspect(mbc)} is unimplemented"
    end
  end

  def set_bank_control(%{mbc: mbc} = cart, addr, value) do
    case mbc do
      %{type: :nombc} -> # Does rom need to be enabled in No Mbc cartridge that has RAM?
        cart
      %{type: :mbc1} ->
        mbc1_set_control(cart, addr, value)
    end
  end

  defp mbc1_set_control(%{mbc: mbc, rom: rom, ram: ram} = cart, addr, value) do
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
        mode = if (value &&& @mbc1_mode_mask) != 0, do: :advance_rom_or_ram_bank, else: :simple_rom_bank
        put_in(cart.mbc.mode, mode)
        |> mbc1_set_bank()
    end
    Map.put(cart, :mbc, mbc)
  end

  defp mbc1_set_bank(%{mbc: mbc, rom: rom, ram: ram} = cart) do
    %{mode: mode, bank1: bank1, bank2: bank2} = mbc
    rom_high = (((bank2 <<< 5) ||| bank1) * 0x4000) &&& (rom.size - 1) 
    {rom_low, ram_bank} = if mode == :simple_rom_bank do
        # Only does regular rom banking
        {0x0000, 0x00}
    else
        # 0x0000-0x3ffff of ROM & RAM is affected by bank2
        {((bank2 <<< 5) * 0x4000) &&& (rom.size - 1), bank2 &&& (Memory.array_size(ram.memory) - 1)}
    end
    %{mbc | rom: {rom_low, rom_high}, ram: ram_bank}
  end

end
