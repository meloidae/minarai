defmodule Gameboy.Cpu do
  use Bitwise
  alias Gameboy.Cpu
  alias Gameboy.Hardware
  alias Gameboy.Utils

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

  defimpl Inspect, for: Cpu do
    def inspect(cpu, _) do
      regs = cpu.regs
      "pc: #{Utils.to_hex(regs.pc)} op: #{Utils.to_hex(cpu.opcode)} sp: #{Utils.to_hex(regs.sp)} af: #{Utils.to_hex(regs.af)} bc: #{Utils.to_hex(regs.bc)} de: #{Utils.to_hex(regs.de)} hl: #{Utils.to_hex(regs.hl)}"
    end
  end


  def init do
    %Cpu{}
  end

  # Fetch opcode for instruction and increment pc
  def fetch_next(%Cpu{} = cpu, hw, addr) do
    {opcode, hw} = Hardware.synced_read(hw, addr)
    {write_register(Map.put(cpu, :opcode opcode), :pc, (addr + 1) &&& 0xffff), hw}
  end

  # handle interrupt
  # TODO
  def handle_interrupt(%Cpu{} = cpu, hw) do
    {cpu, hw}
  end


  # 16-bit reads from a register
  def read_register(%Cpu{} = cpu, :af), do: cpu.regs.af
  def read_register(%Cpu{} = cpu, :bc), do: cpu.regs.bc
  def read_register(%Cpu{} = cpu, :de), do: cpu.regs.de
  def read_register(%Cpu{} = cpu, :hl), do: cpu.regs.hl
  def read_register(%Cpu{} = cpu, :pc), do: cpu.regs.pc
  def read_register(%Cpu{} = cpu, :sp), do: cpu.regs.sp


  # 8 bit reads from a register
  def read_register(%Cpu{} = cpu, :a), do: (cpu.regs.af >>> 8) &&& 0xff
  def read_register(%Cpu{} = cpu, :f), do: cpu.regs.af &&& 0xff
  def read_register(%Cpu{} = cpu, :b), do: (cpu.regs.bc >>> 8) &&& 0xff
  def read_register(%Cpu{} = cpu, :c), do: cpu.regs.bc &&& 0xff
  def read_register(%Cpu{} = cpu, :d), do: (cpu.regs.de >>> 8) &&& 0xff
  def read_register(%Cpu{} = cpu, :e), do: cpu.regs.de &&& 0xff
  def read_register(%Cpu{} = cpu, :h), do: (cpu.regs.hl >>> 8) &&& 0xff
  def read_register(%Cpu{} = cpu, :l), do: cpu.regs.hl &&& 0xff


  # 16-bit writes to a register
  def write_register(%Cpu{} = cpu, :af, data), do: put_in(cpu.regs.af, data)
  def write_register(%Cpu{} = cpu, :bc, data), do: put_in(cpu.regs.bc, data)
  def write_register(%Cpu{} = cpu, :de, data), do: put_in(cpu.regs.de, data)
  def write_register(%Cpu{} = cpu, :hl, data), do: put_in(cpu.regs.hl, data)
  def write_register(%Cpu{} = cpu, :pc, data), do: put_in(cpu.regs.pc, data)
  def write_register(%Cpu{} = cpu, :sp, data), do: put_in(cpu.regs.sp, data)


  # 8-bit writes to a register
  def write_register(%Cpu{} = cpu, :a, data) do
    value = ((data <<< 8) &&& 0xff00) ||| (cpu.regs.af &&& 0x00ff)
    put_in(cpu.regs.af, value)
  end
  def write_register(%Cpu{} = cpu, :f, data) do
    value = (cpu.regs.af &&& 0xff00) ||| (data &&& 0x00ff)
    put_in(cpu.regs.af, value)
  end
  def write_register(%Cpu{} = cpu, :b, data) do
    value = ((data <<< 8) &&& 0xff00) ||| (cpu.regs.bc &&& 0x00ff)
    put_in(cpu.regs.bc, value)
  end
  def write_register(%Cpu{} = cpu, :c, data) do
    value = (cpu.regs.bc &&& 0xff00) ||| (data &&& 0x00ff)
    put_in(cpu.regs.bc, value)
  end
  def write_register(%Cpu{} = cpu, :d, data) do
    value = ((data <<< 8) &&& 0xff00) ||| (cpu.regs.de &&& 0x00ff)
    put_in(cpu.regs.de, value)
  end
  def write_register(%Cpu{} = cpu, :e, data) do
    value = (cpu.regs.de &&& 0xff00) ||| (data &&& 0x00ff)
    put_in(cpu.regs.de, value)
  end
  def write_register(%Cpu{} = cpu, :h, data) do
    value = ((data <<< 8) &&& 0xff00) ||| (cpu.regs.hl &&& 0x00ff)
    put_in(cpu.regs.hl, value)
  end
  def write_register(%Cpu{} = cpu, :l, data) do
    value = (cpu.regs.hl &&& 0xff00) ||| (data &&& 0x00ff)
    put_in(cpu.regs.hl, value)
  end

  # Set/Get flags
  for {which_flag, offset} <- List.zip([[:z, :n, :h, :c], Enum.to_list(7..4)]) do
    true_val = 1 <<< offset
    false_val = bxor(0xff, true_val)
    def set_flag(%Cpu{} = cpu, unquote(which_flag), true) do
      a = cpu.regs.af &&& 0xff00
      f = cpu.regs.af &&& 0x00ff
      f = f ||| unquote(true_val)
      put_in(cpu.regs.af, a ||| f)
    end

    def set_flag(%Cpu{} = cpu, unquote(which_flag), false) do
      a = cpu.regs.af &&& 0xff00
      f = cpu.regs.af &&& 0x00ff
      f = f &&& unquote(false_val)
      put_in(cpu.regs.af, a ||| f)
    end

    def flag(%Cpu{} = cpu, unquote(which_flag) = fl) do
      # IO.puts("flag: #{fl}, true_val: #{unquote(true_val)}")
      (cpu.regs.af &&& unquote(true_val)) != 0
    end
  end

  # Check flag based on condition code
  def check_condition(%Cpu{} = cpu, :nz), do: !flag(cpu, :z)
  def check_condition(%Cpu{} = cpu, :z), do: flag(cpu, :z)
  def check_condition(%Cpu{} = cpu, :nc), do: !flag(cpu, :c)
  def check_condition(%Cpu{} = cpu, :c), do: flag(cpu, :c)


  # Add two u16 values, then get carries from bit 7 (carry) and bit 3 (half carry)
  def add_u16_byte_carry(a, b) do
    sum = (a + b) &&& 0xffff
    carry = (((a &&& 0xff) + (b &&& 0xff)) &&& 0x100) != 0
    half_carry = (((a &&& 0xf) + (b &&& 0xf)) &&& 0x10) != 0
    {sum, carry, half_carry}
  end
  def add_u16_byte_carry(a, b, _), do: add_u16_byte_carry(a, b)

  # Add two u16 values, then get carries from bit 15 (carry) and bit 11 (half carry)
  def add_u16_word_carry(a, b) do
    sum = (a + b) &&& 0xffff
    carry = ((a + b) &&& 0x10000) != 0
    half_carry = (((a &&& 0xfff) + (b &&& 0xfff)) &&& 0x1000) != 0
    {sum, carry, half_carry}
  end
  def add_u16_word_carry(a, b, _), do: add_u16_word_carry(a, b)

  # Add two u8 values, then get carries from bit 7 (carry) and bit 3 (half carry)
  def add_u8_byte_carry(a, b) do
    sum = (a + b) &&& 0xff
    carry = ((a + b) &&& 0x100) != 0
    half_carry = (((a &&& 0xf) + (b &&& 0xf)) &&& 0x10) != 0
    {sum, carry, half_carry}
  end
  def add_u8_byte_carry(a, b, _), do: add_u8_byte_carry(a, b)

  # Add two u8 values and c flag, then get carries from bit 7 (carry) and bit 3 (half carry)
  def adc_u8_byte_carry(a, b, %Cpu{} = cpu) do
    c = if flag(cpu, :c), do: 1, else: 0
    sum = (a + b + c) &&& 0xff
    carry = ((a + b + c) &&& 0x100) != 0
    half_carry = (((a &&& 0xf) + (b &&& 0xf) + c) &&& 0x10) != 0
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
  def sbc_u8_byte_carry(a, b, %Cpu{} = cpu) do
    c = if flag(cpu, :c), do: 1, else: 0
    diff = (a - b - c) &&& 0xff
    carry = a < (b + c)
    half_carry = (a &&& 0xf) < ((b &&& 0xf) + c)
    {diff, carry, half_carry}
  end

  # Rotate u8 value to left, old bit 7 to carry
  def rlc_u8_byte_carry(value) do
    carry = (value &&& 0x80) != 0
    value = if carry, do: (value <<< 1) ||| 0x1, else: value <<< 1
    value = value &&& 0xff
    {value, carry}
  end
  def rlc_u8_byte_carry(value, _), do: rlc_u8_byte_carry(value)

  # Roate u8 value to left through carry flag, old bit 7 to carry
  def rl_u8_byte_carry(value, %Cpu{} = cpu) do
    carry = (value &&& 0x80) != 0
    value = if flag(cpu, :c), do: (value <<< 1) ||| 0x1, else: value <<< 1
    value = value &&& 0xff
    {value, carry}
  end

  # Rotate u8 value to right, old bit 0 to carry
  def rrc_u8_byte_carry(value) do
    carry = (value &&& 0x1) != 0
    value = if carry, do: (value >>> 1) ||| 0x80, else: value >>> 1
    value = value &&& 0xff
    {value, carry}
  end
  def rrc_u8_byte_carry(value, _), do: rrc_u8_byte_carry(value)

  # Rotate u8 value to right through carry flag, old bit 0 to carry
  def rr_u8_byte_carry(value, %Cpu{} = cpu) do
    carry = (value &&& 0x1) != 0
    value = if flag(cpu, :c), do: (value >>> 1) ||| 0x80, else: value >>> 1
    value = value &&& 0xff
    {value, carry}
  end

  # Shift u8 value to left, lsb is set to 0
  def sla_u8_byte_carry(value) do
    carry = (value &&& 0x80) != 0
    value = (value <<< 1) &&& 0xff
    {value, carry}
  end
  def sla_u8_byte_carry(value, _), do: sla_u8_byte_carry(value)

  # Shift u8 value to right, msb doesn't change
  def sra_u8_byte_carry(value) do
    carry = (value &&& 0x1) != 0
    msb = value &&& 0x80
    value = (value >>> 1) ||| msb
    {value, carry}
  end
  def sra_u8_byte_carry(value, _), do: sra_u8_byte_carry(value)

  # Shift u8 value to right, msb is set to 0
  def srl_u8_byte_carry(value) do
    carry = (value &&& 0x1) != 0
    value = value >>> 1
    {value, carry}
  end
  def srl_u8_byte_carry(value, _), do: srl_u8_byte_carry(value)

  # Fetch 8 bit value at pc. Returns tuple of {value, cpu, hw} as pc is incremented
  def fetch_imm8(%Cpu{} = cpu, hw) do
    addr = cpu.regs.pc
    {value, hw} = Hardware.synced_read(hw, addr)
    {value, write_register(cpu, :pc, (addr + 1) &&& 0xffff), hw}
  end

  # Fetch 16 bit value at pc. Returns tuple of {value, cpu, hw} as pc is incremented
  def fetch_imm16(%Cpu{} = cpu, hw) do
    {low, cpu, hw} = fetch_imm8(cpu, hw)
    {high, cpu, hw} = fetch_imm8(cpu, hw)
    value = ((high <<< 8) &&& 0xff00) ||| (low &&& 0x00ff)
    {value, cpu, hw}
  end

  # Push 16 bit to value to stack
  def push_u16(%Cpu{} = cpu, hw, data) do
    low = data &&& 0xff
    high = (data >>> 8) &&& 0xff
    sp = Cpu.read_register(cpu, :sp)
    sp = (sp - 1) &&& 0xffff
    hw = Hardware.synced_write(hw, sp, high)
    sp = (sp - 1) &&& 0xffff
    hw = Hardware.synced_write(hw, sp, low)
    {Cpu.write_register(cpu, :sp, sp), hw}
  end

  # Pop 16 bit value from stack
  def pop_u16(%Cpu{} = cpu, hw) do
    sp = Cpu.read_register(cpu, :sp)
    {low, hw} = Hardware.synced_read(hw, sp)
    sp = (sp + 1) &&& 0xffff
    {high, hw} = Hardware.synced_read(hw, sp)
    sp = (sp + 1) &&& 0xffff
    {(high <<< 8) ||| low, Cpu.write_register(cpu, :sp, sp), hw}
  end

  # read for a single register
  for reg <- [:a, :f, :b, :c, :d, :e, :h, :l] do
    def read(%Cpu{} = cpu, unquote(reg), hw), do: {read_register(cpu, unquote(reg)), cpu, hw}
  end

  # read for an 8-bit immediate value (no write)
  def read(%Cpu{} = cpu, :imm, hw), do: fetch_imm8(cpu, hw)

  # read for addr (16 bit registers or immediate address)
  # reading from/writing to an address involves memory access == synced read/write
  for reg <- [:bc, :de, :hl] do
    def read(%Cpu{} = cpu, unquote(reg), hw) do
      addr = read_register(cpu, unquote(reg))
      {value, hw} = Hardware.synced_read(hw, addr) 
      {value, cpu, hw}
    end
  end

  # read to HL and decrement/increment HL. Decrement/increment after addr is used
  def read(%Cpu{} = cpu, :hld, hw) do
    addr = read_register(cpu, :hl)
    cpu = write_register(cpu, :hl, (addr - 1) &&& 0xffff)  # wrapping sub
    {value, hw} = Hardware.synced_read(hw, addr)
    {value, cpu, hw}
  end

  def read(%Cpu{} = cpu, :hli, hw) do
    addr = read_register(cpu, :hl)
    cpu = write_register(cpu, :hl, (addr + 1) &&& 0xffff)  # wrapping add
    {value, hw} = Hardware.synced_read(hw, addr)
    {value, cpu, hw}
  end

  # read for immediate addr
  def read(%Cpu{} = cpu, :immaddr, hw) do
    {addr, cpu, hw} = fetch_imm16(cpu, hw)
    {value, hw} = Hardware.synced_read(hw, addr)
    {value, cpu, hw}
  end

  # read for high address (uses 8 bit immediate value for addr)
  def read(%Cpu{} = cpu, :hi, hw) do
    {addr, cpu, hw} = fetch_imm8(cpu, hw)
    addr = 0xff00 ||| addr
    {value, hw} = Hardware.synced_read(hw, addr)
    {value, cpu, hw}
  end

  # read for high address but address is taken from c
  def read(%Cpu{} = cpu, :hic, hw) do
    addr = read_register(cpu, :c)
    addr = 0xff00 ||| addr
    {value, hw} = Hardware.synced_read(hw, addr)
    {value, cpu, hw}
  end


  # write for a single register
  for reg <- [:a, :f, :b, :c, :d, :e, :h, :l] do
    def write(%Cpu{} = cpu, unquote(reg), hw, data), do: {write_register(cpu, unquote(reg), data), hw}
  end

  # write for addr (16 bit registers or immediate address)
  for reg <- [:bc, :de, :hl] do
    def write(%Cpu{} = cpu, unquote(reg), hw, data) do
      addr = read_register(cpu, unquote(reg))
      {cpu, Hardware.synced_write(hw, addr, data)}
    end
  end

  # write to HL and decrement/increment HL. Decrement/increment after addr is used
  def write(%Cpu{} = cpu, :hld, hw, data) do
    addr = read_register(cpu, :hl)
    cpu = write_register(cpu, :hl, (addr - 1) &&& 0xffff)  # wrapping sub
    {cpu, Hardware.synced_write(hw, addr, data)}
  end

  def write(%Cpu{} = cpu, :hli, hw, data) do
    addr = read_register(cpu, :hl)
    cpu = write_register(cpu, :hl, (addr + 1) &&& 0xffff)  # wrapping add
    {cpu, Hardware.synced_write(hw, addr, data)}
  end

  # write for immediate addr
  def write(%Cpu{} = cpu, :immaddr, hw, data) do
    {addr, cpu, hw} = fetch_imm16(cpu, hw)
    {cpu, Hardware.synced_write(hw, addr, data)}
  end

  # write for high address (uses 8 bit immediate value for addr)
  def write(%Cpu{} = cpu, :hi, hw, data) do
    # IO.puts("cpu: #{inspect(cpu)}")
    # IO.puts("data: #{Utils.to_hex(data)}")
    {addr, cpu, hw} = fetch_imm8(cpu, hw)
    addr = 0xff00 ||| addr
    {cpu, Hardware.synced_write(hw, addr, data)}
  end

  # write for high address but address is taken from c
  def write(%Cpu{} = cpu, :hic, hw, data) do
    addr = read_register(cpu, :c)
    addr = 0xff00 ||| addr
    {cpu, Hardware.synced_write(hw, addr, data)}
  end

end
