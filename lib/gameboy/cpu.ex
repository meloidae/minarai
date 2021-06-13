defmodule Gameboy.CPU do
  use Bitwise
  alias Gameboy.CPU
  alias Gameboy.HardwareInterface, as: HWI

  defmodule RegisterFile do
    defstruct af: 0x0000,
              bc: 0x0000,
              de: 0x0000,
              hl: 0x0000,
              pc: 0x0000,
              sp: 0x0000

  end

  defstruct regs: struct(RegisterFile),
            opcode: 0x0,
            ime: false,
            delayed_set_ime: nil, 
            state: :running

  defimpl Inspect, for: CPU do
    def inspect(cpu, _) do
      regs = cpu.regs
      to_str = fn x -> 
        digits = Integer.to_string(x, 16)
        num_zero = 8 - String.length(digits)
        if num_zero > 0, do: "#{String.duplicate("0", num_zero)}#{digits}", else: digits
      end
      "pc: #{to_str.(regs.pc)} sp: #{to_str.(regs.sp)} af: #{to_str.(regs.af)} bc: #{to_str.(regs.bc)} de: #{to_str.(regs.de)} hl: #{to_str.(regs.hl)}"
    end
  end


  def init do
    %CPU{}
  end

  # 16-bit reads from a register
  def read_register(%CPU{} = cpu, :af), do: cpu.regs.af
  def read_register(%CPU{} = cpu, :bc), do: cpu.regs.bc
  def read_register(%CPU{} = cpu, :de), do: cpu.regs.de
  def read_register(%CPU{} = cpu, :hl), do: cpu.regs.hl
  def read_register(%CPU{} = cpu, :pc), do: cpu.regs.pc
  def read_register(%CPU{} = cpu, :sp), do: cpu.regs.sp


  # 8 bit reads from a register
  def read_register(%CPU{} = cpu, :a), do: cpu.regs.af >>> 8 &&& 0xff
  def read_register(%CPU{} = cpu, :f), do: cpu.regs.af &&& 0xff
  def read_register(%CPU{} = cpu, :b), do: cpu.regs.bc >>> 8 &&& 0xff
  def read_register(%CPU{} = cpu, :c), do: cpu.regs.bc &&& 0xff
  def read_register(%CPU{} = cpu, :h), do: cpu.regs.hl >>> 8 &&& 0xff
  def read_register(%CPU{} = cpu, :l), do: cpu.regs.hl &&& 0xff


  # 16-bit writes to a register
  def write_register(%CPU{} = cpu, :af, data), do: put_in(cpu.regs.af, data)
  def write_register(%CPU{} = cpu, :bc, data), do: put_in(cpu.regs.bc, data)
  def write_register(%CPU{} = cpu, :de, data), do: put_in(cpu.regs.de, data)
  def write_register(%CPU{} = cpu, :hl, data), do: put_in(cpu.regs.hl, data)
  def write_register(%CPU{} = cpu, :pc, data), do: put_in(cpu.regs.pc, data)
  def write_register(%CPU{} = cpu, :sp, data), do: put_in(cpu.regs.sp, data)


  # 8-bit writes to a register
  def write_register(%CPU{} = cpu, :a, data) do
    value = ((data <<< 8) &&& 0xff00) ||| (cpu.regs.af &&& 0x00ff)
    put_in(cpu.regs.af, value)
  end
  def write_register(%CPU{} = cpu, :f, data) do
    value = (cpu.regs.af &&& 0xff00) ||| (data &&& 0x00ff)
    put_in(cpu.regs.af, value)
  end
  def write_register(%CPU{} = cpu, :b, data) do
    value = ((data <<< 8) &&& 0xff00) ||| (cpu.regs.bc &&& 0x00ff)
    put_in(cpu.regs.bc, value)
  end
  def write_register(%CPU{} = cpu, :c, data) do
    value = (cpu.regs.bc &&& 0xff00) ||| (data &&& 0x00ff)
    put_in(cpu.regs.bc, value)
  end
  def write_register(%CPU{} = cpu, :d, data) do
    value = ((data <<< 8) &&& 0xff00) ||| (cpu.regs.de &&& 0x00ff)
    put_in(cpu.regs.de, value)
  end
  def write_register(%CPU{} = cpu, :e, data) do
    value = (cpu.regs.de &&& 0xff00) ||| (data &&& 0x00ff)
    put_in(cpu.regs.de, value)
  end
  def write_register(%CPU{} = cpu, :h, data) do
    value = ((data <<< 8) &&& 0xff00) ||| (cpu.regs.hl &&& 0x00ff)
    put_in(cpu.regs.hl, value)
  end
  def write_register(%CPU{} = cpu, :l, data) do
    value = (cpu.regs.hl &&& 0xff00) ||| (data &&& 0x00ff)
    put_in(cpu.regs.hl, value)
  end


  # Set flags
  for {which_flag, offset} <- List.zip([[:z, :n, :h, :c], Enum.to_list(7..4)]) do
    true_val = 1 <<< offset
    false_val = bxor(0xff, true_val)
    def set_flag(%CPU{} = cpu, unquote(which_flag), true) do
      a = cpu.regs.af &&& 0xff00
      f = cpu.regs.af &&& 0x00ff
      f = f ||| unquote(true_val)
      put_in(cpu.regs.af, a ||| f)
    end

    def set_flag(%CPU{} = cpu, unquote(which_flag), false) do
      a = cpu.regs.af &&& 0xff00
      f = cpu.regs.af &&& 0x00ff
      f = f &&& unquote(false_val)
      put_in(cpu.regs.af, a ||| f)
    end

    def flag(%CPU{} = cpu, unquote(which_flag)), do: cpu.regs.af &&& unquote(true_val) != 0
  end

  # Check flag based on condition code
  def check_condition(%CPU{} = cpu, :nz), do: !flag(cpu, :z)
  def check_condition(%CPU{} = cpu, :z), do: flag(cpu, :z)
  def check_condition(%CPU{} = cpu, :nc), do: !flag(cpu, :c)
  def check_condition(%CPU{} = cpu, :c), do: flag(cpu, :c)


  # Add two u16 values, then get carries from bit 7 (carry) and bit 3 (half carry)
  def add_u16_byte_carry(a, b) do
    sum = (a + b) &&& 0xffff
    carry = ((a &&& 0xff) + (b &&& 0xff)) &&& 0x100 != 0
    half_carry = ((a &&& 0xf) + (b &&& 0xf)) &&& 0x10 != 0
    {sum, carry, half_carry}
  end
  def add_u16_byte_carry(a, b, _), do: add_u16_byte_carry(a, b)

  # Add two u16 values, then get carries from bit 15 (carry) and bit 11 (half carry)
  def add_u16_word_carry(a, b) do
    sum = (a + b) &&& 0xffff
    carry = (a + b) &&& 0x10000 != 0
    half_carry = ((a &&& 0xfff) + (b &&& 0xfff)) &&& 0x1000 != 0
    {sum, carry, half_carry}
  end
  def add_u16_word_carry(a, b, _), do: add_u16_word_carry(a, b)

  # Add two u8 values, then get carries from bit 7 (carry) and bit 3 (half carry)
  def add_u8_byte_carry(a, b) do
    sum = (a + b) &&& 0xff
    carry = (a + b) &&& 0x100 != 0
    half_carry = ((a &&& 0xf) + (b &&& 0xf)) &&& 0x10 != 0
    {sum, carry, half_carry}
  end
  def add_u8_byte_carry(a, b, _), do: add_u8_byte_carry(a, b)

  # Add two u8 values and c flag, then get carries from bit 7 (carry) and bit 3 (half carry)
  def adc_u8_byte_carry(a, b, %CPU{} = cpu) do
    c = if flag(cpu, :c), do: 1, else: 0
    sum = (a + b + c) &&& 0xff
    carry = (a + b + c) &&& 0x100 != 0
    half_carry = ((a &&& 0xf) + (b &&& 0xf) + c) &&& 0x10 != 0
    {sum, carry, half_carry}
  end

  # Sub u8 from u8, then get carries from bit 7 (carry) and bit 3 (half carry)
  def sub_u8_byte_carry(a, b) do
    diff = (a - b) &&& 0xff
    carry = a < b
    half_carry = (a &&& 0xf) < (b &&& 0xf)
    {diff, carry, half_carry}
  end
  def sub_u8_byte_carry(a, b, _), do: sub_u8_byte_carry(a, b)

  # Sub u8 and c flag from u8, then get carries from bit 7 (carry) and bit 3 (half carry)
  def sbc_u8_byte_carry(a, b, %CPU{} = cpu) do
    c = if flag(cpu, :c), do: 1, else: 0
    diff = (a - b - c) &&& 0xff
    carry = a < (b + c)
    half_carry = (a &&& 0xf) < ((b &&& 0xf) + c)
    {diff, carry, half_carry}
  end

  # Rotate u8 value to left, old bit 7 to carry
  def rlc_u8_byte_carry(value) do
    carry = value &&& 0x80 != 0
    value = if carry, do: (value <<< 1) ||| 0x1, else: value <<< 1
    value = value &&& 0xff
    {value, carry}
  end
  def rlc_u8_byte_carry(value, _), do: rlc_u8_byte_carry(value)

  # Roate u8 value to left through carry flag, old bit 7 to carry
  def rl_u8_byte_carry(value, %CPU{} = cpu) do
    carry = value &&& 0x80 != 0
    value = if flag(cpu, :c), do: (value <<< 1) ||| 0x1, else: value <<< 1
    value = value &&& 0xff
    {value, carry}
  end

  # Rotate u8 value to right, old bit 0 to carry
  def rrc_u8_byte_carry(value) do
    carry = value &&& 0x1 != 0
    value = if carry, do: (value >>> 1) ||| 0x80, else: value >>> 1
    value = value &&& 0xff
    {value, carry}
  end
  def rrc_u8_byte_carry(value, _), do: rrc_u8_byte_carry(value)

  # Rotate u8 value to right through carry flag, old bit 0 to carry
  def rr_u8_byte_carry(value, %CPU{} = cpu) do
    carry = value &&& 0x1 != 0
    value = if flag(cpu, :c), do: (value >>> 1) ||| 0x80, else: value >>> 1
    value = value &&& 0xff
    {value, carry}
  end

  # Shift u8 value to left, lsb is set to 0
  def sla_u8_byte_carry(value) do
    carry = value &&& 0x80 != 0
    value = (value <<< 1) &&& 0xff
    {value, carry}
  end
  def sla_u8_byte_carry(value, _), do: sla_u8_byte_carry(value)

  # Shift u8 value to right, msb doesn't change
  def sra_u8_byte_carry(value) do
    carry = value &&& 0x1 != 0
    msb = value &&& 0x80
    value = (value >>> 1) ||| msb
    {value, carry}
  end
  def sra_u8_byte_carry(value, _), do: sra_u8_byte_carry(value)

  # Shift u8 value to right, msb is set to 0
  def srl_u8_byte_carry(value) do
    carry = value &&& 0x1 != 0
    value = value >>> 1
    {value, carry}
  end
  def srl_u8_byte_carry(value, _), do: srl_u8_byte_carry(value)


  # Fetch 8 bit value at pc. Returns tuple of {value, cpu} as pc is incremented
  def fetch_imm8(%CPU{} = cpu, hw) do
    addr = cpu.regs.pc
    {HWI.synced_read(hw, addr), write_register(cpu, :pc, (addr + 1) &&& 0xffff)}
  end

  # Fetch 16 bit value at pc. Returns tuple of {value, cpu} as pc is incremented
  def fetch_imm16(%CPU{} = cpu, hw) do
    {low, cpu} = fetch_imm8(cpu, hw)
    {high, cpu} = fetch_imm8(cpu, hw)
    value = ((high <<< 8) &&& 0xff00) ||| (low &&& 0x00ff)
    {value, cpu}
  end

  # Push 16 bit to value to stack
  def push_u16(%CPU{} = cpu, hw, data) do
    low = data &&& 0xff
    high = (data >>> 8) &&& 0xff
    sp = CPU.read_register(cpu, :sp)
    sp = (sp - 1) &&& 0xffff
    HWI.synced_write(hw, sp, high)
    sp = (sp - 1) &&& 0xffff
    HWI.synced_write(hw, sp, low)
    CPU.write_register(cpu, :sp, sp)
  end

  # Pop 16 bit value from stack
  def pop_u16(%CPU{} = cpu, hw) do
    sp = CPU.read_register(cpu, :sp)
    low = HWI.synced_read(hw, sp)
    sp = (sp + 1) &&& 0xffff
    high = HWI.synced_read(hw, sp)
    sp = (sp + 1) &&& 0xffff
    {(high <<< 8) ||| low, CPU.write_register(cpu, :sp, sp)}
  end

  # read for a single register
  for reg <- [:a, :f, :b, :c, :d, :e, :h, :l] do
    def read(%CPU{} = cpu, unquote(reg), _), do: {read_register(cpu, unquote(reg)), cpu}
  end

  # read for an 8-bit immediate value (no write)
  def read(%CPU{} = cpu, :imm, hw), do: fetch_imm8(cpu, hw)

  # read for addr (16 bit registers or immediate address)
  # reading from/writing to an address involves memory access == synced read/write
  for reg <- [:bc, :de, :hl] do
    def read(%CPU{} = cpu, unquote(reg), hw) do
      addr = read_register(cpu, unquote(reg))
      {HWI.synced_read(hw, addr), cpu}
    end
  end

  # read to HL and decrement/increment HL. Decrement/increment after addr is used
  def read(%CPU{} = cpu, :hld, hw) do
    addr = read_register(cpu, :hl)
    cpu = write_register(cpu, :hl, (addr - 1) &&& 0xffff)  # wrapping sub
    {HWI.synced_read(hw, addr), cpu}
  end

  def read(%CPU{} = cpu, :hli, hw) do
    addr = read_register(cpu, :hl)
    cpu = write_register(cpu, :hl, (addr + 1) &&& 0xffff)  # wrapping add
    {HWI.synced_read(hw, addr), cpu}
  end

  # read for immediate addr
  def read(%CPU{} = cpu, :immaddr, hw) do
    {addr, cpu} = fetch_imm16(cpu, hw)
    {HWI.synced_read(hw, addr), cpu}
  end

  # read for high address (uses 8 bit immediate value for addr)
  def read(%CPU{} = cpu, :hi, hw) do
    {addr, cpu} = fetch_imm8(cpu, hw)
    addr = 0xff00 ||| addr
    {HWI.synced_read(hw, addr), cpu}
  end

  # read for high address but address is taken from c
  def read(%CPU{} = cpu, :hic, hw) do
    addr = read_register(cpu, :c)
    addr = 0xff00 ||| addr
    {HWI.synced_read(hw, addr), cpu}
  end


  # write for a single register
  for reg <- [:a, :f, :b, :c, :d, :e, :h, :l] do
    def write(%CPU{} = cpu, unquote(reg), _, data), do: write_register(cpu, unquote(reg), data)
  end

  # write for addr (16 bit registers or immediate address)
  for reg <- [:bc, :de, :hl] do
    def write(%CPU{} = cpu, unquote(reg), hw, data) do
      addr = read_register(cpu, unquote(reg))
      HWI.synced_write(hw, addr, data)
      cpu
    end
  end

  # write to HL and decrement/increment HL. Decrement/increment after addr is used
  def write(%CPU{} = cpu, :hld, hw, data) do
    addr = read_register(cpu, :hl)
    cpu = write_register(cpu, :hl, (addr - 1) &&& 0xffff)  # wrapping sub
    HWI.synced_write(hw, addr, data)
    cpu
  end

  def write(%CPU{} = cpu, :hli, hw, data) do
    addr = read_register(cpu, :hl)
    cpu = write_register(cpu, :hl, (addr + 1) &&& 0xffff)  # wrapping add
    HWI.synced_write(hw, addr, data)
    cpu
  end

  # write for immediate addr
  def write(%CPU{} = cpu, :immaddr, hw, data) do
    {addr, cpu} = fetch_imm16(cpu, hw)
    HWI.synced_write(hw, addr, data)
    cpu
  end

  # write for high address (uses 8 bit immediate value for addr)
  def write(%CPU{} = cpu, :hi, hw, data) do
    {addr, cpu} = fetch_imm8(cpu, hw)
    addr = 0xff00 ||| addr
    HWI.synced_write(hw, addr, data)
    cpu
  end

  # write for high address but address is taken from c
  def write(%CPU{} = cpu, :hic, hw, data) do
    addr = read_register(cpu, :c)
    addr = 0xff00 ||| addr
    HWI.synced_write(hw, addr, data)
    cpu
  end

end
