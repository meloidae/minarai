defmodule Gameboy.Cpu do
  use Bitwise
  alias Gameboy.Cpu
  alias Gameboy.Hardware
  alias Gameboy.Utils
  alias Gameboy.Cpu.Disassemble

  defstruct a: 0x00,
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
            state: :running

  defimpl Inspect, for: Cpu do
    def inspect(cpu, _) do
      [
        "pc: #{Utils.to_hex(cpu.pc)} ",
        "op: #{Utils.to_hex(cpu.opcode)} ",
        "sp: #{Utils.to_hex(cpu.sp)} ",
        "af: #{Utils.to_hex(Cpu.read_register(cpu, :af))} ",
        "bc: #{Utils.to_hex(Cpu.read_register(cpu, :bc))} ",
        "de: #{Utils.to_hex(Cpu.read_register(cpu, :de))} ",
        "hl: #{Utils.to_hex(Cpu.read_register(cpu, :hl))}"
      ] |> IO.iodata_to_binary()
    end
  end


  def init do
    %Cpu{}
  end

  # Fetch opcode for instruction and increment pc
  def fetch_next(cpu, hw, addr) do
    {opcode, hw} = Hardware.synced_read(hw, addr)
    if :persistent_term.get({Minarai, :count_fn_calls}, false) do
      Utils.update_counter(Disassemble.disassemble(opcode, cpu, hw))
    end
    {%{cpu | opcode: opcode, pc: (addr + 1) &&& 0xffff}, hw}
  end

  # handle interrupt TODO
  def handle_interrupt(%Cpu{} = cpu, hw) do
    case Hardware.check_interrupt(hw) do
      nil ->
        # No interrupt is requested
        {cpu, hw}
      {addr, mask} ->
        %{ime: ime, pc: pc, sp: sp, state: state} = cpu
        cond do
          ime ->
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
            # if cpu.state != :running do
              # IO.puts("Resume with jump")
            # end
            {%{cpu | pc: addr, sp: sp, state: :running, ime: false}, hw}
          state != :haltbug ->
            # When ime is disabled, resume from halt without acknowledging interrupts
            # IO.puts("Resume no jump")
            {Map.put(cpu, :state, :running), hw}
          true ->
            # halt bug
            {cpu, hw}
        end
    end
  end

  # 16-bit reads from a register
  @compile {:inline, read_register: 2}
  def read_register(%Cpu{a: a, f: f}, :af), do: (a <<< 8) ||| f
  def read_register(%Cpu{b: b, c: c}, :bc), do: (b <<< 8) ||| c
  def read_register(%Cpu{d: d, e: e}, :de), do: (d <<< 8) ||| e
  def read_register(%Cpu{h: h, l: l}, :hl), do: (h <<< 8) ||| l
  def read_register(%Cpu{pc: pc}, :pc), do: pc
  def read_register(%Cpu{sp: sp}, :sp), do: sp

  # 8 bit reads from a register
  def read_register(%Cpu{a: a}, :a), do: a
  def read_register(%Cpu{f: f}, :f), do: f
  def read_register(%Cpu{b: b}, :b), do: b
  def read_register(%Cpu{c: c}, :c), do: c
  def read_register(%Cpu{d: d}, :d), do: d
  def read_register(%Cpu{e: e}, :e), do: e
  def read_register(%Cpu{h: h}, :h), do: h
  def read_register(%Cpu{l: l}, :l), do: l


  # 16-bit writes to a register
  @compile {:inline, write_register: 3}
  def write_register(%Cpu{} = cpu, :af, data), do: %{cpu | a: (data >>> 8) &&& 0xff, f: data &&& 0xf0}  # lower nibble of f is always zero
  def write_register(%Cpu{} = cpu, :bc, data), do: %{cpu | b: (data >>> 8) &&& 0xff, c: data &&& 0xff}
  def write_register(%Cpu{} = cpu, :de, data), do: %{cpu | d: (data >>> 8) &&& 0xff, e: data &&& 0xff}
  def write_register(%Cpu{} = cpu, :hl, data), do: %{cpu | h: (data >>> 8) &&& 0xff, l: data &&& 0xff}
  def write_register(%Cpu{} = cpu, :pc, data), do: Map.put(cpu, :pc, data)
  def write_register(%Cpu{} = cpu, :sp, data), do: Map.put(cpu, :sp, data)

  # 8-bit writes to a register
  def write_register(%Cpu{} = cpu, :a, data), do: Map.put(cpu, :a, data)
  def write_register(%Cpu{} = cpu, :f, data), do: Map.put(cpu, :f, data &&& 0xf0)  # Lower nibble is always zero
  def write_register(%Cpu{} = cpu, :b, data), do: Map.put(cpu, :b, data)
  def write_register(%Cpu{} = cpu, :c, data), do: Map.put(cpu, :c, data)
  def write_register(%Cpu{} = cpu, :d, data), do: Map.put(cpu, :d, data)
  def write_register(%Cpu{} = cpu, :e, data), do: Map.put(cpu, :e, data)
  def write_register(%Cpu{} = cpu, :h, data), do: Map.put(cpu, :h, data)
  def write_register(%Cpu{} = cpu, :l, data), do: Map.put(cpu, :l, data)

  # Set/Get flags
  for {which_flag, offset} <- Enum.zip([:z, :n, :h, :c], 7..4) do
    true_val = 1 <<< offset
    false_val = bxor(0xff, true_val)
    def set_flag(cpu, unquote(which_flag), true) do
      f = cpu.f ||| unquote(true_val)
      Map.put(cpu, :f, f)
    end

    def set_flag(cpu, unquote(which_flag), false) do
      f = cpu.f &&& unquote(false_val)
      Map.put(cpu, :f, f)
    end

    # def flag(%Cpu{} = cpu, unquote(which_flag)) do
    #   (cpu.f &&& unquote(true_val)) != 0
    # end
  end

  for z <- [true, false] do
    for n <- [true, false] do
      for h <- [true, false] do
        for c <- [true, false] do
          z_val = if z, do: 1 <<< 7, else: 0
          n_val = if n, do: 1 <<< 6, else: 0
          h_val = if h, do: 1 <<< 5, else: 0
          c_val = if c, do: 1 <<< 4, else: 0
          f_val = bor(z_val, n_val) |> bor(h_val) |> bor(c_val)
          def set_all_flags(%Cpu{} = cpu, unquote(z), unquote(n), unquote(h), unquote(c)) do
            Map.put(cpu, :f, unquote(f_val))
          end
        end
      end
    end
  end

  def set_flags(cpu, flags) do
    f = compute_flags(flags, cpu.f)
    Map.put(cpu, :f, f)
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

  @z_table 0..255 |> Enum.map(fn x -> (x &&& (1 <<< 7)) != 0 end) |> List.to_tuple()
  def flag(cpu, :z), do: elem(@z_table, cpu.f)
  @n_table 0..255 |> Enum.map(fn x -> (x &&& (1 <<< 6)) != 0 end) |> List.to_tuple()
  def flag(cpu, :n), do: elem(@n_table, cpu.f)
  @h_table 0..255 |> Enum.map(fn x -> (x &&& (1 <<< 5)) != 0 end) |> List.to_tuple()
  def flag(cpu, :h), do: elem(@h_table, cpu.f)
  @c_table 0..255 |> Enum.map(fn x -> (x &&& (1 <<< 4)) != 0 end) |> List.to_tuple()
  def flag(cpu, :c), do: elem(@c_table, cpu.f)

  # Check flag based on condition code
  def check_condition(cpu, :nz), do: !flag(cpu, :z)
  def check_condition(cpu, :z), do: flag(cpu, :z)
  def check_condition(cpu, :nc), do: !flag(cpu, :c)
  def check_condition(cpu, :c), do: flag(cpu, :c)


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
  def adc_u8_byte_carry(a, b, cpu) do
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
  def sbc_u8_byte_carry(a, b, cpu) do
    c = if flag(cpu, :c), do: 1, else: 0
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

  # def rlc_u8_byte_carry(value) do
  #   carry = (value &&& 0x80) != 0
  #   value = if carry, do: (value <<< 1) ||| 0x1, else: value <<< 1
  #   value = value &&& 0xff
  #   {value, carry}
  # end
  def rlc_u8_byte_carry(value, _cpu), do: rlc_u8_byte_carry(value)

  # Rotate u8 value to left through carry flag, old bit 7 to carry
  def rl_u8_byte_carry(value, cpu) do
    carry = (value &&& 0x80) != 0
    value = if flag(cpu, :c), do: (value <<< 1) ||| 0x1, else: value <<< 1
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
  # def rrc_u8_byte_carry(value) do
  #   carry = (value &&& 0x1) != 0
  #   value = if carry, do: (value >>> 1) ||| 0x80, else: value >>> 1
  #   value = value &&& 0xff
  #   {value, carry}
  # end
  def rrc_u8_byte_carry(value, _cpu), do: rrc_u8_byte_carry(value)

  # Rotate u8 value to right through carry flag, old bit 0 to carry
  def rr_u8_byte_carry(value, cpu) do
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
  def sla_u8_byte_carry(value, _cpu), do: sla_u8_byte_carry(value)

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
  def srl_u8_byte_carry(value, _cpu), do: srl_u8_byte_carry(value)

  # Fetch 8 bit value at pc. Returns tuple of {value, cpu, hw} as pc is incremented
  def fetch_imm8(%Cpu{pc: addr} = cpu, hw) do
    {value, hw} = Hardware.synced_read(hw, addr)
    # {value, write_register(cpu, :pc, (addr + 1) &&& 0xffff), hw}
    # {value, Map.put(cpu, :pc, (addr + 1) &&& 0xffff), hw}
    {value, Map.put(cpu, :pc, (addr + 1) &&& 0xffff), hw}
  end

  # Fetch 16 bit value at pc. Returns tuple of {value, cpu, hw} as pc is incremented
  def fetch_imm16(cpu, hw) do
    {low, cpu, hw} = fetch_imm8(cpu, hw)
    {high, cpu, hw} = fetch_imm8(cpu, hw)
    # IO.puts("imm16 = low: #{Utils.to_hex(low)}, high: #{Utils.to_hex(high)}")
    value = ((high <<< 8) &&& 0xff00) ||| (low &&& 0x00ff)
    {value, cpu, hw}
  end

  # Push 16 bit to value to stack
  def push_u16(%Cpu{sp: sp} = cpu, hw, data) do
    low = data &&& 0xff
    high = (data >>> 8) &&& 0xff
    sp = (sp - 1) &&& 0xffff
    # IO.puts("high sp = #{Utils.to_hex(sp)}")
    hw = Hardware.synced_write(hw, sp, high)
    sp = (sp - 1) &&& 0xffff
    # IO.puts("low sp = #{Utils.to_hex(sp)}")
    hw = Hardware.synced_write(hw, sp, low)
    {Map.put(cpu, :sp, sp), hw}
  end

  # Pop 16 bit value from stack
  def pop_u16(%Cpu{sp: sp} = cpu, hw) do
    {low, hw} = Hardware.synced_read(hw, sp)
    sp = (sp + 1) &&& 0xffff
    {high, hw} = Hardware.synced_read(hw, sp)
    sp = (sp + 1) &&& 0xffff
    # {(high <<< 8) ||| low, Cpu.write_register(cpu, :sp, sp), hw}
    {(high <<< 8) ||| low, Map.put(cpu, :sp, sp), hw}
  end

  # read for a single register
  # for reg <- [:a, :f, :b, :c, :d, :e, :h, :l] do
  #   def read(cpu, unquote(reg), hw), do: {read_register(cpu, unquote(reg)), cpu, hw}
  # end
  def read(cpu, :a, hw), do: {cpu.a, cpu, hw}
  def read(cpu, :f, hw), do: {cpu.f, cpu, hw}
  def read(cpu, :b, hw), do: {cpu.b, cpu, hw}
  def read(cpu, :c, hw), do: {cpu.c, cpu, hw}
  def read(cpu, :d, hw), do: {cpu.d, cpu, hw}
  def read(cpu, :e, hw), do: {cpu.e, cpu, hw}
  def read(cpu, :h, hw), do: {cpu.h, cpu, hw}
  def read(cpu, :l, hw), do: {cpu.l, cpu, hw}

  # read for an 8-bit immediate value (no write)
  def read(cpu, :imm, hw), do: fetch_imm8(cpu, hw)

  # read for addr (16 bit registers or immediate address)
  # reading from/writing to an address involves memory access == synced read/write
  for reg <- [:bc, :de, :hl] do
    def read(cpu, unquote(reg), hw) do
      addr = read_register(cpu, unquote(reg))
      {value, hw} = Hardware.synced_read(hw, addr) 
      {value, cpu, hw}
    end
  end

  # read to HL and decrement/increment HL. Decrement/increment after addr is used
  def read(cpu, :hld, hw) do
    addr = read_register(cpu, :hl)
    cpu = write_register(cpu, :hl, (addr - 1) &&& 0xffff)  # wrapping sub
    {value, hw} = Hardware.synced_read(hw, addr)
    {value, cpu, hw}
  end

  def read(cpu, :hli, hw) do
    addr = read_register(cpu, :hl)
    cpu = write_register(cpu, :hl, (addr + 1) &&& 0xffff)  # wrapping add
    {value, hw} = Hardware.synced_read(hw, addr)
    {value, cpu, hw}
  end

  # read for immediate addr
  def read(cpu, :immaddr, hw) do
    {addr, cpu, hw} = fetch_imm16(cpu, hw)
    {value, hw} = Hardware.synced_read(hw, addr)
    {value, cpu, hw}
  end

  # read for high address (uses 8 bit immediate value for addr)
  def read(cpu, :hi, hw) do
    {addr, cpu, hw} = fetch_imm8(cpu, hw)
    addr = 0xff00 ||| addr
    {value, hw} = Hardware.synced_read(hw, addr)
    {value, cpu, hw}
  end

  # read for high address but address is taken from c
  def read(cpu, :hic, hw) do
    addr = cpu.c
    addr = 0xff00 ||| addr
    {value, hw} = Hardware.synced_read(hw, addr)
    {value, cpu, hw}
  end


  # write for a single register
  # for reg <- [:a, :f, :b, :c, :d, :e, :h, :l] do
  #   def write(cpu, unquote(reg), hw, data), do: {Map.put(cpu, unquote(reg), data), hw}
  # end
  def write(cpu, :a, hw, data), do: {Map.put(cpu, :a, data), hw}
  # Lower nibble of f is always zero
  def write(cpu, :f, hw, data), do: {Map.put(cpu, :f, data &&& 0xf0), hw}
  def write(cpu, :b, hw, data), do: {Map.put(cpu, :b, data), hw}
  def write(cpu, :c, hw, data), do: {Map.put(cpu, :c, data), hw}
  def write(cpu, :d, hw, data), do: {Map.put(cpu, :d, data), hw}
  def write(cpu, :e, hw, data), do: {Map.put(cpu, :e, data), hw}
  def write(cpu, :h, hw, data), do: {Map.put(cpu, :h, data), hw}
  def write(cpu, :l, hw, data), do: {Map.put(cpu, :l, data), hw}

  # write for addr (16 bit registers or immediate address)
  for reg <- [:bc, :de, :hl] do
    def write(cpu, unquote(reg), hw, data) do
      addr = read_register(cpu, unquote(reg))
      {cpu, Hardware.synced_write(hw, addr, data)}
    end
  end

  # write to HL and decrement/increment HL. Decrement/increment after addr is used
  def write(cpu, :hld, hw, data) do
    addr = read_register(cpu, :hl)
    cpu = write_register(cpu, :hl, (addr - 1) &&& 0xffff)  # wrapping sub
    {cpu, Hardware.synced_write(hw, addr, data)}
  end

  def write(cpu, :hli, hw, data) do
    addr = read_register(cpu, :hl)
    cpu = write_register(cpu, :hl, (addr + 1) &&& 0xffff)  # wrapping add
    {cpu, Hardware.synced_write(hw, addr, data)}
  end

  # write for immediate addr
  def write(cpu, :immaddr, hw, data) do
    {addr, cpu, hw} = fetch_imm16(cpu, hw)
    {cpu, Hardware.synced_write(hw, addr, data)}
  end

  # write for high address (uses 8 bit immediate value for addr)
  def write(cpu, :hi, hw, data) do
    # IO.puts("cpu: #{inspect(cpu)}")
    # IO.puts("data: #{Utils.to_hex(data)}")
    {addr, cpu, hw} = fetch_imm8(cpu, hw)
    addr = 0xff00 ||| addr
    {cpu, Hardware.synced_write(hw, addr, data)}
  end

  # write for high address but address is taken from c
  def write(cpu, :hic, hw, data) do
    addr = cpu.c
    addr = 0xff00 ||| addr
    {cpu, Hardware.synced_write(hw, addr, data)}
  end

  # Update pc and enable interrupt immediately (used for RETI instruction)
  @compile {:inline, return_from_interrupt: 2}
  def return_from_interrupt(cpu, ret_addr) do
    %{cpu | pc: ret_addr, ime: true}
  end

  @compile {:inline, set_ime: 2, ime: 1, apply_delayed_ime: 2}
  def ime(cpu), do: cpu.ime
  def set_ime(cpu, value), do: Map.put(cpu, :ime, value)
  # Copy ime value from delayed_ime and set delayed_ime to nil
  def apply_delayed_ime(cpu, value), do: %{cpu | ime: value, delayed_ime: nil}

  @compile {:inline, set_delayed_ime: 2, delayed_ime: 1}
  def set_delayed_ime(cpu, value), do: Map.put(cpu, :delayed_ime, value)
  def delayed_ime(cpu), do: cpu.delayed_ime

  @compile {:inline, set_state: 2, state: 1}
  def state(cpu), do: cpu.state
  def set_state(cpu, state), do: Map.put(cpu, :state, state)

  @compile {:inline, opcode: 1}
  def opcode(cpu), do: cpu.opcode

end
