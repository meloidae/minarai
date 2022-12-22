defmodule Gameboy.SmallCpu do
  import Bitwise
  require Record

  alias Gameboy.Hardware
  alias Gameboy.Utils

  Record.defrecordp(:cpu,
                    afbc: 0x00,
                    dehl: 0x00,
                    sppc: 0x00,
                    opcode: 0x0,
                    ime: false,
                    delayed_ime: nil, 
                    state: :running)


  def init do
    cpu()
  end

  # Fetch opcode for instruction and increment pc
  def fetch_next(cpu(sppc: reg) = cp, hw, addr) do
    {opcode, hw} = Hardware.synced_read(hw, addr)
    if :persistent_term.get({Minarai, :count_fn_calls}, false) do
      Utils.update_counter(Disassemble.disassemble(opcode, cp, hw))
    end
    {cpu(cp, opcode: opcode, sppc: (reg &&& 0xffff_0000) ||| ((addr + 1) &&& 0xffff)), hw}
  end

  # Handle interrupt
  def handle_interrupt(cp, hw) do
    case Hardware.check_interrupt(hw) do
      nil ->
        # No interrupt is requested
        {cp, hw}
      {addr, mask} ->
        cpu(ime: ime, sppc: sppc, state: state) = cp
        cond do
          ime -> # ime is enabled
            pc = sppc &&& 0x0000_ffff
            sp = (sppc &&& 0xffff_0000) >>> 16
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
            {cpu(cp, sppc: (sp <<< 16) ||| addr, state: :running, ime: false), hw}
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
  def read_register(cpu(afbc: reg), :af), do: (reg &&& 0xffff_0000) >>> 16
  def read_register(cpu(afbc: reg), :bc), do: reg &&& 0x0000_ffff
  def read_register(cpu(dehl: reg), :de), do: (reg &&& 0xffff_0000) >>> 16
  def read_register(cpu(dehl: reg), :hl), do: reg &&& 0x0000_ffff
  def read_register(cpu(sppc: reg), :sp), do: (reg &&& 0xffff_0000) >>> 16
  def read_register(cpu(sppc: reg), :pc), do: reg &&& 0x0000_ffff

  # 8 bit reads from a register
  def read_register(cpu(afbc: reg), :a), do: (reg &&& 0xff00_0000) >>> 24
  def read_register(cpu(afbc: reg), :f), do: (reg &&& 0x00ff_0000) >>> 16
  def read_register(cpu(afbc: reg), :b), do: (reg &&& 0x0000_ff00) >>> 8
  def read_register(cpu(afbc: reg), :c), do: reg &&& 0x0000_00ff
  def read_register(cpu(dehl: reg), :d), do: (reg &&& 0xff00_0000) >>> 24
  def read_register(cpu(dehl: reg), :e), do: (reg &&& 0x00ff_0000) >>> 16
  def read_register(cpu(dehl: reg), :h), do: (reg &&& 0x0000_ff00) >>> 8
  def read_register(cpu(dehl: reg), :l), do: reg &&& 0x0000_00ff

  # 16-bit writes to a register
  @compile {:inline, write_register: 3}
  def write_register(cpu(afbc: reg) = cp, :af, data) do
    # lower nibble of f is always zero
    cpu(cp, afbc: (reg &&& 0x0000_ffff) ||| ((data &&& 0xfff0) <<< 16))
  end
  def write_register(cpu(afbc: reg) = cp, :bc, data) do
    cpu(cp, afbc: (reg &&& 0xffff_0000) ||| (data &&& 0xffff))
  end
  def write_register(cpu(dehl: reg) = cp, :de, data) do
    cpu(cp, dehl: (reg &&& 0x0000_ffff) ||| ((data &&& 0xffff) <<< 16))
  end
  def write_register(cpu(dehl: reg) = cp, :hl, data) do
    cpu(cp, dehl: (reg &&& 0xffff_0000) ||| (data &&& 0xffff))
  end
  def write_register(cpu(sppc: reg) = cp, :sp, data) do
    cpu(cp, sppc: (reg &&& 0x0000_ffff) ||| ((data &&& 0xffff) <<< 16))
  end
  def write_register(cpu(sppc: reg) = cp, :pc, data) do
    cpu(cp, sppc: (reg &&& 0xffff_0000) ||| (data &&& 0xffff))
  end

  # 8-bit writes to a register
  def write_register(cpu(afbc: reg) = cp, :a, data) do
    cpu(cp, afbc: (reg &&& 0x00ff_ffff) ||| (data <<< 24))
  end
  def write_register(cpu(afbc: reg) = cp, :f, data) do
    # Lower nibble is always zero
    cpu(cp, afbc: (reg &&& 0xff00_ffff) ||| ((data &&& 0xf0) <<< 16))
  end
  def write_register(cpu(afbc: reg) = cp, :b, data) do
    cpu(cp, afbc: (reg &&& 0xffff_00ff) ||| (data <<< 8))
  end
  def write_register(cpu(afbc: reg) = cp, :c, data) do
    cpu(cp, afbc: (reg &&& 0xffff_ff00) ||| data)
  end
  def write_register(cpu(dehl: reg) = cp, :d, data) do
    cpu(cp, dehl: (reg &&& 0x00ff_ffff) ||| (data <<< 24))
  end
  def write_register(cpu(dehl: reg) = cp, :e, data) do
    # Lower nibble is always zero
    cpu(cp, dehl: (reg &&& 0xff00_ffff) ||| (data <<< 16))
  end
  def write_register(cpu(dehl: reg) = cp, :h, data) do
    cpu(cp, dehl: (reg &&& 0xffff_00ff) ||| (data <<< 8))
  end
  def write_register(cpu(dehl: reg) = cp, :l, data) do
    cpu(cp, dehl: (reg &&& 0xffff_ff00) ||| data)
  end

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
          f_val = f_val <<< 16
          def set_all_flags(cpu(afbc: reg) = cp, unquote(z), unquote(n), unquote(h), unquote(c)) do
            cpu(cp, afbc: (reg &&& 0xff00_ffff) ||| unquote(f_val))
          end
        end
      end
    end
  end


  # Set one or more flags at once
  def set_flags(cpu(afbc: reg) = cp, flags) do
    f = (reg &&& 0x00ff_0000) >>> 16
    cpu(cp, afbc: (reg &&& 0xff00_ffff) ||| (compute_flags(flags, f) <<< 16))
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
  def flag(cpu(afbc: reg), :z), do: elem(@z_table, (reg &&& 0x00ff_0000) >>> 16)
  @n_table 0..255 |> Enum.map(fn x -> (x &&& (1 <<< 6)) != 0 end) |> List.to_tuple()
  def flag(cpu(afbc: reg), :n), do: elem(@n_table, (reg &&& 0x00ff_0000) >>> 16)
  @h_table 0..255 |> Enum.map(fn x -> (x &&& (1 <<< 5)) != 0 end) |> List.to_tuple()
  def flag(cpu(afbc: reg), :h), do: elem(@h_table, (reg &&& 0x00ff_0000) >>> 16)
  @c_table 0..255 |> Enum.map(fn x -> (x &&& (1 <<< 4)) != 0 end) |> List.to_tuple()
  def flag(cpu(afbc: reg), :c), do: elem(@c_table, (reg &&& 0x00ff_0000) >>> 16)

  # Check flag based on condition code
  def check_condition(cp, :nz), do: not flag(cp, :z)
  def check_condition(cp, :z), do: flag(cp, :z)
  def check_condition(cp, :nc), do: not flag(cp, :c)
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
  def fetch_imm8(cpu(sppc: reg) = cp, hw) do
    addr = 0x0000_ffff &&& reg
    {value, hw} = Hardware.synced_read(hw, addr)
    {value, cpu(cp, sppc: (reg &&& 0xffff_0000) ||| ((addr + 1) &&& 0xffff)), hw}
  end

  # Fetch 16 bit value at pc. Returns tuple of {value, cpu, hw} as pc is incremented
  def fetch_imm16(cp, hw) do
    {low, cp, hw} = fetch_imm8(cp, hw)
    {high, cp, hw} = fetch_imm8(cp, hw)
    value = ((high <<< 8) &&& 0xff00) ||| (low &&& 0x00ff)
    {value, cp, hw}
  end

  # Push 16 bit to value to stack
  def push_u16(cpu(sppc: reg) = cp, hw, data) do
    sp = (reg &&& 0xffff_0000) >>> 16
    low = data &&& 0xff
    high = (data >>> 8) &&& 0xff
    sp = (sp - 1) &&& 0xffff
    hw = Hardware.synced_write(hw, sp, high)
    sp = (sp - 1) &&& 0xffff
    hw = Hardware.synced_write(hw, sp, low)
    {cpu(cp, sppc: (reg &&& 0x0000_ffff) ||| (sp <<< 16)), hw}
  end

  # Pop 16 bit value from stack
  def pop_u16(cpu(sppc: reg) = cp, hw) do
    sp = (reg &&& 0xffff_0000) >>> 16
    {low, hw} = Hardware.synced_read(hw, sp)
    sp = (sp + 1) &&& 0xffff
    {high, hw} = Hardware.synced_read(hw, sp)
    sp = (sp + 1) &&& 0xffff
    {(high <<< 8) ||| low, cpu(cp, sppc: (reg &&& 0x0000_ffff) ||| (sp <<< 16)), hw}
  end

  # Read for a single register
  def read(cp, :a, hw), do: {read_register(cp, :a), cp, hw}
  def read(cp, :f, hw), do: {read_register(cp, :f), cp, hw}
  def read(cp, :b, hw), do: {read_register(cp, :b), cp, hw}
  def read(cp, :c, hw), do: {read_register(cp, :c), cp, hw}
  def read(cp, :d, hw), do: {read_register(cp, :d), cp, hw}
  def read(cp, :e, hw), do: {read_register(cp, :e), cp, hw}
  def read(cp, :h, hw), do: {read_register(cp, :h), cp, hw}
  def read(cp, :l, hw), do: {read_register(cp, :l), cp, hw}

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
    addr = read_register(cp, :c)
    addr = 0xff00 ||| addr
    {value, hw} = Hardware.synced_read(hw, addr)
    {value, cp, hw}
  end

  # Write to a single register
  def write(cp, :a, hw, data), do: {write_register(cp, :a, data), hw}
  def write(cp, :f, hw, data), do: {write_register(cp, :f, data), hw}
  def write(cp, :b, hw, data), do: {write_register(cp, :b, data), hw}
  def write(cp, :c, hw, data), do: {write_register(cp, :c, data), hw}
  def write(cp, :d, hw, data), do: {write_register(cp, :d, data), hw}
  def write(cp, :e, hw, data), do: {write_register(cp, :e, data), hw}
  def write(cp, :h, hw, data), do: {write_register(cp, :h, data), hw}
  def write(cp, :l, hw, data), do: {write_register(cp, :l, data), hw}

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
    addr = read_register(cp, :c)
    addr = 0xff00 ||| addr
    {cp, Hardware.synced_write(hw, addr, data)}
  end

  # Update pc and enable interrupt immediately (used for RETI instruction)
  @compile {:inline, return_from_interrupt: 2}
  def return_from_interrupt(cpu(sppc: reg) = cp, ret_addr) do
    cpu(cp, sppc: (reg &&& 0xffff_0000) ||| ret_addr, ime: true)
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

  @compile {:inline, post_interrupt: 3}
  def post_interrupt(cp, sp, pc) do
    cpu(cp, sppc: (sp <<< 16) ||| pc, state: :running, ime: false)
  end

  @compile{:inline, post_fetch: 3}
  def post_fetch(cpu(sppc: reg) = cp, pc, opcode) do
    cpu(cp, opcode: opcode, sppc: (reg &&& 0xffff_0000) ||| ((pc + 1) &&& 0xffff))
  end
end
