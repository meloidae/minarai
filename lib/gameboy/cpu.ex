defmodule Gameboy.RecordCpu do
  use Bitwise
  require Record

  alias Gameboy.Hardware
  alias Gameboy.Utils
  alias Gameboy.Cpu.Disassemble

  Record.defrecordp(:cpu,
                    a: 0x00,
                    f: 0x00,
                    b: 0x00,
                    c: 0x00,
                    d: 0x00,
                    e: 0x00,
                    h: 0x00,
                    l: 0x00,
                    pc: 0x0000,
                    sp: 0x0000,
                    opcode: 0x0,
                    ime: false,
                    delayed_ime: nil, 
                    state: :running)

  def init do
    cpu()
  end

  # Fetch opcode for instruction and increment pc
  def fetch_next(cp, hw, addr) do
    {opcode, hw} = Hardware.synced_read(hw, addr)
    if :persistent_term.get({Minarai, :count_fn_calls}, false) do
      Utils.update_counter(Disassemble.disassemble(opcode, cp, hw))
    end
    {cpu(cp, opcode: opcode, pc: (addr + 1) &&& 0xffff), hw}
  end

  # Handle interrupt
  def handle_interrupt(cp, hw) do
    case Hardware.check_interrupt(hw) do
      nil ->
        # No interrupt is requested
        {cp, hw}
      {addr, mask} ->
        cpu(ime: ime, pc: pc, sp: sp, state: state) = cp
        cond do
          ime -> # ime is enabled
            # Add 8 cycles
            hw = Hardware.sync_cycle(hw) |> Hardware.sync_cycle()
            # Push value of pc on to stack
            low = pc &&& 0xff
            high = pc >>> 8
            sp = (sp - 1) &&& 0xffff
            hw = Hardware.synced_write(hw, sp, high)
            sp = (sp - 1) &&& 0xffff
            hw = Hardware.synced_write(hw, sp, low)
            # Acknowledge interrupt
            hw = Hardware.acknowledge_interrupt(hw, mask)
            # Change pc to address specified by interrupt and switch to running state
            {cpu(cp, pc: addr, sp: sp, state: :running, ime: false), hw}
          state != :haltbug ->
            # When ime is disabled, resume from halt without acknowledging interrupts
            {cpu(cp, state: :running), hw}
          true ->
            # halt bug
            {cp, hw}
        end
    end
  end

  # 16-bit reads from a register
  @compile {:inline, read_register: 2}
  def read_register(cpu(a: a, f: f), :af), do: (a <<< 8) ||| f
  def read_register(cpu(b: b, c: c), :bc), do: (b <<< 8) ||| c
  def read_register(cpu(d: d, e: e), :de), do: (d <<< 8) ||| e
  def read_register(cpu(h: h, l: l), :hl), do: (h <<< 8) ||| l
  def read_register(cpu(pc: pc), :pc), do: pc
  def read_register(cpu(sp: sp), :sp), do: sp

  # 8 bit reads from a register
  def read_register(cpu(a: a), :a), do: a
  def read_register(cpu(f: f), :f), do: f
  def read_register(cpu(b: b), :b), do: b
  def read_register(cpu(c: c), :c), do: c
  def read_register(cpu(d: d), :d), do: d
  def read_register(cpu(e: e), :e), do: e
  def read_register(cpu(h: h), :h), do: h
  def read_register(cpu(l: l), :l), do: l

  # 16-bit writes to a register
  @compile {:inline, write_register: 3}
  def write_register(cp, :af, data), do: cpu(cp, a: (data >>> 8) &&& 0xff, f: data &&& 0xf0)  # lower nibble of f is always zero
  def write_register(cp, :bc, data), do: cpu(cp, b: (data >>> 8) &&& 0xff, c: data &&& 0xff)
  def write_register(cp, :de, data), do: cpu(cp, d: (data >>> 8) &&& 0xff, e: data &&& 0xff)
  def write_register(cp, :hl, data), do: cpu(cp, h: (data >>> 8) &&& 0xff, l: data &&& 0xff)
  def write_register(cp, :pc, data), do: cpu(cp, pc: data)
  def write_register(cp, :sp, data), do: cpu(cp, sp: data)

  # 8-bit writes to a register
  def write_register(cp, :a, data), do: cpu(cp, a: data)
  def write_register(cp, :f, data), do: cpu(cp, f: data &&& 0xf0)  # Lower nibble is always zero
  def write_register(cp, :b, data), do: cpu(cp, b: data)
  def write_register(cp, :c, data), do: cpu(cp, c: data)
  def write_register(cp, :d, data), do: cpu(cp, d: data)
  def write_register(cp, :e, data), do: cpu(cp, e: data)
  def write_register(cp, :h, data), do: cpu(cp, h: data)
  def write_register(cp, :l, data), do: cpu(cp, l: data)

  # Set all flags at once
  for z <- [true, false] do
    for n <- [true, false] do
      for h <- [true, false] do
        for c <- [true, false] do
          z_val = if z, do: 1 <<< 7, else: 0
          n_val = if n, do: 1 <<< 6, else: 0
          h_val = if h, do: 1 <<< 5, else: 0
          c_val = if c, do: 1 <<< 4, else: 0
          f_val = bor(z_val, n_val) |> bor(h_val) |> bor(c_val)
          def set_all_flags(cp, unquote(z), unquote(n), unquote(h), unquote(c)) do
            cpu(cp, f: unquote(f_val))
          end
        end
      end
    end
  end

  # Set one or more flags at once
  def set_flags(cpu(f: f) = cp, flags) do
    cpu(cp, f: compute_flags(flags, f))
  end
  defp compute_flags([], value), do: value
  defp compute_flags([{:z, true} | t], value), do: compute_flags(t, value ||| 0x80)
  defp compute_flags([{:z, false} | t], value), do: compute_flags(t, value &&& 0x7f)
  defp compute_flags([{:n, true} | t], value), do: compute_flags(t, value ||| 0x40)
  defp compute_flags([{:n, false} | t], value), do: compute_flags(t, value &&& 0xbf)
  defp compute_flags([{:h, true} | t], value), do: compute_flags(t, value ||| 0x20)
  defp compute_flags([{:h, false} | t], value), do: compute_flags(t, value &&& 0xdf)
  defp compute_flags([{:c, true} | t], value), do: compute_flags(t, value ||| 0x10)
  defp compute_flags([{:c, false} | t], value), do: compute_flags(t, value &&& 0xef)

  # Get flag
  @z_table 0..255 |> Enum.map(fn x -> (x &&& (1 <<< 7)) != 0 end) |> List.to_tuple()
  def flag(cpu(f: f), :z), do: elem(@z_table, f)
  @n_table 0..255 |> Enum.map(fn x -> (x &&& (1 <<< 6)) != 0 end) |> List.to_tuple()
  def flag(cpu(f: f), :n), do: elem(@n_table, f)
  @h_table 0..255 |> Enum.map(fn x -> (x &&& (1 <<< 5)) != 0 end) |> List.to_tuple()
  def flag(cpu(f: f), :h), do: elem(@h_table, f)
  @c_table 0..255 |> Enum.map(fn x -> (x &&& (1 <<< 4)) != 0 end) |> List.to_tuple()
  def flag(cpu(f: f), :c), do: elem(@c_table, f)

  # Check flag based on condition code
  def check_condition(cp, :nz), do: !flag(cp, :z)
  def check_condition(cp, :z), do: flag(cp, :z)
  def check_condition(cp, :nc), do: !flag(cp, :c)
  def check_condition(cp, :c), do: flag(cp, :c)


  # Add two u16 values, then get carries from bit 7 (carry) and bit 3 (half carry)
  # Note that the result is the sum of a + SIGNED b
  # Carries are calculate using UNSIGNED b
  @signed_table 0..255 |> Enum.map(fn x ->
    msb = x &&& 0x80
    if msb != 0, do: x ||| 0xff00, else: x
  end) |> List.to_tuple()
  def add_u16_byte_carry(a, b) do
    sum = (a + elem(@signed_table, b)) &&& 0xffff
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

  # Increment u8, only return the result and half carry (ignore carry)
  @inc_u8_byte_carry 0..0xff
  |> Enum.map(fn x ->
    sum = (x + 1) &&& 0xff
    half_carry = (((x &&& 0xf) + 1) &&& 0x10) != 0
    {sum, half_carry}
  end)
  |> List.to_tuple()
  def inc_u8_byte_carry(value) do
    elem(@inc_u8_byte_carry, value)
  end

  # Add two u8 values and c flag, then get carries from bit 7 (carry) and bit 3 (half carry)
  def adc_u8_byte_carry(a, b, cp) do
    c = if flag(cp, :c), do: 1, else: 0
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

  # Decrement u8, only return the result and half carry (ignore carry)
  @dec_u8_byte_carry 0..0xff
  |> Enum.map(fn x ->
    diff = (x - 1) &&& 0xff
    half_carry = (x &&& 0xf) < 1
    {diff, half_carry}
  end)
  |> List.to_tuple()
  def dec_u8_byte_carry(value) do
    elem(@dec_u8_byte_carry, value)
  end

  # Sub u8 and c flag from u8, then get carries from bit 7 (carry) and bit 3 (half carry)
  def sbc_u8_byte_carry(a, b, cp) do
    c = if flag(cp, :c), do: 1, else: 0
    diff = (a - b - c) &&& 0xff
    carry = a < (b + c)
    half_carry = (a &&& 0xf) < ((b &&& 0xf) + c)
    {diff, carry, half_carry}
  end

  # Rotate u8 value to left, old bit 7 to carry
  @rlc 0..0xff
  |> Enum.map(fn value ->
    carry = (value &&& 0x80) != 0
    value = if carry, do: (value <<< 1) ||| 0x1, else: value <<< 1
    value = value &&& 0xff
    {value, carry}
  end)
  |> List.to_tuple()

  def rlc_u8_byte_carry(value) do
    elem(@rlc, value)
  end
  def rlc_u8_byte_carry(value, _cp), do: rlc_u8_byte_carry(value)

  # Rotate u8 value to left through carry flag, old bit 7 to carry
  def rl_u8_byte_carry(value, cp) do
    carry = (value &&& 0x80) != 0
    value = if flag(cp, :c), do: (value <<< 1) ||| 0x1, else: value <<< 1
    value = value &&& 0xff
    {value, carry}
  end

  # Rotate u8 value to right, old bit 0 to carry
  @rrc 0..0xff
  |> Enum.map(fn value ->
    carry = (value &&& 0x1) != 0
    value = if carry, do: (value >>> 1) ||| 0x80, else: value >>> 1
    value = value &&& 0xff
    {value, carry}
  end)
  |> List.to_tuple()
  def rrc_u8_byte_carry(value) do
    elem(@rrc, value)
  end
  def rrc_u8_byte_carry(value, _cp), do: rrc_u8_byte_carry(value)

  # Rotate u8 value to right through carry flag, old bit 0 to carry
  def rr_u8_byte_carry(value, cp) do
    carry = (value &&& 0x1) != 0
    value = if flag(cp, :c), do: (value >>> 1) ||| 0x80, else: value >>> 1
    value = value &&& 0xff
    {value, carry}
  end

  # Shift u8 value to left, lsb is set to 0
  def sla_u8_byte_carry(value) do
    carry = (value &&& 0x80) != 0
    value = (value <<< 1) &&& 0xff
    {value, carry}
  end
  def sla_u8_byte_carry(value, _cp), do: sla_u8_byte_carry(value)

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
  def srl_u8_byte_carry(value, _cp), do: srl_u8_byte_carry(value)

  # Fetch 8 bit value at pc. Returns tuple of {value, cpu, hw} as pc is incremented
  def fetch_imm8(cpu(pc: addr) = cp, hw) do
    {value, hw} = Hardware.synced_read(hw, addr)
    {value, cpu(cp, pc: (addr + 1) &&& 0xffff), hw}
  end

  # Fetch 16 bit value at pc. Returns tuple of {value, cpu, hw} as pc is incremented
  def fetch_imm16(cp, hw) do
    {low, cp, hw} = fetch_imm8(cp, hw)
    {high, cp, hw} = fetch_imm8(cp, hw)
    value = ((high <<< 8) &&& 0xff00) ||| (low &&& 0x00ff)
    {value, cp, hw}
  end

  # Push 16 bit to value to stack
  def push_u16(cpu(sp: sp) = cp, hw, data) do
    low = data &&& 0xff
    high = (data >>> 8) &&& 0xff
    sp = (sp - 1) &&& 0xffff
    hw = Hardware.synced_write(hw, sp, high)
    sp = (sp - 1) &&& 0xffff
    hw = Hardware.synced_write(hw, sp, low)
    {cpu(cp, sp: sp), hw}
  end

  # Pop 16 bit value from stack
  def pop_u16(cpu(sp: sp) = cp, hw) do
    {low, hw} = Hardware.synced_read(hw, sp)
    sp = (sp + 1) &&& 0xffff
    {high, hw} = Hardware.synced_read(hw, sp)
    sp = (sp + 1) &&& 0xffff
    {(high <<< 8) ||| low, cpu(cp, sp: sp), hw}
  end

  # Read for a single register
  def read(cp, :a, hw), do: {cpu(cp, :a), cp, hw}
  def read(cp, :f, hw), do: {cpu(cp, :f), cp, hw}
  def read(cp, :b, hw), do: {cpu(cp, :b), cp, hw}
  def read(cp, :c, hw), do: {cpu(cp, :c), cp, hw}
  def read(cp, :d, hw), do: {cpu(cp, :d), cp, hw}
  def read(cp, :e, hw), do: {cpu(cp, :e), cp, hw}
  def read(cp, :h, hw), do: {cpu(cp, :h), cp, hw}
  def read(cp, :l, hw), do: {cpu(cp, :l), cp, hw}

  # Read for an 8-bit immediate value (no write)
  def read(cp, :imm, hw), do: fetch_imm8(cp, hw)

  # Read for addr (16 bit registers or immediate address)
  # Reading from/writing to an address involves memory access == synced read/write
  for reg <- [:bc, :de, :hl] do
    def read(cp, unquote(reg), hw) do
      addr = read_register(cp, unquote(reg))
      {value, hw} = Hardware.synced_read(hw, addr) 
      {value, cp, hw}
    end
  end

  # Read from addr in HL and decrement/increment HL. Decrement/increment after addr is used
  def read(cp, :hld, hw) do
    addr = read_register(cp, :hl)
    cp = write_register(cp, :hl, (addr - 1) &&& 0xffff)  # wrapping sub
    {value, hw} = Hardware.synced_read(hw, addr)
    {value, cp, hw}
  end
  def read(cp, :hli, hw) do
    addr = read_register(cp, :hl)
    cp = write_register(cp, :hl, (addr + 1) &&& 0xffff)  # wrapping add
    {value, hw} = Hardware.synced_read(hw, addr)
    {value, cp, hw}
  end

  # Read from immediate addr
  def read(cp, :immaddr, hw) do
    {addr, cp, hw} = fetch_imm16(cp, hw)
    {value, hw} = Hardware.synced_read(hw, addr)
    {value, cp, hw}
  end

  # Read from high address (uses 8 bit immediate value for addr)
  def read(cp, :hi, hw) do
    {addr, cp, hw} = fetch_imm8(cp, hw)
    addr = 0xff00 ||| addr
    {value, hw} = Hardware.synced_read(hw, addr)
    {value, cp, hw}
  end

  # Read from high address but address is taken from c
  def read(cp, :hic, hw) do
    addr = cpu(cp, :c)
    addr = 0xff00 ||| addr
    {value, hw} = Hardware.synced_read(hw, addr)
    {value, cp, hw}
  end

  # Write to a single register
  def write(cp, :a, hw, data), do: {cpu(cp, a: data), hw}
  # Lower nibble of f is always zero
  def write(cp, :f, hw, data), do: {cpu(cp, f: data &&& 0xf0), hw}
  def write(cp, :b, hw, data), do: {cpu(cp, b: data), hw}
  def write(cp, :c, hw, data), do: {cpu(cp, c: data), hw}
  def write(cp, :d, hw, data), do: {cpu(cp, d: data), hw}
  def write(cp, :e, hw, data), do: {cpu(cp, e: data), hw}
  def write(cp, :h, hw, data), do: {cpu(cp, h: data), hw}
  def write(cp, :l, hw, data), do: {cpu(cp, l: data), hw}

  # Write to addr (16 bit registers or immediate address)
  for reg <- [:bc, :de, :hl] do
    def write(cp, unquote(reg), hw, data) do
      addr = read_register(cp, unquote(reg))
      {cp, Hardware.synced_write(hw, addr, data)}
    end
  end

  # Write to addr in HL and decrement/increment HL. Decrement/increment after addr is used
  def write(cp, :hld, hw, data) do
    addr = read_register(cp, :hl)
    cp = write_register(cp, :hl, (addr - 1) &&& 0xffff)  # wrapping sub
    {cp, Hardware.synced_write(hw, addr, data)}
  end
  def write(cp, :hli, hw, data) do
    addr = read_register(cp, :hl)
    cp = write_register(cp, :hl, (addr + 1) &&& 0xffff)  # wrapping add
    {cp, Hardware.synced_write(hw, addr, data)}
  end

  # Write to immediate addr
  def write(cp, :immaddr, hw, data) do
    {addr, cp, hw} = fetch_imm16(cp, hw)
    {cp, Hardware.synced_write(hw, addr, data)}
  end

  # Write to high address (uses 8 bit immediate value for addr)
  def write(cp, :hi, hw, data) do
    {addr, cp, hw} = fetch_imm8(cp, hw)
    addr = 0xff00 ||| addr
    {cp, Hardware.synced_write(hw, addr, data)}
  end

  # Write to high address but address is taken from c
  def write(cp, :hic, hw, data) do
    addr = cpu(cp, :c)
    addr = 0xff00 ||| addr
    {cp, Hardware.synced_write(hw, addr, data)}
  end

  # Update pc and enable interrupt immediately (used for RETI instruction)
  @compile {:inline, return_from_interrupt: 2}
  def return_from_interrupt(cp, ret_addr) do
    cpu(cp, pc: ret_addr, ime: true)
  end

  @compile {:inline, set_ime: 2, ime: 1, apply_delayed_ime: 2}
  def ime(cp), do: cpu(cp, :ime)
  def set_ime(cp, value), do: cpu(cp, ime: value)
  # Copy ime value from delayed_ime and set delayed_ime to nil
  def apply_delayed_ime(cp, value), do: cpu(cp, ime: value, delayed_ime: nil)

  @compile {:inline, set_delayed_ime: 2, delayed_ime: 1}
  def set_delayed_ime(cp, value), do: cpu(cp, delayed_ime: value)
  def delayed_ime(cp), do: cpu(cp, :delayed_ime)

  @compile {:inline, set_state: 2, state: 1}
  def state(cp), do: cpu(cp, :state)
  def set_state(cp, state), do: cpu(cp, state: state)

  @compile {:inline, opcode: 1}
  def opcode(cp), do: cpu(cp, :opcode)
end
