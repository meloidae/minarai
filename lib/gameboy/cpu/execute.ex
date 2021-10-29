defmodule Gameboy.Cpu.Execute do
  use Bitwise
  alias Gameboy.Cpu
  alias Gameboy.Hardware
  alias Gameboy.Interrupts
  alias Gameboy.Utils

  # 8 bit load
  def ld(%Cpu{} = cpu, hw, dst, src) do
    {value, cpu, hw} = Cpu.read(cpu, src, hw)
    Cpu.write(cpu, dst, hw, value)
  end

  def debug(cpu, _hw) do
    IO.puts("#{inspect(cpu)}")
    receive do
      _ -> IO.puts("Done")
    end
  end

  # 16 bit loads
  # LD rr, nn
  # 12 cycles
  def ld16_rr_nn(%Cpu{} = cpu, hw, reg16) do
    {value, cpu, hw} = Cpu.fetch_imm16(cpu, hw)
    {Cpu.write_register(cpu, reg16, value), hw}
  end

  # LD SP, HL
  # 8 cycles
  def ld16_sp_hl(%Cpu{} = cpu, hw) do
    value = Cpu.read_register(cpu, :hl)
    cpu = Map.put(cpu, :sp, value)
    {cpu, Hardware.sync_cycle(hw)} # Add 4 extra cycles
  end

  # LDHL SP, n
  # 12 cycles
  def ld16_hl_sp_n(%Cpu{} = cpu, hw) do
    sp = cpu.sp
    {offset, cpu, hw} = Cpu.fetch_imm8(cpu, hw)
    {value, carry, half_carry} = Cpu.add_u16_byte_carry(sp, offset)
    cpu = Cpu.write_register(cpu, :hl, value)
          |> Cpu.set_flag(:z, false)
          |> Cpu.set_flag(:n, false)
          |> Cpu.set_flag(:h, half_carry)
          |> Cpu.set_flag(:c, carry)
    {cpu, Hardware.sync_cycle(hw)} # Add 4 extra cycles
  end

  # LD (nn), SP
  # 20 cycles
  def ld16_nn_sp(%Cpu{} = cpu, hw) do
    value = cpu.sp
    {addr, cpu, hw} = Cpu.fetch_imm16(cpu, hw)
    hw = Hardware.synced_write(hw, addr, value &&& 0xff)
    {cpu, Hardware.synced_write(hw, (addr + 1) &&& 0xffff, (value >>> 8) &&& 0xff)}
  end

  # PUSH rr
  # 16 cycles
  def push16_rr(%Cpu{} = cpu, hw, reg16) do
    value = Cpu.read_register(cpu, reg16)
    hw = Hardware.sync_cycle(hw) # Add 4 extra cycles
    Cpu.push_u16(cpu, hw, value)
  end

  # POP rr
  # 12 cycles
  def pop16_rr(%Cpu{} = cpu, hw, reg16) do
    {value, cpu, hw} = Cpu.pop_u16(cpu, hw)
    {Cpu.write_register(cpu, reg16, value), hw}
  end

  # Addtions
  defp _add(%Cpu{} = cpu, hw, dst, src, add_fn) do
    {val1, cpu, hw} = Cpu.read(cpu, dst, hw)
    {val2, cpu, hw} = Cpu.read(cpu, src, hw)
    {sum, carry, half_carry} = add_fn.(val1, val2, cpu)
    {cpu, hw} = Cpu.write(cpu, dst, hw, sum)
    cpu = Cpu.set_flag(cpu, :z, sum == 0)
    |> Cpu.set_flag(:n, false)
    |> Cpu.set_flag(:h, half_carry)
    |> Cpu.set_flag(:c, carry)
    {cpu, hw}
  end
  # ADD dd, ss
  def add(%Cpu{} = cpu, hw, dst, src), do: _add(cpu, hw, dst, src, &Cpu.add_u8_byte_carry/3)
  # ADC dd, ss
  def adc(%Cpu{} = cpu, hw, dst, src), do: _add(cpu, hw, dst, src, &Cpu.adc_u8_byte_carry/3)


  # Subtractions
  defp _sub(%Cpu{} = cpu, hw, dst, src, sub_fn) do
    {val1, cpu, hw} = Cpu.read(cpu, dst, hw)
    {val2, cpu, hw} = Cpu.read(cpu, src, hw)
    {diff, carry, half_carry} = sub_fn.(val1, val2, cpu)
    {cpu, hw} = Cpu.write(cpu, dst, hw, diff)
    cpu = Cpu.set_flag(cpu, :z, diff == 0)
    |> Cpu.set_flag(:n, true)
    |> Cpu.set_flag(:h, half_carry)
    |> Cpu.set_flag(:c, carry)
    {cpu, hw}
  end
  # SUB dd, ss
  def sub(%Cpu{} = cpu, hw, dst, src), do: _sub(cpu, hw, dst, src, &Cpu.sub_u8_byte_carry/3)
  def sbc(%Cpu{} = cpu, hw, dst, src), do: _sub(cpu, hw, dst, src, &Cpu.sbc_u8_byte_carry/3)

  # AND dd, ss
  def and_op(%Cpu{} = cpu, hw, dst, src) do
    {val1, cpu, hw} = Cpu.read(cpu, dst, hw)
    {val2, cpu, hw} = Cpu.read(cpu, src, hw)
    result = val1 &&& val2
    {cpu, hw} = Cpu.write(cpu, dst, hw, result)
    cpu = Cpu.set_flag(cpu, :z, result == 0)
    |> Cpu.set_flag(:n, false)
    |> Cpu.set_flag(:h, true)
    |> Cpu.set_flag(:c, false)
    {cpu, hw}
  end

  # OR dd, ss
  def or_op(%Cpu{} = cpu, hw, dst, src) do
    {val1, cpu, hw} = Cpu.read(cpu, dst, hw)
    {val2, cpu, hw} = Cpu.read(cpu, src, hw)
    result = val1 ||| val2
    {cpu, hw} = Cpu.write(cpu, dst, hw, result)
    cpu = Cpu.set_flag(cpu, :z, result == 0)
    |> Cpu.set_flag(:n, false)
    |> Cpu.set_flag(:h, false)
    |> Cpu.set_flag(:c, false)
    {cpu, hw}
  end

  # XOR dd, ss
  def xor(%Cpu{} = cpu, hw, dst, src) do
    {val1, cpu, hw} = Cpu.read(cpu, dst, hw)
    {val2, cpu, hw} = Cpu.read(cpu, src, hw)
    result = bxor(val1, val2)
    {cpu, hw} = Cpu.write(cpu, dst, hw, result)
    cpu = Cpu.set_flag(cpu, :z, result == 0)
    |> Cpu.set_flag(:n, false)
    |> Cpu.set_flag(:h, false)
    |> Cpu.set_flag(:c, false)
    {cpu, hw}
  end

  # CP dd, ss
  def cp(%Cpu{} = cpu, hw, dst, src) do
    {val1, cpu, hw} = Cpu.read(cpu, dst, hw)
    {val2, cpu, hw} = Cpu.read(cpu, src, hw)
    {diff, carry, half_carry} = Cpu.sub_u8_byte_carry(val1, val2)
    # cpu = Cpu.set_flag(cpu, :z, diff == 0)
    # |> Cpu.set_flag(:n, true)
    # |> Cpu.set_flag(:h, half_carry)
    # |> Cpu.set_flag(:c, carry)
    cpu = Cpu.set_flags(cpu, [{:z, diff == 0}, {:n, true}, {:h, half_carry}, {:c, carry}])
    # IO.puts("cp")
    {cpu, hw}
  end

  # INC d
  def inc(%Cpu{} = cpu, hw, dst) do
    {value, cpu, hw} = Cpu.read(cpu, dst, hw)
    {sum, _carry, half_carry} = Cpu.add_u8_byte_carry(value, 1)
    Cpu.set_flag(cpu, :z, sum == 0)
    |> Cpu.set_flag(:n, false)
    |> Cpu.set_flag(:h, half_carry)
    |> Cpu.write(dst, hw, sum)
  end

  # DEC d
  def dec(%Cpu{} = cpu, hw, dst) do
    {value, cpu, hw} = Cpu.read(cpu, dst, hw)
    {diff, _carry, half_carry} = Cpu.sub_u8_byte_carry(value, 1)
    Cpu.set_flag(cpu, :z, diff == 0)
    |> Cpu.set_flag(:n, true)
    |> Cpu.set_flag(:h, half_carry)
    |> Cpu.write(dst, hw, diff)
  end


  # 16-bit arithmetic
  #
  # ADD HL, rr
  # 8 cycles
  # z flag is not affected
  def add16_hl_rr(%Cpu{} = cpu, hw, reg16) do
    hl = Cpu.read_register(cpu, :hl)
    val = Cpu.read_register(cpu, reg16)
    {sum, carry, half_carry} = Cpu.add_u16_word_carry(hl, val)
    # cpu = Cpu.write_register(cpu, :hl, sum)
    #       |> Cpu.set_flag(:n, false)
    #       |> Cpu.set_flag(:h, half_carry)
    #       |> Cpu.set_flag(:c, carry)
    cpu = Cpu.write_register(cpu, :hl, sum)
          |> Cpu.set_flags([{:n, false}, {:h, half_carry}, {:c, carry}])
    {cpu, Hardware.sync_cycle(hw)} # Add 4 extra cycles
  end

  # ADD SP, n
  # 16 cycles
  def add16_sp_n(%Cpu{} = cpu, hw) do
    {offset, cpu, hw} = Cpu.fetch_imm8(cpu, hw)
    sp = cpu.sp
    {sum, carry, half_carry} = Cpu.add_u16_byte_carry(sp, offset)
    cpu = Map.put(cpu, :sp, sum)
          |> Cpu.set_flag(:z, false)
          |> Cpu.set_flag(:n, false)
          |> Cpu.set_flag(:h, half_carry)
          |> Cpu.set_flag(:c, carry)
    # Add 8 extra cycles
    {cpu, Hardware.sync_cycle(hw) |> Hardware.sync_cycle()}
  end

  # INC rr
  # 8 cycles
  def inc16_rr(%Cpu{} = cpu, hw, reg16) do
    value = Cpu.read_register(cpu, reg16)
    cpu = Cpu.write_register(cpu, reg16, (value + 1) &&& 0xffff)
    {cpu, Hardware.sync_cycle(hw)} # Add 4 extra cycles
  end

  # DEC rr
  # 8 cycles
  def dec16_rr(%Cpu{} = cpu, hw, reg16) do
    value = Cpu.read_register(cpu, reg16)
    cpu = Cpu.write_register(cpu, reg16, (value - 1) &&& 0xffff)
    {cpu, Hardware.sync_cycle(hw)} # Add 4 extra cycles
  end

  # Miscellaneous instructions
  #
  # SWAP dd
  # dd is either 8-bit register or address in HL
  # Swaps lower bit higher bit of dst
  def swap(%Cpu{} = cpu, hw, dst) do
    {value, cpu, hw} = Cpu.read(cpu, dst, hw)
    value = ((value &&& 0x0f) <<< 4) ||| ((value &&& 0xf0) >>> 4)
    Cpu.set_flag(cpu, :z, value == 0)
    |> Cpu.set_flag(:n, false)
    |> Cpu.set_flag(:h, false)
    |> Cpu.set_flag(:c, false)
    |> Cpu.write(dst, hw, value)
  end

  # DAA
  # 4 cycles
  # decimal adjust register A
  def daa(%Cpu{} = cpu, hw) do
    a = cpu.a
    c = Cpu.flag(cpu, :c)
    h = Cpu.flag(cpu, :h)
    {carry, a} = if !Cpu.flag(cpu, :n) do # After add/adc
      {carry, a} = if c or (a > 0x99), do: {true, (a + 0x60) &&& 0xff}, else: {false, a}
      a = if h or (a &&& 0x0f) > 0x09, do: (a + 0x06) &&& 0xff, else: a
      {carry, a}
    else # After sub/sbc
      case {c, h} do
        {true, true} ->
          {true, (a + 0x9a) &&& 0xff}
        {true, false} ->
          {true, (a + 0xa0) &&& 0xff}
        {false, true} ->
          {false, (a + 0xfa) &&& 0xff}
        _ ->
          {false, a}
      end
    end
    cpu = Map.put(cpu, :a, a)
    |> Cpu.set_flag(:z, a == 0)
    |> Cpu.set_flag(:h, false)
    |> Cpu.set_flag(:c, carry)
    {cpu, hw}
  end

  # CPL
  # 4 cycles
  # Take complement (flip bits of) A register
  def cpl(%Cpu{} = cpu, hw) do
    a = cpu.a
    cpu = Map.put(cpu, :a, ~~~a &&& 0xff)
    |> Cpu.set_flag(:n, true)
    |> Cpu.set_flag(:h, true)
    {cpu, hw}
  end

  # CCF
  # 4 cycles
  # Complement a carry flag
  def ccf(%Cpu{} = cpu, hw) do
    carry = Cpu.flag(cpu, :c)
    cpu = Cpu.set_flag(cpu, :c, !carry)
    |> Cpu.set_flag(:n, false)
    |> Cpu.set_flag(:h, false)
    {cpu, hw}
  end

  # SCF
  # 4 cycles
  # Set a carry flag
  def scf(%Cpu{} = cpu, hw) do
    cpu = Cpu.set_flag(cpu, :c, true)
    |> Cpu.set_flag(:n, false)
    |> Cpu.set_flag(:h, false)
    {cpu, hw}
  end

  # NOP
  # 4 cycles
  # Does... nothing
  def nop(cpu, hw) do
    {cpu, hw}
  end

  # HALT
  # 4 cycles
  # TODO
  # Enter halt state unless it's a halt bug
  def halt(%Cpu{} = cpu, hw) do
    cond do
      cpu.ime ->
        {Map.put(cpu, :state, :halt), hw}
      !is_nil(Interrupts.check(hw.intr)) ->
        {Map.put(cpu, :state, :halt), hw}
      true ->
        {Map.put(cpu, :state, :haltbug), hw}
    end
  end

  # STOP
  # 4 cycles
  # raise error fo now
  def stop(%Cpu{} = cpu, hw) do
    {cpu, hw}
  end

  # DI
  # 4 cycles
  # Disable interrupt immediately (unlike how ei is delayed)
  def di(%Cpu{} = cpu, hw) do
    {Map.put(cpu, :ime, false), hw}
  end

  # EI
  # 4 cycles
  # Enable interrupt (but is delayed)
  def ei(%Cpu{} = cpu, hw) do
    {Map.put(cpu, :delayed_set_ime, true), hw}
  end

  # Rotation/Shifts
  def _shift(%Cpu{} = cpu, hw, dst, shift_fn) do
    {value, cpu, hw} = Cpu.read(cpu, dst, hw)
    {value, carry} = shift_fn.(value, cpu)
    # Cpu.set_flag(cpu, :z, value == 0)
    # |> Cpu.set_flag(:n, false)
    # |> Cpu.set_flag(:h, false)
    # |> Cpu.set_flag(:c, carry)
    # |> Cpu.write(dst, hw, value)
    Cpu.set_flags(cpu, [{:z, value == 0}, {:n, false}, {:h, false}, {:c, carry}])
    |> Cpu.write(dst, hw, value)
  end
  # RLC dd
  # 2-byte opcode (+ 4 cycles) unless it's RLCA (1-byte opcode)
  # rotate left
  def rlc(%Cpu{} = cpu, hw, dst), do: _shift(cpu, hw, dst, &Cpu.rlc_u8_byte_carry/2)
  # RL dd
  # 2-byte opcode (+ 4 cycles), unless RLA
  # rotate left through carry
  def rl(%Cpu{} = cpu, hw, dst), do: _shift(cpu, hw, dst, &Cpu.rl_u8_byte_carry/2)
  # RRC dd
  # 2-byte opcode (+ 4 cycles), unless it's RRCA (1-byte opcode)
  # rorate right
  def rrc(%Cpu{} = cpu, hw, dst), do: _shift(cpu, hw, dst, &Cpu.rrc_u8_byte_carry/2)
  # RR dd
  # 2-byte opcode (+ 4 cycles), unless it's RRCA (1-byte opcode)
  # rorate right through carry
  def rr(%Cpu{} = cpu, hw, dst), do: _shift(cpu, hw, dst, &Cpu.rr_u8_byte_carry/2)
  # SLA dd
  # 2-byte opcode (+ 4 cycles)
  # shift left
  def sla(%Cpu{} = cpu, hw, dst), do: _shift(cpu, hw, dst, &Cpu.sla_u8_byte_carry/2)
  # SRA dd
  # 2-byte opcode (+ 4 cycles)
  # shift right, msb doesn't change
  def sra(%Cpu{} = cpu, hw, dst), do: _shift(cpu, hw, dst, &Cpu.sra_u8_byte_carry/2)
  # SRL dd
  # 2-byte opcode (+ 4 cycles)
  # shift right, msb is set to 0
  def srl(%Cpu{} = cpu, hw, dst), do: _shift(cpu, hw, dst, &Cpu.srl_u8_byte_carry/2)

  # Bit instructions
  #
  # BIT b, dd
  # 2-byte opcode (+ 4 cycles)
  # Test bit b of dst
  def bit(%Cpu{} = cpu, hw, bit, dst) do
    {value, cpu, hw} = Cpu.read(cpu, dst, hw)
    value = value &&& (0x1 <<< bit)
    cpu = Cpu.set_flag(cpu, :z, value == 0)
    |> Cpu.set_flag(:n, false)
    |> Cpu.set_flag(:h, true)
    {cpu, hw}
  end
  # SET b, dd
  # 2-byte opcode (+ 4 cycles)
  # Set bit b of dst, flags are unaffected
  def set(%Cpu{} = cpu, hw, bit, dst) do
    {value, cpu, hw} = Cpu.read(cpu, dst, hw)
    value = value ||| (0x1 <<< bit)
    Cpu.write(cpu, dst, hw, value)
  end
  # RES b, dd
  # 2-byte opcode (+ 4 cycles)
  # Reset bit b of dst, flags are unaffected
  def res(%Cpu{} = cpu, hw, bit, dst) do
    {value, cpu, hw} = Cpu.read(cpu, dst, hw)
    value = value &&& ~~~(0x1 <<< bit)
    Cpu.write(cpu, dst, hw, value)
  end

  # Jumps
  #
  # JP nn
  # 16 cycles
  # jump using immediate u16 value
  def jp_nn(%Cpu{} = cpu, hw) do
    {addr, cpu, hw} = Cpu.fetch_imm16(cpu, hw)
    cpu = Map.put(cpu, :pc, addr)
    {cpu, Hardware.sync_cycle(hw)}
  end
  # JP hl
  # 4 cycles
  # jump to address stored in HL register
  def jp_hl(%Cpu{} = cpu, hw) do
    addr = Cpu.read_register(cpu, :hl)
    {Map.put(cpu, :pc, addr), hw}
  end
  # JP cc, nn
  # jump if condition is met (16 cycles), otherwise do nothing (12 cycles)
  def jp_cc_nn(%Cpu{} = cpu, hw, cc) do
    {addr, cpu, hw} = Cpu.fetch_imm16(cpu, hw)
    if Cpu.check_condition(cpu, cc) do
      cpu = Map.put(cpu, :pc, addr)
      {cpu, Hardware.sync_cycle(hw)} # 4 extra cycles
    else
      {cpu, hw}
    end
  end

  @signed_table 0..255 |> Enum.map(fn x ->
    msb = x &&& 0x80
    if msb != 0, do: x ||| 0xff00, else: x
  end) |> List.to_tuple()
  # JR n
  # 12 cycles
  # Add i8 immediate value to current pc and jump
  def jr_n(%Cpu{} = cpu, hw) do
    # fetch immediate value first (increments pc)
    {offset, cpu, hw} = Cpu.fetch_imm8(cpu, hw)
    # IO.puts("jr +0x#{offset}")
    # addr = Cpu.read_register(cpu, :pc)
    addr = cpu.pc
    # offset = if msb != 0, do: (~~~offset + 1) &&& 0xffff, else: offset
    offset = elem(@signed_table, offset)
    cpu = Map.put(cpu, :pc, (addr + offset) &&& 0xffff)
    {cpu, Hardware.sync_cycle(hw)}
  end
  # JR cc, n
  # 12 cycles if condiiton is met, otherwise 8 cycels
  def jr_cc_n(%Cpu{} = cpu, hw, cc) do
    # fetch immediate value first (increments pc)
    {offset, cpu, hw} = Cpu.fetch_imm8(cpu, hw)
    # addr = Cpu.read_register(cpu, :pc)
    addr = cpu.pc
    if Cpu.check_condition(cpu, cc) do
      # msb = offset &&& 0x80
      # offset = if msb != 0, do: offset ||| 0xff00, else: offset
      offset = elem(@signed_table, offset)
      cpu = Map.put(cpu, :pc, (addr + offset) &&& 0xffff)
      {cpu, Hardware.sync_cycle(hw)} # 4 extra cycles
    else
      {cpu, hw}
    end
  end

  # Calls
  #
  # CALL nn
  # 24 cycles
  # push addresss of next instruction onto stack and jump to u16 immediate address value
  def call_nn(%Cpu{} = cpu, hw) do
    {addr, cpu, hw} = Cpu.fetch_imm16(cpu, hw)
    hw = Hardware.sync_cycle(hw) # 4 extra cycles
    {cpu, hw} = Cpu.push_u16(cpu, hw, cpu.pc)
    {Map.put(cpu, :pc, addr), hw}
  end
  # CALL cc, nn
  # 24 cycles if condition is met, otherwise 12 cycles
  def call_cc_nn(%Cpu{} = cpu, hw, cc) do
    {addr, cpu, hw} = Cpu.fetch_imm16(cpu, hw)
    if Cpu.check_condition(cpu, cc) do
      hw = Hardware.sync_cycle(hw) # 4 extra cycles
      {cpu, hw} = Cpu.push_u16(cpu, hw, cpu.pc)
      {Map.put(cpu, :pc, addr), hw}
    else
      {cpu, hw}
    end
  end

  # Restart
  # RST n
  # 16 cycles
  # Push current address onto stack, then jump to address n
  def rst(%Cpu{} = cpu, hw, n) do
    {cpu, hw} = Cpu.push_u16(cpu, hw, cpu.pc)
    cpu = Map.put(cpu, :pc, n &&& 0xffff)
    {cpu, Hardware.sync_cycle(hw)}
  end

  # Returns
  # RET
  # 16 cycles
  # pop two bytes from stack and jump to that address
  def ret(%Cpu{} = cpu, hw) do
    {addr, cpu, hw} = Cpu.pop_u16(cpu, hw)
    cpu = Map.put(cpu, :pc, addr)
    {cpu, Hardware.sync_cycle(hw)}
  end
  # RET cc
  # 20 cycls when condition is met, otherwise 8 cycles
  def ret_cc(%Cpu{} = cpu, hw, cc) do
    hw = Hardware.sync_cycle(hw)
    if Cpu.check_condition(cpu, cc) do
      {addr, cpu, hw} = Cpu.pop_u16(cpu, hw)
      cpu = Map.put(cpu, :pc, addr)
      {cpu, Hardware.sync_cycle(hw)}
    else
      {cpu, hw}
    end
  end
  # RETI
  # 16 cycles
  # Do return and enable interrupts right away (not delayed like EI)
  def reti(%Cpu{} = cpu, hw) do
    cpu = Map.put(cpu, :ime, true)
    {addr, cpu, hw} = Cpu.pop_u16(cpu, hw)
    cpu = Map.put(cpu, :sp, addr)
    {cpu, Hardware.sync_cycle(hw)}
  end

  def undefined(_cpu, _hw, opcode) do
    raise "Undefined opcode: #{Utils.to_hex(opcode)}"
  end

  def cb_undefined(_cpu, _hw, opcode) do
    raise "Undefined cb opcode: #{Utils.to_hex(opcode)}"
  end

end
