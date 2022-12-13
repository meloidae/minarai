defmodule Gameboy.Cartridge do
  import Bitwise
  alias Gameboy.Memory
  alias Gameboy.Utils
  alias Gameboy.TupleMemory
  alias Gameboy.EtsMemory, as: RWMemory

  defstruct mbc: :nombc,
            ram: nil

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

  @path "@{path}"

  @rom @path
  |> File.read!()
  |> TupleMemory.init()

  @mbc_type @rom
  |> TupleMemory.read(@cart_type)
  |> (case do
    0x00 ->
      :nombc
    x when x in 0x01..0x03 ->
      :mbc1
    x when x in 0x0f..0x13 ->
      :mbc3
    x ->
      x
  end)

  @default_mbc @mbc_type
  |> (case do
    :nombc ->
      nil
    :mbc1 ->
      %{mode: :simple_rom_bank, bank1: 0x01, bank2: 0x00, rom: {0x0000, 0x4000}, ram: 0x00, ram_enable: false}
    :mbc3 ->
      %{rom: 0x4000, ram: 0x00, ram_rtc_enable: false, rtc_s: 0x00, rtc_m: 0x00, rtc_h: 0x00, rtc_dl: 0x00, rtc_dh: 0x00, latch_clock: nil}
    x ->
      x
  end)

  defp rom, do: @rom

  def init(_path) do
    mbc = @default_mbc
    if not is_atom(@mbc_type) do
      raise "cart_type = 0x#{Utils.to_hex(@mbc_type)} is not implemented"
    end
    ram = init_ram(mbc)
    IO.puts("MBC type: #{@mbc_type}")
    IO.puts("Cartridge mbc: #{inspect(mbc)}")
    IO.puts("ROM banks: #{div(tuple_size(rom()), @bank_size)}")
    {mbc, ram}
  end

  def set_rom(cart, _rom), do: cart

  def get_rom(_cart), do: rom()

  defp init_ram(_mbc) do
    case TupleMemory.read(rom(), @ram_size) do
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

  case @mbc_type do
    :nombc ->
      def read_rom_low(_cart, addr) do
        # No Mbc, so just read from specified address
        TupleMemory.read(rom(), addr)
      end
    :mbc1 ->
      def read_rom_low({%{rom: {low_offset, _high_offset}}, _ram}, addr) do
        TupleMemory.read(rom(), low_offset ||| (addr &&& @bank_mask))
      end
    :mbc3 ->
      def read_rom_low(_cart, addr) do
        TupleMemory.read(rom(), addr)
      end
    _ ->
      def red_rom_low(_cart, _addr) do
        raise "read_rom_low() is not implemented for #{@mbc_type}"
      end
  end

  case @mbc_type do
    :nombc ->
      def read_rom_high(_cart, addr) do
        TupleMemory.read(rom(), addr)
      end
    :mbc1 ->
      def read_rom_high({%{rom: {_low_offset, high_offset}}, _ram}, addr) do
        TupleMemory.read(rom(), high_offset ||| (addr &&& @bank_mask))
      end
    :mbc3 ->
      def read_rom_high({%{rom: offset}, _ram}, addr) do
        TupleMemory.read(rom(), offset ||| (addr &&& @bank_mask))
      end
    _ ->
      def red_rom_high(_cart, _addr) do
        raise "read_rom_high() is not implemented for #{@mbc_type}"
      end
  end

  case @mbc_type do
    :nombc ->
      def read_binary_rom_low(_cart, addr, len) do
        TupleMemory.read_binary(rom(), addr, len)
      end
    :mbc1 ->
      def read_binary_rom_low({%{rom: {low_offset, _high_offset}}, _ram}, addr, len) do
        TupleMemory.read_binary(rom(), low_offset ||| (addr &&& @bank_mask), len)
      end
    :mbc3 ->
      def read_binary_rom_low(_cart, addr, len) do
        TupleMemory.read_binary(rom(), addr, len)
      end
    _ ->
      def read_binary_rom_low(_cart, _addr, _len) do
        raise "Read binary rom low for mbc #{@mbc_type} is unimplemented"
      end
  end

  case @mbc_type do
    :nombc ->
      def read_binary_rom_high(_cart, addr, len) do
        TupleMemory.read_binary(rom(), addr, len)
      end
    :mbc1 ->
      def read_binary_rom_high({%{rom: {_low_offset, high_offset}}, _ram}, addr, len) do
        TupleMemory.read_binary(rom(), high_offset ||| (addr &&& @bank_mask), len)
      end
    :mbc3 ->
      def read_binary_rom_high({%{rom: offset}, _ram}, addr, len) do
        TupleMemory.read_binary(rom(), offset ||| (addr &&& @bank_mask), len)
      end
    _ ->
      def read_binary_rom_high(_cart, _addr, _len) do
        raise "Read binary rom high for mbc #{@mbc_type} is unimplemented"
      end
  end

  case @mbc_type do
    :nombc ->
      def read_ram({_mbc, ram}, addr) do
        RWMemory.read_array(ram, 0x0, addr &&& @bank_mask)
      end
    :mbc1 ->
      def read_ram({%{ram: bank}, ram}, addr) do
        RWMemory.read_array(ram, bank, addr &&& @bank_mask)
      end
    :mbc3 ->
      def read_ram({%{ram: 0x08, rtc_s: value}, _ram}, _addr), do: value
      def read_ram({%{ram: 0x09, rtc_m: value}, _ram}, _addr), do: value
      def read_ram({%{ram: 0x0a, rtc_h: value}, _ram}, _addr), do: value
      def read_ram({%{ram: 0x0b, rtc_dl: value}, _ram}, _addr), do: value
      def read_ram({%{ram: 0x0c, rtc_dh: value}, _ram}, _addr), do: value
      def read_ram({%{ram: bank}, ram}, addr) do
        RWMemory.read_array(ram, bank, addr &&& @bank_mask)
      end
  end

  case @mbc_type do
    :nombc ->
      def write_ram({_mbc, ram} = cart, addr, value) do
        # How to enable write with no mbc?
        # put_in(cart.ram.memory, Memory.write_array(ram.memory, 0x0, addr &&& @bank_mask, value))
        RWMemory.write_array(ram, 0x0, addr &&& @bank_mask, value)
        cart
      end
    :mbc1 ->
      def write_ram({%{ram_enable: false}, _ram} = cart, _addr, _value), do: cart
      def write_ram({%{ram_enable: true, ram: bank}, ram} = cart, addr, value) do
        # put_in(cart.ram.memory, Memory.write_array(ram.memory, bank, addr &&& (ram.memory[0].size - 1), value))
        RWMemory.write_array(ram, bank, addr &&& @bank_mask, value)
        cart
      end
    :mbc3 ->
      def write_ram({%{ram_rtc_enable: false}, _ram} = cart, _addr, _value), do: cart
      def write_ram({%{ram_rtc_enable: true, ram: 0x08}, _ram} = cart, _addr, value) do
        put_in(cart.mbc.rtc_s, value)
      end
      def write_ram({%{ram_rtc_enable: true, ram: 0x09}, _ram} = cart, _addr, value) do
        put_in(cart.mbc.rtc_m, value)
      end
      def write_ram({%{ram_rtc_enable: true, ram: 0x0a}, _ram} = cart, _addr, value) do
        put_in(cart.mbc.rtc_h, value)
      end
      def write_ram({%{ram_rtc_enable: true, ram: 0x0b}, _ram} = cart, _addr, value) do
        put_in(cart.mbc.rtc_dl, value)
      end
      def write_ram({%{ram_rtc_enable: true, ram: 0x0c}, _ram} = cart, _addr, value) do
        put_in(cart.mbc.rtc_dh, value)
      end
      def write_ram({%{ram_rtc_enable: true, ram: bank}, ram} = cart, addr, value) do
        # put_in(cart.ram.memory, Memory.write_array(ram.memory, bank, addr &&& (ram.memory[0].size - 1), value))
        RWMemory.write_array(ram, bank, addr &&& @bank_mask, value)
        cart
      end
  end

  case @mbc_type do
    :nombc ->
      def set_bank_control(cart, _addr, _value), do: cart
    :mbc1 ->
      def set_bank_control({mbc, ram} = cart, addr, value) do
        mbc = cond do
          addr <= 0x1fff -> # RAM enable
            # Any value with 0xa in lower 4 bit enables RAM
            Map.put(mbc, :ram_enable, (value &&& 0x0a) != 0)
          addr <= 0x3fff -> # ROM bank number
            bank1 = value &&& @mbc1_bank1_mask
            # If writing 0x00 is attempted, make it 0x01
            bank1 = if bank1 == 0x00, do: 0x01, else: bank1
            Map.put(mbc, :bank1, bank1)
            |> mbc1_set_bank(ram)
          addr <= 0x5fff -> # RAM bank number or upper bits of ROM bank number
            Map.put(mbc, :bank2, value &&& @mbc1_bank2_mask)
            |> mbc1_set_bank(ram)
          true -> # Banking mode select
            mode = if (value &&& @mbc1_mode_mask) != 0, do: :advance_rom_or_ram_bank, else: :simple_rom_bank
            Map.put(mbc, :mode, mode)
            |> mbc1_set_bank(ram)
        end
        {mbc, ram}
      end
    :mbc3 ->
      def set_bank_control({mbc, ram}, addr, value) do
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
        {mbc, ram}
      end
  end

  if @mbc_type == :mbc1 do
    defp mbc1_set_bank(%{mode: mode, bank1: bank1, bank2: bank2} = mbc, ram) do
      rom_high = (((bank2 <<< 5) ||| bank1) * 0x4000) &&& (tuple_size(rom()) - 1) 
      {rom_low, ram_bank} = if mode == :simple_rom_bank do
          # Only does regular rom banking
          {0x0000, 0x00}
      else
          # 0x0000-0x3ffff of ROM & RAM is affected by bank2
          {((bank2 <<< 5) * 0x4000) &&& (tuple_size(rom()) - 1), bank2 &&& (Memory.array_size(ram.memory) - 1)}
      end
      %{mbc | rom: {rom_low, rom_high}, ram: ram_bank}
    end
  end

end
