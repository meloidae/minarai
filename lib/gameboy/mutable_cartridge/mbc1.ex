defmodule Gameboy.MutableCartridge.Mbc1 do
  use Bitwise
  alias Gameboy.TupleMemory
  alias Gameboy.EtsMemory, as: RWMemory

  @bank_mask 0x3fff
  @mbc1_bank1_mask 0x1f
  @mbc1_bank2_mask 0x03
  @mbc1_mode_mask 0x01
  # mbc1-related functions

  require Record
  Record.defrecordp(
    :mbc_state,
    mode: :simple_rom_bank,
    bank1: 0x1,
    bank2: 0x0,
    rom_low: 0x0000,
    rom_high: 0x4000,
    ram_bank: 0x00,
    ram_enable: false
  )

  for k <- [:mode, :bank1, :bank2, :rom_low, :rom_high, :ram_bank, :ram_enable] do
    defmacrop index(unquote(k)), do: mbc_state(unquote(k)) + 1
  end

  def init do
    ref = :ets.new(:mbc, [:public])
    mbc = mbc_state()
    :ets.insert(ref, mbc)
    ref
  end

  def read_rom_low(mbc, rom, addr) do
    offset = :ets.lookup_element(mbc, :mbc_state, index(:rom_low))
    TupleMemory.read(rom, offset ||| (addr &&& @bank_mask))
  end

  def read_rom_high(mbc, rom, addr) do
    offset = :ets.lookup_element(mbc, :mbc_state, index(:rom_high))
    TupleMemory.read(rom, offset ||| (addr &&& @bank_mask))
  end

  def read_binary_rom_low(mbc, rom, addr, len) do
    offset = :ets.lookup_element(mbc, :mbc_state, index(:rom_low))
    TupleMemory.read_binary(rom, offset ||| (addr &&& @bank_mask), len)
  end

  def read_binary_rom_high(mbc, rom, addr, len) do
    offset = :ets.lookup_element(mbc, :mbc_state, index(:rom_low))
    TupleMemory.read_binary(rom, offset ||| (addr &&& @bank_mask), len)
  end

  def read_ram(mbc, ram, addr) do
    bank = :ets.lookup_element(mbc, :mbc_state, index(:ram_bank))
    RWMemory.read_array(ram, bank, addr &&& @bank_mask)
  end

  def write_ram(mbc, ram, addr, value) do
    mbc_state(ram_bank: bank, ram_enable: ram_enable) = :ets.lookup(mbc, :mbc_state)
                                                   |> hd()
    if ram_enable do
      RWMemory.write_array(ram, bank, addr &&& @bank_mask, value)
    end
  end

  def set_bank_control(mbc, rom, ram, addr, value) do
    cond do
      addr <= 0x1fff -> # RAM enable
        # Any value with 0xa in lower 4 bit enables RAM
        :ets.update_element(mbc, :mbc_state, {index(:ram_enable), (value &&& 0x0a) == 0x0a})
      addr <= 0x3fff -> # ROM bank number
        bank1 = value &&& @mbc1_bank1_mask
        # If writing 0x00 is attempted, force it to be 0x01
        bank1 = if bank1 == 0x00, do: 0x01, else: bank1
        mbc_state(mode: mode, bank2: bank2) = :ets.lookup(mbc, :mbc_state)
                                              |> hd()
        mbc1_set_bank(mbc, mode, bank1, bank2, rom, ram)
      addr <= 0x5fff -> # RAM bank number or upper bits of ROM bank number
        bank2 = value &&& @mbc1_bank2_mask
        mbc_state(mode: mode, bank1: bank1) = :ets.lookup(mbc, :mbc_state)
                                              |> hd()
        mbc1_set_bank(mbc, mode, bank1, bank2, rom, ram)
      true -> # Banking mode select
        mode = if (value &&& @mbc1_mode_mask) != 0, do: :advanced_rom_or_ram_bank, else: :simple_rom_bank
        mbc_state(bank1: bank1, bank2: bank2) = :ets.lookup(mbc, :mbc_state)
                                                |> hd()
        mbc1_set_bank(mbc, mode, bank1, bank2, rom, ram)
    end
  end

  def mbc1_set_bank(mbc, :simple_rom_bank, bank1, bank2, rom, _ram) do
    # Regular ROM banking
    rom_high = (((bank2 <<< 5) ||| bank1) * 0x4000) &&& (tuple_size(rom) - 1) 
    updates = [
      {index(:mode), :simple_rom_bank},
      {index(:bank1), bank1}, 
      {index(:bank2), bank2},
      {index(:rom_low), 0x0000},
      {index(:rom_high), rom_high},
      {index(:ram_bank), 0x00},
    ]
    :ets.update_element(mbc, :mbc_state, updates)
  end

  def mbc1_set_bank(mbc, :advanced_rom_or_ram_bank, bank1, bank2, rom, ram) do
    # RAM and 0x0000-0x3ffff of ROM are affected by bank2
    rom_high = (((bank2 <<< 5) ||| bank1) * 0x4000) &&& (tuple_size(rom) - 1) 
    rom_low = ((bank2 <<< 5) * 0x4000) &&& (tuple_size(rom) - 1)
    ram_bank = bank2 &&& (RWMemory.array_size(ram) - 1)
    updates = [
      {index(:mode), :advanced_rom_or_ram_bank},
      {index(:bank1), bank1}, 
      {index(:bank2), bank2},
      {index(:rom_low), rom_low},
      {index(:rom_high), rom_high},
      {index(:ram_bank), ram_bank},
    ]
    :ets.update_element(mbc, :mbc_state, updates)
  end
end
