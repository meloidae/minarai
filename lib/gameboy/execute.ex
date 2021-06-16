defmodule Gameboy.Execute do
  use Bitwise
  alias Gameboy.CPU
  alias Gameboy.HardwareInterface, as: HWI
  alias Gameboy.Utils

  # 8 bit load
  def ld(%CPU{} = cpu, hw, dst, src) do
    {value, cpu, hw} = CPU.read(cpu, src, hw)
    CPU.write(cpu, dst, hw, value)
  end

  # 16 bit loads
  # LD rr, nn
  # 12 cycles
  def ld16_rr_nn(%CPU{} = cpu, hw, reg16) do
    {value, cpu, hw} = CPU.fetch_imm16(cpu, hw)
    {CPU.write_register(cpu, reg16, value), hw}
  end

  # LD SP, HL
  # 8 cycles
  def ld16_sp_hl(%CPU{} = cpu, hw) do
    value = CPU.read_register(cpu, :hl)
    cpu = CPU.write_register(cpu, :sp, value)
    {cpu, HWI.sync_cycle(hw)} # Add 4 extra cycles
  end

  # LDHL SP, n
  # 12 cycles
  def ld16_hl_sp_n(%CPU{} = cpu, hw) do
    sp = CPU.read_register(cpu, :sp)
    {offset, cpu, hw} = CPU.fetch_imm8(cpu, hw)
    {value, carry, half_carry} = CPU.add_u16_byte_carry(sp, offset)
    cpu = CPU.write_register(cpu, :hl, value)
          |> CPU.set_flag(:z, false)
          |> CPU.set_flag(:n, false)
          |> CPU.set_flag(:h, half_carry)
          |> CPU.set_flag(:c, carry)
    {cpu, HWI.sync_cycle(hw)} # Add 4 extra cycles
  end

  # LD (nn), SP
  # 20 cycles
  def ld16_nn_sp(%CPU{} = cpu, hw) do
    value = CPU.read_register(cpu, :sp)
    {addr, cpu, hw} = CPU.fetch_imm16(cpu, hw)
    hw = HWI.synced_write(hw, addr, value &&& 0xff)
    {cpu, HWI.synced_write(hw, (addr + 1) &&& 0xffff, (value >>> 8) &&& 0xff)}
  end

  # PUSH rr
  # 16 cycles
  def push16_rr(%CPU{} = cpu, hw, reg16) do
    value = CPU.read_register(cpu, reg16)
    hw = HWI.sync_cycle(hw) # Add 4 extra cycles
    CPU.push_u16(cpu, hw, value)
  end

  # POP rr
  # 12 cycles
  def pop16_rr(%CPU{} = cpu, hw, reg16) do
    {value, cpu, hw} = CPU.pop_u16(cpu, hw)
    {CPU.write_register(cpu, reg16, value), hw}
  end

  # Addtions
  defp _add(%CPU{} = cpu, hw, dst, src, add_fn) do
    {val1, cpu, hw} = CPU.read(cpu, dst, hw)
    {val2, cpu, hw} = CPU.read(cpu, src, hw)
    {sum, carry, half_carry} = add_fn.(val1, val2, cpu)
    {cpu, hw} = CPU.write(cpu, dst, hw, sum)
    cpu = CPU.set_flag(cpu, :z, sum == 0)
    |> CPU.set_flag(:n, false)
    |> CPU.set_flag(:h, half_carry)
    |> CPU.set_flag(:c, carry)
    {cpu, hw}
  end
  # ADD dd, ss
  def add(%CPU{} = cpu, hw, dst, src), do: _add(cpu, hw, dst, src, &CPU.add_u8_byte_carry/3)
  # ADC dd, ss
  def adc(%CPU{} = cpu, hw, dst, src), do: _add(cpu, hw, dst, src, &CPU.adc_u8_byte_carry/3)


  # Subtractions
  defp _sub(%CPU{} = cpu, hw, dst, src, sub_fn) do
    {val1, cpu, hw} = CPU.read(cpu, dst, hw)
    {val2, cpu, hw} = CPU.read(cpu, src, hw)
    {diff, carry, half_carry} = sub_fn.(val1, val2, cpu)
    {cpu, hw} = CPU.write(cpu, dst, hw, diff)
    cpu = CPU.set_flag(cpu, :z, diff == 0)
    |> CPU.set_flag(:n, true)
    |> CPU.set_flag(:h, half_carry)
    |> CPU.set_flag(:c, carry)
    {cpu, hw}
  end
  # SUB dd, ss
  def sub(%CPU{} = cpu, hw, dst, src), do: _sub(cpu, hw, dst, src, &CPU.sub_u8_byte_carry/3)
  def sbc(%CPU{} = cpu, hw, dst, src), do: _sub(cpu, hw, dst, src, &CPU.sbc_u8_byte_carry/3)

  # AND dd, ss
  def and_op(%CPU{} = cpu, hw, dst, src) do
    {val1, cpu, hw} = CPU.read(cpu, dst, hw)
    {val2, cpu, hw} = CPU.read(cpu, src, hw)
    result = val1 &&& val2
    {cpu, hw} = CPU.write(cpu, dst, hw, result)
    cpu = CPU.set_flag(cpu, :z, result == 0)
    |> CPU.set_flag(:n, false)
    |> CPU.set_flag(:h, true)
    |> CPU.set_flag(:c, false)
    {cpu, hw}
  end

  # OR dd, ss
  def or_op(%CPU{} = cpu, hw, dst, src) do
    {val1, cpu, hw} = CPU.read(cpu, dst, hw)
    {val2, cpu, hw} = CPU.read(cpu, src, hw)
    result = val1 ||| val2
    {cpu, hw} = CPU.write(cpu, dst, hw, result)
    cpu = CPU.set_flag(cpu, :z, result == 0)
    |> CPU.set_flag(:n, false)
    |> CPU.set_flag(:h, false)
    |> CPU.set_flag(:c, false)
    {cpu, hw}
  end

  # XOR dd, ss
  def xor(%CPU{} = cpu, hw, dst, src) do
    {val1, cpu, hw} = CPU.read(cpu, dst, hw)
    {val2, cpu, hw} = CPU.read(cpu, src, hw)
    result = bxor(val1, val2)
    {cpu, hw} = CPU.write(cpu, dst, hw, result)
    cpu = CPU.set_flag(cpu, :z, result == 0)
    |> CPU.set_flag(:n, false)
    |> CPU.set_flag(:h, false)
    |> CPU.set_flag(:c, false)
    {cpu, hw}
  end

  # CP dd, ss
  def cp(%CPU{} = cpu, hw, dst, src) do
    {val1, cpu, hw} = CPU.read(cpu, dst, hw)
    {val2, cpu, hw} = CPU.read(cpu, src, hw)
    {diff, carry, half_carry} = CPU.sub_u8_byte_carry(val1, val2)
    cpu = CPU.set_flag(cpu, :z, diff == 0)
    |> CPU.set_flag(:n, true)
    |> CPU.set_flag(:h, half_carry)
    |> CPU.set_flag(:c, carry)
    {cpu, hw}
  end

  # INC d
  def inc(%CPU{} = cpu, hw, dst) do
    {value, cpu, hw} = CPU.read(cpu, dst, hw)
    {sum, _carry, half_carry} = CPU.add_u8_byte_carry(value, 1)
    CPU.set_flag(cpu, :z, sum == 0)
    |> CPU.set_flag(:n, false)
    |> CPU.set_flag(:h, half_carry)
    |> CPU.write(dst, hw, sum)
  end

  # DEC d
  def dec(%CPU{} = cpu, hw, dst) do
    {value, cpu, hw} = CPU.read(cpu, dst, hw)
    {diff, _carry, half_carry} = CPU.sub_u8_byte_carry(value, 1)
    CPU.set_flag(cpu, :z, diff == 0)
    |> CPU.set_flag(:n, true)
    |> CPU.set_flag(:h, half_carry)
    |> CPU.write(dst, hw, diff)
  end


  # 16-bit arithmetic
  #
  # ADD HL, rr
  # 8 cycles
  # z flag is not affected
  def add16_hl_rr(%CPU{} = cpu, hw, reg16) do
    hl = CPU.read_register(cpu, :hl)
    val = CPU.read_register(cpu, reg16)
    {sum, carry, half_carry} = CPU.add_u16_word_carry(hl, val)
    cpu = CPU.write_register(cpu, :hl, sum)
          |> CPU.set_flag(:n, false)
          |> CPU.set_flag(:h, half_carry)
          |> CPU.set_flag(:c, carry)
    {cpu, HWI.sync_cycle(hw)} # Add 4 extra cycles
  end

  # ADD SP, n
  # 16 cycles
  def add16_sp_n(%CPU{} = cpu, hw) do
    {offset, cpu, hw} = CPU.fetch_imm8(cpu, hw)
    sp = CPU.read_register(cpu, :sp)
    {sum, carry, half_carry} = CPU.add_u16_byte_carry(sp, offset)
    cpu = CPU.write_register(cpu, :sp, sum)
          |> CPU.set_flag(:z, false)
          |> CPU.set_flag(:n, false)
          |> CPU.set_flag(:h, half_carry)
          |> CPU.set_flag(:c, carry)
    # Add 8 extra cycles
    {cpu, HWI.sync_cycle(hw) |> HWI.sync_cycle()}
  end

  # INC rr
  # 8 cycles
  def inc16_rr(%CPU{} = cpu, hw, reg16) do
    value = CPU.read_register(cpu, reg16)
    cpu = CPU.write_register(cpu, reg16, (value + 1) &&& 0xffff)
    {cpu, HWI.sync_cycle(hw)} # Add 4 extra cycles
  end

  # DEC rr
  # 8 cycles
  def dec16_rr(%CPU{} = cpu, hw, reg16) do
    value = CPU.read_register(cpu, reg16)
    cpu = CPU.write_register(cpu, reg16, (value - 1) &&& 0xffff)
    {cpu, HWI.sync_cycle(hw)} # Add 4 extra cycles
  end

  # Miscellaneous instructions
  #
  # SWAP dd
  # dd is either 8-bit register or address in HL
  # Swaps lower bit higher bit of dst
  def swap(%CPU{} = cpu, hw, dst) do
    {value, cpu, hw} = CPU.read(cpu, dst, hw)
    value = ((value &&& 0x0f) <<< 4) ||| ((value &&& 0xf0) >>> 4)
    CPU.set_flag(cpu, :z, value == 0)
    |> CPU.set_flag(:n, false)
    |> CPU.set_flag(:h, false)
    |> CPU.set_flag(:c, false)
    |> CPU.write(dst, hw, value)
  end

  # DAA
  # 4 cycles
  # decimal adjust register A
  def daa(%CPU{} = cpu, hw) do
    a = CPU.read_register(cpu, :a)
    c = CPU.flag(cpu, :c)
    h = CPU.flag(cpu, :h)
    {carry, a} = if !CPU.flag(cpu, :n) do # After add/adc
      {carry, a} = if c ||| a > 0x99, do: {true, (a + 0x60) &&& 0xff}, else: {false, a}
      a = if h ||| (a &&& 0x0f) > 0x09, do: (a + 0x06) &&& 0xff, else: a
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
    cpu = CPU.write_register(cpu, :a, a)
    |> CPU.set_flag(:z, a == 0)
    |> CPU.set_flag(:h, false)
    |> CPU.set_flag(:c, carry)
    {cpu, hw}
  end

  # CPL
  # 4 cycles
  # Take complement (flip bits of) A register
  def cpl(%CPU{} = cpu, hw) do
    a = CPU.read_register(cpu, :a)
    cpu = CPU.write_register(cpu, :a, ~~~a &&& 0xff)
    |> CPU.set_flag(:n, true)
    |> CPU.set_flag(:h, true)
    {cpu, hw}
  end

  # CCF
  # 4 cycles
  # Complement a carry flag
  def ccf(%CPU{} = cpu, hw) do
    carry = CPU.flag(cpu, :c)
    cpu = CPU.set_flag(cpu, :c, !carry)
    |> CPU.set_flag(:n, false)
    |> CPU.set_flag(:h, false)
    {cpu, hw}
  end

  # SCF
  # 4 cycles
  # Set a carry flag
  def scf(%CPU{} = cpu, hw) do
    cpu = CPU.set_flag(cpu, :c, true)
    |> CPU.set_flag(:n, false)
    |> CPU.set_flag(:h, false)
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
  def halt(%CPU{} = cpu, hw) do
    {cpu, hw}
  end

  # STOP
  # 4 cycles
  # raise error fo now
  def stop(%CPU{} = cpu, hw) do
    {cpu, hw}
  end

  # DI
  # 4 cycles
  # Disable interrupt immediately (unlike how ei is delayed)
  def di(%CPU{} = cpu, hw) do
    {put_in(cpu.ime, false), hw}
  end

  # EI
  # 4 cycles
  # Enable interrupt (but is delayed)
  def ei(%CPU{} = cpu, hw) do
    {put_in(cpu.delayed_set_ime, true), hw}
  end

  # Rotation/Shifts
  def _shift(%CPU{} = cpu, hw, dst, shift_fn) do
    {value, cpu, hw} = CPU.read(cpu, dst, hw)
    {value, carry} = shift_fn.(value, cpu)
    CPU.set_flag(cpu, :z, value == 0)
    |> CPU.set_flag(:n, false)
    |> CPU.set_flag(:h, false)
    |> CPU.set_flag(:c, carry)
    |> CPU.write(dst, hw, value)
  end
  # RLC dd
  # 2-byte opcode (+ 4 cycles) unless it's RLCA (1-byte opcode)
  # rotate left
  def rlc(%CPU{} = cpu, hw, dst), do: _shift(cpu, hw, dst, &CPU.rlc_u8_byte_carry/2)
  # RL dd
  # 2-byte opcode (+ 4 cycles), unless RLA
  # rotate left through carry
  def rl(%CPU{} = cpu, hw, dst), do: _shift(cpu, hw, dst, &CPU.rl_u8_byte_carry/2)
  # RRC dd
  # 2-byte opcode (+ 4 cycles), unless it's RRCA (1-byte opcode)
  # rorate right
  def rrc(%CPU{} = cpu, hw, dst), do: _shift(cpu, hw, dst, &CPU.rrc_u8_byte_carry/2)
  # RR dd
  # 2-byte opcode (+ 4 cycles), unless it's RRCA (1-byte opcode)
  # rorate right through carry
  def rr(%CPU{} = cpu, hw, dst), do: _shift(cpu, hw, dst, &CPU.rr_u8_byte_carry/2)
  # SLA dd
  # 2-byte opcode (+ 4 cycles)
  # shift left
  def sla(%CPU{} = cpu, hw, dst), do: _shift(cpu, hw, dst, &CPU.sla_u8_byte_carry/2)
  # SRA dd
  # 2-byte opcode (+ 4 cycles)
  # shift right, msb doesn't change
  def sra(%CPU{} = cpu, hw, dst), do: _shift(cpu, hw, dst, &CPU.sra_u8_byte_carry/2)
  # SRL dd
  # 2-byte opcode (+ 4 cycles)
  # shift right, msb is set to 0
  def srl(%CPU{} = cpu, hw, dst), do: _shift(cpu, hw, dst, &CPU.srl_u8_byte_carry/2)

  # Bit instructions
  #
  # BIT b, dd
  # 2-byte opcode (+ 4 cycles)
  # Test bit b of dst
  def bit(%CPU{} = cpu, hw, bit, dst) do
    {value, cpu, hw} = CPU.read(cpu, dst, hw)
    value = value &&& (0x1 <<< bit)
    cpu = CPU.set_flag(cpu, :z, value == 0)
    |> CPU.set_flag(:n, false)
    |> CPU.set_flag(:h, true)
    {cpu, hw}
  end
  # SET b, dd
  # 2-byte opcode (+ 4 cycles)
  # Set bit b of dst, flags are unaffected
  def set(%CPU{} = cpu, hw, bit, dst) do
    {value, cpu, hw} = CPU.read(cpu, dst, hw)
    value = value ||| (0x1 <<< bit)
    CPU.write(cpu, dst, hw, value)
  end
  # RES b, dd
  # 2-byte opcode (+ 4 cycles)
  # Reset bit b of dst, flags are unaffected
  def res(%CPU{} = cpu, hw, bit, dst) do
    {value, cpu, hw} = CPU.read(cpu, dst, hw)
    value = value &&& ~~~(0x1 <<< bit)
    CPU.write(cpu, dst, hw, value)
  end

  # Jumps
  #
  # JP nn
  # 16 cycles
  # jump using immediate u16 value
  def jp_nn(%CPU{} = cpu, hw) do
    {addr, cpu, hw} = CPU.fetch_imm16(cpu, hw)
    cpu = CPU.write_register(cpu, :pc, addr)
    {cpu, HWI.sync_cycle(hw)}
  end
  # JP hl
  # 4 cycles
  # jump to address stored in HL register
  def jp_hl(%CPU{} = cpu, hw) do
    addr = CPU.read_register(cpu, :hl)
    {CPU.write_register(cpu, :pc, addr), hw}
  end
  # JP cc, nn
  # jump if condition is met (16 cycles), otherwise do nothing (12 cycles)
  def jp_cc_nn(%CPU{} = cpu, hw, cc) do
    {addr, cpu, hw} = CPU.fetch_imm16(cpu, hw)
    if CPU.check_condition(cpu, cc) do
      cpu = CPU.write_register(cpu, :pc, addr)
      {cpu, HWI.sync_cycle(hw)} # 4 extra cycles
    else
      {cpu, hw}
    end
  end
  # JR n
  # 12 cycles
  # Add i8 immediate value to current pc and jump
  def jr_n(%CPU{} = cpu, hw) do
    # fetch immediate value first (increments pc)
    {offset, cpu, hw} = CPU.fetch_imm8(cpu, hw)
    addr = CPU.read_register(cpu, :pc)
    msb = offset &&& 0x80
    offset = if msb != 0, do: (~~~offset + 1) &&& 0xffff, else: offset
    cpu = CPU.write_register(cpu, :pc, (addr + offset) && 0xffff)
    {cpu, HWI.sync_cycle(hw)}
  end
  # JR cc, n
  # 12 cycles if condiiton is met, otherwise 8 cycels
  def jr_cc_n(%CPU{} = cpu, hw, cc) do
    # fetch immediate value first (increments pc)
    {offset, cpu, hw} = CPU.fetch_imm8(cpu, hw)
    addr = CPU.read_register(cpu, :pc)
    IO.puts("offset: #{Utils.to_hex(offset)}")
    if CPU.check_condition(cpu, cc) do
      msb = offset &&& 0x80
      offset = if msb != 0, do: offset ||| 0xff00, else: offset
      IO.puts("addr: #{Utils.to_hex(addr)}, offset: #{Utils.to_hex(offset)}, addr+offset = #{Utils.to_hex((addr + offset) &&& 0xffff)}")
      cpu = CPU.write_register(cpu, :pc, (addr + offset) &&& 0xffff)
      {cpu, HWI.sync_cycle(hw)} # 4 extra cycles
    else
      {cpu, hw}
    end
  end

  # Calls
  #
  # CALL nn
  # 24 cycles
  # push addresss of next instruction onto stack and jump to u16 immediate address value
  def call_nn(%CPU{} = cpu, hw) do
    {addr, cpu, hw} = CPU.fetch_imm16(cpu, hw)
    hw = HWI.sync_cycle(hw) # 4 extra cycles
    {cpu, hw} = CPU.push_u16(cpu, hw, CPU.read_register(cpu, :pc))
    {CPU.write_register(cpu, :pc, addr), hw}
  end
  # CALL cc, nn
  # 24 cycles if condition is met, otherwise 12 cycles
  def call_cc_nn(%CPU{} = cpu, hw, cc) do
    {addr, cpu, hw} = CPU.fetch_imm16(cpu, hw)
    if CPU.check_condition(cpu, cc) do
      hw = HWI.sync_cycle(hw) # 4 extra cycles
      {cpu, hw} = CPU.push_u16(cpu, hw, CPU.read_register(cpu, :pc))
      {CPU.write_register(cpu, :pc, addr), hw}
    else
      {cpu, hw}
    end
  end

  # Restart
  # RST n
  # 16 cycles
  # Push current address onto stack, then jump to address n
  def rst(%CPU{} = cpu, hw, n) do
    {cpu, hw} = CPU.push_u16(cpu, hw, CPU.read_register(cpu, :pc))
    cpu = CPU.write_register(cpu, :pc, n &&& 0xffff)
    {cpu, HWI.sync_cycle(hw)}
  end

  # Returns
  # RET
  # 16 cycles
  # pop two bytes from stack and jump to that address
  def ret(%CPU{} = cpu, hw) do
    {addr, cpu, hw} = CPU.pop_u16(cpu, hw)
    cpu = CPU.write_register(cpu, :pc, addr)
    {cpu, HWI.sync_cycle(hw)}
  end
  # RET cc
  # 20 cycls when condition is met, otherwise 8 cycles
  def ret_cc(%CPU{} = cpu, hw, cc) do
    hw = HWI.sync_cycle(hw)
    if CPU.check_condition(cpu, cc) do
      {addr, cpu, hw} = CPU.pop_u16(cpu, hw)
      cpu = CPU.write_register(cpu, :pc, addr)
      {cpu, HWI.sync_cycle(hw)}
    else
      {cpu, hw}
    end
  end
  # RETI
  # 16 cycles
  # Do return and enable interrupts right away (not delayed like EI)
  def reti(%CPU{} = cpu, hw) do
    cpu = put_in(cpu.ime, true)
    {addr, cpu, hw} = CPU.pop_u16(cpu, hw)
    cpu = CPU.write_register(cpu, :sp, addr)
    {cpu, HWI.sync_cycle(hw)}
  end

end
