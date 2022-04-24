defmodule Gameboy.MutableCartridge.Mbc3 do
  use Bitwise
  alias Gameboy.TupleMemory
  alias Gameboy.EtsMemory, as: RWMemory

  @bank_size 0x4000
  @bank_mask 0xffff

  require Record
  Record.defrecordp(
    :mbc_state,
    rom_high: 0x4000,
    ram_bank: 0x00,
    ram_rtc_enable: false,
    rtc_s: 0x00,
    rtc_m: 0x00,
    rtc_h: 0x00,
    rtc_dl: 0x00,
    rtc_dh: 0x00,
    latch_clock: nil
  )

  for k <- [:rom_high, :ram_bank, :ram_rtc_enable, :rtc_s, :rtc_m, :rtc_h, :rtc_dl, :rtc_dh, :latch_clock] do
    defmacrop index(unquote(k)), do: mbc_state(unquote(k)) + 1
  end

  def init do
    ref = :ets.new(:mbc, [:public])
    mbc = mbc_state()
    :ets.insert(ref, mbc)
    ref
  end

  def read_rom_low(_mbc, rom, addr), do: TupleMemory.read(rom, addr &&& @bank_mask)

  def read_rom_high(mbc, rom, addr) do
    offset = :ets.lookup_element(mbc, :mbc_state, index(:rom_high))
    TupleMemory.read(rom, offset ||| (addr &&& @bank_mask))
  end

  def read_ram(mbc, ram, addr) do
    mbc_state(
      ram_bank: bank,
      rtc_s: rtc_s,
      rtc_m: rtc_m,
      rtc_h: rtc_h,
      rtc_dl: rtc_dl,
      rtc_dh: rtc_dh
    ) = :ets.lookup(mbc, :mbc_state) |> hd()
    case bank do
      0x08 -> rtc_s
      0x09 -> rtc_m
      0x0a -> rtc_h
      0x0b -> rtc_dl
      0x0c -> rtc_dh
      _ -> RWMemory.read_array(ram, bank, addr &&& @bank_mask)
    end
  end

  def write_ram(mbc, ram, addr, value) do
    mbc_state(ram_bank: bank, ram_rtc_enable: enable) = :ets.lookup(mbc, :mbc_state)
                                                        |> hd()
    case {enable, bank} do
      {false, _} -> nil
      {true, 0x08} -> :ets.update_element(mbc, :mbc_state, {index(:rtc_s), value})
      {true, 0x09} -> :ets.update_element(mbc, :mbc_state, {index(:rtc_m), value})
      {true, 0x0a} -> :ets.update_element(mbc, :mbc_state, {index(:rtc_h), value})
      {true, 0x0b} -> :ets.update_element(mbc, :mbc_state, {index(:rtc_dl), value})
      {true, 0x0c} -> :ets.update_element(mbc, :mbc_state, {index(:rtc_dh), value})
      {true, _}-> RWMemory.write_array(ram, bank, addr &&& @bank_mask, value)
    end
  end

  def set_bank_control(mbc, _rom, _ram, addr, value) do
    cond do
      addr <= 0x1fff -> # RAM enable
        # Any value with 0xa in lower 4 bit enables RAM & RTC registers
        :ets.update_element(mbc, :mbc_state, {index(:ram_rtc_enable), (value &&& 0x0a) == 0x0a})
      addr <= 0x3fff -> # ROM bank number (lower 7 bits only)
        # If writing 0x00 is attempted, force it to be 0x01
        bank = if value == 0x00, do: 0x01, else: value &&& 0x7f
        offset = bank * @bank_size
        :ets.update_element(mbc, :mbc_state, {index(:rom_high), offset})
      addr <= 0x5fff -> # RAM bank number or RTC register select
        # 0x00-0x03: Change RAM bank number
        # 0x08-0x0c: Select RTC register
        if value <= 0x03 or (0x08 <= value and value <= 0x0c) do
          :ets.update_element(mbc, :mbc_state, {index(:ram_bank), value})
        end
      true -> # Latch clock
        case value do
          0x00 ->
            :ets.update_element(mbc, :mbc_state, {index(:latch_clock), 0x00})
          0x01 ->
            prev_latch_clock = :ets.lookup_element(mbc, :mbc_state, index(:latch_clock))
            if prev_latch_clock == 0 do
              # TODO Actuallly latch clock value when 0 and 1 are written in order
              :ets.update_element(mbc, :mbc_state, {index(:latch_clock), 0x01})
            else
              :ets.update_element(mbc, :mbc_state, {index(:latch_clock), nil})
            end
          _ ->
            :ets.update_element(mbc, :mbc_state, {index(:latch_clock), nil})
        end
    end
  end
end
