defmodule Gameboy.Cpu.Decode do
  # alias Gameboy.Cpu
  # alias Gameboy.RecordCpu, as: Cpu
  alias Gameboy.SmallCpu, as: Cpu
  alias Gameboy.Cpu.Execute, as: Exec
  alias Gameboy.Utils
  alias Gameboy.Hardware

  def cpu_step(cpu, hw) do
    {cpu, hw} = Cpu.handle_interrupt(cpu, hw)
    state = Cpu.state(cpu)
    case state do
      :running ->
        {cpu, hw} = Cpu.fetch_next(cpu, hw, Cpu.read_register(cpu, :pc))
        decode_exec(cpu, hw)
      :haltbug ->
        # Halt bug. Fetch but don't increment pc
        pc = Cpu.read_register(cpu, :pc)
        {cpu, hw} = Cpu.fetch_next(cpu, hw, pc)
        cpu = Cpu.write_register(cpu, :pc, pc)
              |> Cpu.set_state(:running)
        decode_exec(cpu, hw)
      :halt ->
        # IO.puts("Halt")
        {cpu, Hardware.sync_cycle(hw)}
      _ -> # stop?
        # IO.puts("stop")
        {cpu, hw}
    end
  end

  # def decode_exec(%{opcode: opcode, delayed_ime: nil} = cpu, hw) do
  #   instruction(opcode, cpu, hw)
  # end
  # def decode_exec(%{opcode: opcode, delayed_ime: ime_value} = cpu, hw) do
  #   {cpu, hw} = instruction(opcode, cpu, hw)
  #   # {%{cpu | ime: ime_value, delayed_ime: nil}, hw}
  #   {Cpu.apply_delayed_ime(cpu), hw}
  # end

  def decode_exec(cpu, hw) do
    opcode = Cpu.opcode(cpu)
    delayed_ime = Cpu.delayed_ime(cpu)
    if delayed_ime == nil do
      instruction(opcode, cpu, hw)
    else
      {cpu, hw} = instruction(opcode, cpu, hw)
      {Cpu.apply_delayed_ime(cpu, delayed_ime), hw}
    end
  end

  def cb_prefix(cpu, hw) do
    {cpu, hw} = Cpu.fetch_next(cpu, hw, Cpu.read_register(cpu, :pc))
    # IO.puts("CB #{Utils.to_hex(cpu.opcode, 2)}")
    cb_instruction(Cpu.opcode(cpu), cpu, hw)
  end
  
  # 8 bit loads
  def instruction(0x7f, cpu, hw), do: Exec.ld(cpu, hw, :a, :a)
  def instruction(0x78, cpu, hw), do: Exec.ld(cpu, hw, :a, :b)
  def instruction(0x79, cpu, hw), do: Exec.ld(cpu, hw, :a, :c)
  def instruction(0x7a, cpu, hw), do: Exec.ld(cpu, hw, :a, :d)
  def instruction(0x7b, cpu, hw), do: Exec.ld(cpu, hw, :a, :e)
  def instruction(0x7c, cpu, hw), do: Exec.ld(cpu, hw, :a, :h)
  def instruction(0x7d, cpu, hw), do: Exec.ld(cpu, hw, :a, :l)
  def instruction(0x7e, cpu, hw), do: Exec.ld(cpu, hw, :a, :hl)
  def instruction(0x47, cpu, hw), do: Exec.ld(cpu, hw, :b, :a)

  def instruction(0x40, cpu, hw), do: Exec.ld(cpu, hw, :b, :b)
  # def instruction(0x40, cpu, hw), do: Exec.debug(cpu, hw)

  def instruction(0x41, cpu, hw), do: Exec.ld(cpu, hw, :b, :c)
  def instruction(0x42, cpu, hw), do: Exec.ld(cpu, hw, :b, :d)
  def instruction(0x43, cpu, hw), do: Exec.ld(cpu, hw, :b, :e)
  def instruction(0x44, cpu, hw), do: Exec.ld(cpu, hw, :b, :h)
  def instruction(0x45, cpu, hw), do: Exec.ld(cpu, hw, :b, :l)
  def instruction(0x46, cpu, hw), do: Exec.ld(cpu, hw, :b, :hl)
  def instruction(0x4f, cpu, hw), do: Exec.ld(cpu, hw, :c, :a)
  def instruction(0x48, cpu, hw), do: Exec.ld(cpu, hw, :c, :b)
  def instruction(0x49, cpu, hw), do: Exec.ld(cpu, hw, :c, :c)
  def instruction(0x4a, cpu, hw), do: Exec.ld(cpu, hw, :c, :d)
  def instruction(0x4b, cpu, hw), do: Exec.ld(cpu, hw, :c, :e)
  def instruction(0x4c, cpu, hw), do: Exec.ld(cpu, hw, :c, :h)
  def instruction(0x4d, cpu, hw), do: Exec.ld(cpu, hw, :c, :l)
  def instruction(0x4e, cpu, hw), do: Exec.ld(cpu, hw, :c, :hl)
  def instruction(0x57, cpu, hw), do: Exec.ld(cpu, hw, :d, :a)
  def instruction(0x50, cpu, hw), do: Exec.ld(cpu, hw, :d, :b)
  def instruction(0x51, cpu, hw), do: Exec.ld(cpu, hw, :d, :c)
  def instruction(0x52, cpu, hw), do: Exec.ld(cpu, hw, :d, :d)
  def instruction(0x53, cpu, hw), do: Exec.ld(cpu, hw, :d, :e)
  def instruction(0x54, cpu, hw), do: Exec.ld(cpu, hw, :d, :h)
  def instruction(0x55, cpu, hw), do: Exec.ld(cpu, hw, :d, :l)
  def instruction(0x56, cpu, hw), do: Exec.ld(cpu, hw, :d, :hl)
  def instruction(0x5f, cpu, hw), do: Exec.ld(cpu, hw, :e, :a)
  def instruction(0x58, cpu, hw), do: Exec.ld(cpu, hw, :e, :b)
  def instruction(0x59, cpu, hw), do: Exec.ld(cpu, hw, :e, :c)
  def instruction(0x5a, cpu, hw), do: Exec.ld(cpu, hw, :e, :d)
  def instruction(0x5b, cpu, hw), do: Exec.ld(cpu, hw, :e, :e)
  def instruction(0x5c, cpu, hw), do: Exec.ld(cpu, hw, :e, :h)
  def instruction(0x5d, cpu, hw), do: Exec.ld(cpu, hw, :e, :l)
  def instruction(0x5e, cpu, hw), do: Exec.ld(cpu, hw, :e, :hl)
  def instruction(0x67, cpu, hw), do: Exec.ld(cpu, hw, :h, :a)
  def instruction(0x60, cpu, hw), do: Exec.ld(cpu, hw, :h, :b)
  def instruction(0x61, cpu, hw), do: Exec.ld(cpu, hw, :h, :c)
  def instruction(0x62, cpu, hw), do: Exec.ld(cpu, hw, :h, :d)
  def instruction(0x63, cpu, hw), do: Exec.ld(cpu, hw, :h, :e)
  def instruction(0x64, cpu, hw), do: Exec.ld(cpu, hw, :h, :h)
  def instruction(0x65, cpu, hw), do: Exec.ld(cpu, hw, :h, :l)
  def instruction(0x66, cpu, hw), do: Exec.ld(cpu, hw, :h, :hl)
  def instruction(0x6f, cpu, hw), do: Exec.ld(cpu, hw, :l, :a)
  def instruction(0x68, cpu, hw), do: Exec.ld(cpu, hw, :l, :b)
  def instruction(0x69, cpu, hw), do: Exec.ld(cpu, hw, :l, :c)
  def instruction(0x6a, cpu, hw), do: Exec.ld(cpu, hw, :l, :d)
  def instruction(0x6b, cpu, hw), do: Exec.ld(cpu, hw, :l, :e)
  def instruction(0x6c, cpu, hw), do: Exec.ld(cpu, hw, :l, :h)
  def instruction(0x6d, cpu, hw), do: Exec.ld(cpu, hw, :l, :l)
  def instruction(0x6e, cpu, hw), do: Exec.ld(cpu, hw, :l, :hl)
  def instruction(0x3e, cpu, hw), do: Exec.ld(cpu, hw, :a, :imm)
  def instruction(0x06, cpu, hw), do: Exec.ld(cpu, hw, :b, :imm)
  def instruction(0x0e, cpu, hw), do: Exec.ld(cpu, hw, :c, :imm)
  def instruction(0x16, cpu, hw), do: Exec.ld(cpu, hw, :d, :imm)
  def instruction(0x1e, cpu, hw), do: Exec.ld(cpu, hw, :e, :imm)
  def instruction(0x26, cpu, hw), do: Exec.ld(cpu, hw, :h, :imm)
  def instruction(0x2e, cpu, hw), do: Exec.ld(cpu, hw, :l, :imm)
  def instruction(0x36, cpu, hw), do: Exec.ld(cpu, hw, :hl, :imm)
  def instruction(0x77, cpu, hw), do: Exec.ld(cpu, hw, :hl, :a)
  def instruction(0x70, cpu, hw), do: Exec.ld(cpu, hw, :hl, :b)
  def instruction(0x71, cpu, hw), do: Exec.ld(cpu, hw, :hl, :c)
  def instruction(0x72, cpu, hw), do: Exec.ld(cpu, hw, :hl, :d)
  def instruction(0x73, cpu, hw), do: Exec.ld(cpu, hw, :hl, :e)
  def instruction(0x74, cpu, hw), do: Exec.ld(cpu, hw, :hl, :h)
  def instruction(0x75, cpu, hw), do: Exec.ld(cpu, hw, :hl, :l)
  def instruction(0x0a, cpu, hw), do: Exec.ld(cpu, hw, :a, :bc)
  def instruction(0x1a, cpu, hw), do: Exec.ld(cpu, hw, :a, :de)
  def instruction(0xfa, cpu, hw), do: Exec.ld(cpu, hw, :a, :immaddr)
  def instruction(0x3a, cpu, hw), do: Exec.ld(cpu, hw, :a, :hld)
  def instruction(0x2a, cpu, hw), do: Exec.ld(cpu, hw, :a, :hli)
  def instruction(0xf0, cpu, hw), do: Exec.ld(cpu, hw, :a, :hi)
  def instruction(0xf2, cpu, hw), do: Exec.ld(cpu, hw, :a, :hic)
  def instruction(0x02, cpu, hw), do: Exec.ld(cpu, hw, :bc, :a)
  def instruction(0x12, cpu, hw), do: Exec.ld(cpu, hw, :de, :a)
  def instruction(0xea, cpu, hw), do: Exec.ld(cpu, hw, :immaddr, :a)
  def instruction(0x32, cpu, hw), do: Exec.ld(cpu, hw, :hld, :a)
  def instruction(0x22, cpu, hw), do: Exec.ld(cpu, hw, :hli, :a)
  def instruction(0xe0, cpu, hw), do: Exec.ld(cpu, hw, :hi, :a)
  def instruction(0xe2, cpu, hw), do: Exec.ld(cpu, hw, :hic, :a)

  # 8-bit arithmetic
  def instruction(0x87, cpu, hw), do: Exec.add(cpu, hw, :a, :a)
  def instruction(0x80, cpu, hw), do: Exec.add(cpu, hw, :a, :b)
  def instruction(0x81, cpu, hw), do: Exec.add(cpu, hw, :a, :c)
  def instruction(0x82, cpu, hw), do: Exec.add(cpu, hw, :a, :d)
  def instruction(0x83, cpu, hw), do: Exec.add(cpu, hw, :a, :e)
  def instruction(0x84, cpu, hw), do: Exec.add(cpu, hw, :a, :h)
  def instruction(0x85, cpu, hw), do: Exec.add(cpu, hw, :a, :l)
  def instruction(0x86, cpu, hw), do: Exec.add(cpu, hw, :a, :hl)
  def instruction(0xc6, cpu, hw), do: Exec.add(cpu, hw, :a, :imm)
  def instruction(0x8f, cpu, hw), do: Exec.adc(cpu, hw, :a, :a)
  def instruction(0x88, cpu, hw), do: Exec.adc(cpu, hw, :a, :b)
  def instruction(0x89, cpu, hw), do: Exec.adc(cpu, hw, :a, :c)
  def instruction(0x8a, cpu, hw), do: Exec.adc(cpu, hw, :a, :d)
  def instruction(0x8b, cpu, hw), do: Exec.adc(cpu, hw, :a, :e)
  def instruction(0x8c, cpu, hw), do: Exec.adc(cpu, hw, :a, :h)
  def instruction(0x8d, cpu, hw), do: Exec.adc(cpu, hw, :a, :l)
  def instruction(0x8e, cpu, hw), do: Exec.adc(cpu, hw, :a, :hl)
  def instruction(0xce, cpu, hw), do: Exec.adc(cpu, hw, :a, :imm)
  def instruction(0x97, cpu, hw), do: Exec.sub(cpu, hw, :a, :a)
  def instruction(0x90, cpu, hw), do: Exec.sub(cpu, hw, :a, :b)
  def instruction(0x91, cpu, hw), do: Exec.sub(cpu, hw, :a, :c)
  def instruction(0x92, cpu, hw), do: Exec.sub(cpu, hw, :a, :d)
  def instruction(0x93, cpu, hw), do: Exec.sub(cpu, hw, :a, :e)
  def instruction(0x94, cpu, hw), do: Exec.sub(cpu, hw, :a, :h)
  def instruction(0x95, cpu, hw), do: Exec.sub(cpu, hw, :a, :l)
  def instruction(0x96, cpu, hw), do: Exec.sub(cpu, hw, :a, :hl)
  def instruction(0xd6, cpu, hw), do: Exec.sub(cpu, hw, :a, :imm)
  def instruction(0x9f, cpu, hw), do: Exec.sbc(cpu, hw, :a, :a)
  def instruction(0x98, cpu, hw), do: Exec.sbc(cpu, hw, :a, :b)
  def instruction(0x99, cpu, hw), do: Exec.sbc(cpu, hw, :a, :c)
  def instruction(0x9a, cpu, hw), do: Exec.sbc(cpu, hw, :a, :d)
  def instruction(0x9b, cpu, hw), do: Exec.sbc(cpu, hw, :a, :e)
  def instruction(0x9c, cpu, hw), do: Exec.sbc(cpu, hw, :a, :h)
  def instruction(0x9d, cpu, hw), do: Exec.sbc(cpu, hw, :a, :l)
  def instruction(0x9e, cpu, hw), do: Exec.sbc(cpu, hw, :a, :hl)
  def instruction(0xde, cpu, hw), do: Exec.sbc(cpu, hw, :a, :imm)
  def instruction(0xa7, cpu, hw), do: Exec.and_op(cpu, hw, :a, :a)
  def instruction(0xa0, cpu, hw), do: Exec.and_op(cpu, hw, :a, :b)
  def instruction(0xa1, cpu, hw), do: Exec.and_op(cpu, hw, :a, :c)
  def instruction(0xa2, cpu, hw), do: Exec.and_op(cpu, hw, :a, :d)
  def instruction(0xa3, cpu, hw), do: Exec.and_op(cpu, hw, :a, :e)
  def instruction(0xa4, cpu, hw), do: Exec.and_op(cpu, hw, :a, :h)
  def instruction(0xa5, cpu, hw), do: Exec.and_op(cpu, hw, :a, :l)
  def instruction(0xa6, cpu, hw), do: Exec.and_op(cpu, hw, :a, :hl)
  def instruction(0xe6, cpu, hw), do: Exec.and_op(cpu, hw, :a, :imm)
  def instruction(0xb7, cpu, hw), do: Exec.or_op(cpu, hw, :a, :a)
  def instruction(0xb0, cpu, hw), do: Exec.or_op(cpu, hw, :a, :b)
  def instruction(0xb1, cpu, hw), do: Exec.or_op(cpu, hw, :a, :c)
  def instruction(0xb2, cpu, hw), do: Exec.or_op(cpu, hw, :a, :d)
  def instruction(0xb3, cpu, hw), do: Exec.or_op(cpu, hw, :a, :e)
  def instruction(0xb4, cpu, hw), do: Exec.or_op(cpu, hw, :a, :h)
  def instruction(0xb5, cpu, hw), do: Exec.or_op(cpu, hw, :a, :l)
  def instruction(0xb6, cpu, hw), do: Exec.or_op(cpu, hw, :a, :hl)
  def instruction(0xf6, cpu, hw), do: Exec.or_op(cpu, hw, :a, :imm)
  def instruction(0xaf, cpu, hw), do: Exec.xor(cpu, hw, :a, :a)
  def instruction(0xa8, cpu, hw), do: Exec.xor(cpu, hw, :a, :b)
  def instruction(0xa9, cpu, hw), do: Exec.xor(cpu, hw, :a, :c)
  def instruction(0xaa, cpu, hw), do: Exec.xor(cpu, hw, :a, :d)
  def instruction(0xab, cpu, hw), do: Exec.xor(cpu, hw, :a, :e)
  def instruction(0xac, cpu, hw), do: Exec.xor(cpu, hw, :a, :h)
  def instruction(0xad, cpu, hw), do: Exec.xor(cpu, hw, :a, :l)
  def instruction(0xae, cpu, hw), do: Exec.xor(cpu, hw, :a, :hl)
  def instruction(0xee, cpu, hw), do: Exec.xor(cpu, hw, :a, :imm)
  def instruction(0xbf, cpu, hw), do: Exec.cp(cpu, hw, :a, :a)
  def instruction(0xb8, cpu, hw), do: Exec.cp(cpu, hw, :a, :b)
  def instruction(0xb9, cpu, hw), do: Exec.cp(cpu, hw, :a, :c)
  def instruction(0xba, cpu, hw), do: Exec.cp(cpu, hw, :a, :d)
  def instruction(0xbb, cpu, hw), do: Exec.cp(cpu, hw, :a, :e)
  def instruction(0xbc, cpu, hw), do: Exec.cp(cpu, hw, :a, :h)
  def instruction(0xbd, cpu, hw), do: Exec.cp(cpu, hw, :a, :l)
  def instruction(0xbe, cpu, hw), do: Exec.cp(cpu, hw, :a, :hl)
  def instruction(0xfe, cpu, hw), do: Exec.cp(cpu, hw, :a, :imm)
  def instruction(0x3c, cpu, hw), do: Exec.inc(cpu, hw, :a)
  def instruction(0x04, cpu, hw), do: Exec.inc(cpu, hw, :b)
  def instruction(0x0c, cpu, hw), do: Exec.inc(cpu, hw, :c)
  def instruction(0x14, cpu, hw), do: Exec.inc(cpu, hw, :d)
  def instruction(0x1c, cpu, hw), do: Exec.inc(cpu, hw, :e)
  def instruction(0x24, cpu, hw), do: Exec.inc(cpu, hw, :h)
  def instruction(0x2c, cpu, hw), do: Exec.inc(cpu, hw, :l)
  def instruction(0x34, cpu, hw), do: Exec.inc(cpu, hw, :hl)
  def instruction(0x3d, cpu, hw), do: Exec.dec(cpu, hw, :a)
  def instruction(0x05, cpu, hw), do: Exec.dec(cpu, hw, :b)
  def instruction(0x0d, cpu, hw), do: Exec.dec(cpu, hw, :c)
  def instruction(0x15, cpu, hw), do: Exec.dec(cpu, hw, :d)
  def instruction(0x1d, cpu, hw), do: Exec.dec(cpu, hw, :e)
  def instruction(0x25, cpu, hw), do: Exec.dec(cpu, hw, :h)
  def instruction(0x2d, cpu, hw), do: Exec.dec(cpu, hw, :l)
  def instruction(0x35, cpu, hw), do: Exec.dec(cpu, hw, :hl)
  def instruction(0x07, cpu, hw), do: Exec.rlca(cpu, hw)
  def instruction(0x17, cpu, hw), do: Exec.rla(cpu, hw)
  def instruction(0x0f, cpu, hw), do: Exec.rrca(cpu, hw)
  def instruction(0x1f, cpu, hw), do: Exec.rra(cpu, hw)

  # Control instructions
  def instruction(0xc3, cpu, hw), do: Exec.jp_nn(cpu, hw)
  def instruction(0xe9, cpu, hw), do: Exec.jp_hl(cpu, hw)
  def instruction(0x18, cpu, hw), do: Exec.jr_n(cpu, hw)
  def instruction(0xcd, cpu, hw), do: Exec.call_nn(cpu, hw)
  def instruction(0xc9, cpu, hw), do: Exec.ret(cpu, hw)
  def instruction(0xd9, cpu, hw), do: Exec.reti(cpu, hw)
  def instruction(0xc2, cpu, hw), do: Exec.jp_cc_nn(cpu, hw, :nz)
  def instruction(0xca, cpu, hw), do: Exec.jp_cc_nn(cpu, hw, :z)
  def instruction(0xd2, cpu, hw), do: Exec.jp_cc_nn(cpu, hw, :nc)
  def instruction(0xda, cpu, hw), do: Exec.jp_cc_nn(cpu, hw, :c)
  def instruction(0x20, cpu, hw), do: Exec.jr_cc_n(cpu, hw, :nz)
  def instruction(0x28, cpu, hw), do: Exec.jr_cc_n(cpu, hw, :z)
  def instruction(0x30, cpu, hw), do: Exec.jr_cc_n(cpu, hw, :nc)
  def instruction(0x38, cpu, hw), do: Exec.jr_cc_n(cpu, hw, :c)
  def instruction(0xc4, cpu, hw), do: Exec.call_cc_nn(cpu, hw, :nz)
  def instruction(0xcc, cpu, hw), do: Exec.call_cc_nn(cpu, hw, :z)
  def instruction(0xd4, cpu, hw), do: Exec.call_cc_nn(cpu, hw, :nc)
  def instruction(0xdc, cpu, hw), do: Exec.call_cc_nn(cpu, hw, :c)
  def instruction(0xc0, cpu, hw), do: Exec.ret_cc(cpu, hw, :nz)
  def instruction(0xc8, cpu, hw), do: Exec.ret_cc(cpu, hw, :z)
  def instruction(0xd0, cpu, hw), do: Exec.ret_cc(cpu, hw, :nc)
  def instruction(0xd8, cpu, hw), do: Exec.ret_cc(cpu, hw, :c)
  def instruction(0xc7, cpu, hw), do: Exec.rst(cpu, hw, 0x00)
  def instruction(0xcf, cpu, hw), do: Exec.rst(cpu, hw, 0x08)
  def instruction(0xd7, cpu, hw), do: Exec.rst(cpu, hw, 0x10)
  def instruction(0xdf, cpu, hw), do: Exec.rst(cpu, hw, 0x18)
  def instruction(0xe7, cpu, hw), do: Exec.rst(cpu, hw, 0x20)
  def instruction(0xef, cpu, hw), do: Exec.rst(cpu, hw, 0x28)
  def instruction(0xf7, cpu, hw), do: Exec.rst(cpu, hw, 0x30)
  def instruction(0xff, cpu, hw), do: Exec.rst(cpu, hw, 0x38)

  # Miscellaneous
  def instruction(0x76, cpu, hw), do: Exec.halt(cpu, hw)
  def instruction(0x10, cpu, hw), do: Exec.stop(cpu, hw)
  def instruction(0xf3, cpu, hw), do: Exec.di(cpu, hw)
  def instruction(0xfb, cpu, hw), do: Exec.ei(cpu, hw)
  def instruction(0x3f, cpu, hw), do: Exec.ccf(cpu, hw)
  def instruction(0x37, cpu, hw), do: Exec.scf(cpu, hw)
  def instruction(0x00, cpu, hw), do: Exec.nop(cpu, hw)
  def instruction(0x27, cpu, hw), do: Exec.daa(cpu, hw)
  def instruction(0x2f, cpu, hw), do: Exec.cpl(cpu, hw)

  # 16-bit loads/pop/push
  def instruction(0x01, cpu, hw), do: Exec.ld16_rr_nn(cpu, hw, :bc)
  def instruction(0x11, cpu, hw), do: Exec.ld16_rr_nn(cpu, hw, :de)
  def instruction(0x21, cpu, hw), do: Exec.ld16_rr_nn(cpu, hw, :hl)
  def instruction(0x31, cpu, hw), do: Exec.ld16_rr_nn(cpu, hw, :sp)
  def instruction(0xf9, cpu, hw), do: Exec.ld16_sp_hl(cpu, hw)
  def instruction(0xf8, cpu, hw), do: Exec.ld16_hl_sp_n(cpu, hw)
  def instruction(0x08, cpu, hw), do: Exec.ld16_nn_sp(cpu, hw)
  def instruction(0xf5, cpu, hw), do: Exec.push16_rr(cpu, hw, :af)
  def instruction(0xc5, cpu, hw), do: Exec.push16_rr(cpu, hw, :bc)
  def instruction(0xd5, cpu, hw), do: Exec.push16_rr(cpu, hw, :de)
  def instruction(0xe5, cpu, hw), do: Exec.push16_rr(cpu, hw, :hl)
  def instruction(0xf1, cpu, hw), do: Exec.pop16_rr(cpu, hw, :af)
  def instruction(0xc1, cpu, hw), do: Exec.pop16_rr(cpu, hw, :bc)
  def instruction(0xd1, cpu, hw), do: Exec.pop16_rr(cpu, hw, :de)
  def instruction(0xe1, cpu, hw), do: Exec.pop16_rr(cpu, hw, :hl)

  # 16-bit arithmetic
  def instruction(0x09, cpu, hw), do: Exec.add16_hl_rr(cpu, hw, :bc)
  def instruction(0x19, cpu, hw), do: Exec.add16_hl_rr(cpu, hw, :de)
  def instruction(0x29, cpu, hw), do: Exec.add16_hl_rr(cpu, hw, :hl)
  def instruction(0x39, cpu, hw), do: Exec.add16_hl_rr(cpu, hw, :sp)
  def instruction(0xe8, cpu, hw), do: Exec.add16_sp_n(cpu, hw)
  def instruction(0x03, cpu, hw), do: Exec.inc16_rr(cpu, hw, :bc)
  def instruction(0x13, cpu, hw), do: Exec.inc16_rr(cpu, hw, :de)
  def instruction(0x23, cpu, hw), do: Exec.inc16_rr(cpu, hw, :hl)
  def instruction(0x33, cpu, hw), do: Exec.inc16_rr(cpu, hw, :sp)
  def instruction(0x0b, cpu, hw), do: Exec.dec16_rr(cpu, hw, :bc)
  def instruction(0x1b, cpu, hw), do: Exec.dec16_rr(cpu, hw, :de)
  def instruction(0x2b, cpu, hw), do: Exec.dec16_rr(cpu, hw, :hl)
  def instruction(0x3b, cpu, hw), do: Exec.dec16_rr(cpu, hw, :sp)

  def instruction(0xcb, cpu, hw), do: cb_prefix(cpu, hw)

  # 2 byte instructions
  #
  # 8-bit arithmetic
  def cb_instruction(0x07, cpu, hw), do: Exec.rlc(cpu, hw, :a)
  def cb_instruction(0x00, cpu, hw), do: Exec.rlc(cpu, hw, :b)
  def cb_instruction(0x01, cpu, hw), do: Exec.rlc(cpu, hw, :c)
  def cb_instruction(0x02, cpu, hw), do: Exec.rlc(cpu, hw, :d)
  def cb_instruction(0x03, cpu, hw), do: Exec.rlc(cpu, hw, :e)
  def cb_instruction(0x04, cpu, hw), do: Exec.rlc(cpu, hw, :h)
  def cb_instruction(0x05, cpu, hw), do: Exec.rlc(cpu, hw, :l)
  def cb_instruction(0x06, cpu, hw), do: Exec.rlc(cpu, hw, :hl)
  def cb_instruction(0x17, cpu, hw), do: Exec.rl(cpu, hw, :a)
  def cb_instruction(0x10, cpu, hw), do: Exec.rl(cpu, hw, :b)
  def cb_instruction(0x11, cpu, hw), do: Exec.rl(cpu, hw, :c)
  def cb_instruction(0x12, cpu, hw), do: Exec.rl(cpu, hw, :d)
  def cb_instruction(0x13, cpu, hw), do: Exec.rl(cpu, hw, :e)
  def cb_instruction(0x14, cpu, hw), do: Exec.rl(cpu, hw, :h)
  def cb_instruction(0x15, cpu, hw), do: Exec.rl(cpu, hw, :l)
  def cb_instruction(0x16, cpu, hw), do: Exec.rl(cpu, hw, :hl)
  def cb_instruction(0x0f, cpu, hw), do: Exec.rrc(cpu, hw, :a)
  def cb_instruction(0x08, cpu, hw), do: Exec.rrc(cpu, hw, :b)
  def cb_instruction(0x09, cpu, hw), do: Exec.rrc(cpu, hw, :c)
  def cb_instruction(0x0a, cpu, hw), do: Exec.rrc(cpu, hw, :d)
  def cb_instruction(0x0b, cpu, hw), do: Exec.rrc(cpu, hw, :e)
  def cb_instruction(0x0c, cpu, hw), do: Exec.rrc(cpu, hw, :h)
  def cb_instruction(0x0d, cpu, hw), do: Exec.rrc(cpu, hw, :l)
  def cb_instruction(0x0e, cpu, hw), do: Exec.rrc(cpu, hw, :hl)
  def cb_instruction(0x1f, cpu, hw), do: Exec.rr(cpu, hw, :a)
  def cb_instruction(0x18, cpu, hw), do: Exec.rr(cpu, hw, :b)
  def cb_instruction(0x19, cpu, hw), do: Exec.rr(cpu, hw, :c)
  def cb_instruction(0x1a, cpu, hw), do: Exec.rr(cpu, hw, :d)
  def cb_instruction(0x1b, cpu, hw), do: Exec.rr(cpu, hw, :e)
  def cb_instruction(0x1c, cpu, hw), do: Exec.rr(cpu, hw, :h)
  def cb_instruction(0x1d, cpu, hw), do: Exec.rr(cpu, hw, :l)
  def cb_instruction(0x1e, cpu, hw), do: Exec.rr(cpu, hw, :hl)
  def cb_instruction(0x27, cpu, hw), do: Exec.sla(cpu, hw, :a)
  def cb_instruction(0x20, cpu, hw), do: Exec.sla(cpu, hw, :b)
  def cb_instruction(0x21, cpu, hw), do: Exec.sla(cpu, hw, :c)
  def cb_instruction(0x22, cpu, hw), do: Exec.sla(cpu, hw, :d)
  def cb_instruction(0x23, cpu, hw), do: Exec.sla(cpu, hw, :e)
  def cb_instruction(0x24, cpu, hw), do: Exec.sla(cpu, hw, :h)
  def cb_instruction(0x25, cpu, hw), do: Exec.sla(cpu, hw, :l)
  def cb_instruction(0x26, cpu, hw), do: Exec.sla(cpu, hw, :hl)
  def cb_instruction(0x2f, cpu, hw), do: Exec.sra(cpu, hw, :a)
  def cb_instruction(0x28, cpu, hw), do: Exec.sra(cpu, hw, :b)
  def cb_instruction(0x29, cpu, hw), do: Exec.sra(cpu, hw, :c)
  def cb_instruction(0x2a, cpu, hw), do: Exec.sra(cpu, hw, :d)
  def cb_instruction(0x2b, cpu, hw), do: Exec.sra(cpu, hw, :e)
  def cb_instruction(0x2c, cpu, hw), do: Exec.sra(cpu, hw, :h)
  def cb_instruction(0x2d, cpu, hw), do: Exec.sra(cpu, hw, :l)
  def cb_instruction(0x2e, cpu, hw), do: Exec.sra(cpu, hw, :hl)
  def cb_instruction(0x3f, cpu, hw), do: Exec.srl(cpu, hw, :a)
  def cb_instruction(0x38, cpu, hw), do: Exec.srl(cpu, hw, :b)
  def cb_instruction(0x39, cpu, hw), do: Exec.srl(cpu, hw, :c)
  def cb_instruction(0x3a, cpu, hw), do: Exec.srl(cpu, hw, :d)
  def cb_instruction(0x3b, cpu, hw), do: Exec.srl(cpu, hw, :e)
  def cb_instruction(0x3c, cpu, hw), do: Exec.srl(cpu, hw, :h)
  def cb_instruction(0x3d, cpu, hw), do: Exec.srl(cpu, hw, :l)
  def cb_instruction(0x3e, cpu, hw), do: Exec.srl(cpu, hw, :hl)
  def cb_instruction(0x37, cpu, hw), do: Exec.swap(cpu, hw, :a)
  def cb_instruction(0x30, cpu, hw), do: Exec.swap(cpu, hw, :b)
  def cb_instruction(0x31, cpu, hw), do: Exec.swap(cpu, hw, :c)
  def cb_instruction(0x32, cpu, hw), do: Exec.swap(cpu, hw, :d)
  def cb_instruction(0x33, cpu, hw), do: Exec.swap(cpu, hw, :e)
  def cb_instruction(0x34, cpu, hw), do: Exec.swap(cpu, hw, :h)
  def cb_instruction(0x35, cpu, hw), do: Exec.swap(cpu, hw, :l)
  def cb_instruction(0x36, cpu, hw), do: Exec.swap(cpu, hw, :hl)
  def cb_instruction(0x47, cpu, hw), do: Exec.bit(cpu, hw, 0x0, :a)
  def cb_instruction(0x4f, cpu, hw), do: Exec.bit(cpu, hw, 0x1, :a)
  def cb_instruction(0x57, cpu, hw), do: Exec.bit(cpu, hw, 0x2, :a)
  def cb_instruction(0x5f, cpu, hw), do: Exec.bit(cpu, hw, 0x3, :a)
  def cb_instruction(0x67, cpu, hw), do: Exec.bit(cpu, hw, 0x4, :a)
  def cb_instruction(0x6f, cpu, hw), do: Exec.bit(cpu, hw, 0x5, :a)
  def cb_instruction(0x77, cpu, hw), do: Exec.bit(cpu, hw, 0x6, :a)
  def cb_instruction(0x7f, cpu, hw), do: Exec.bit(cpu, hw, 0x7, :a)
  def cb_instruction(0x40, cpu, hw), do: Exec.bit(cpu, hw, 0x0, :b)
  def cb_instruction(0x48, cpu, hw), do: Exec.bit(cpu, hw, 0x1, :b)
  def cb_instruction(0x50, cpu, hw), do: Exec.bit(cpu, hw, 0x2, :b)
  def cb_instruction(0x58, cpu, hw), do: Exec.bit(cpu, hw, 0x3, :b)
  def cb_instruction(0x60, cpu, hw), do: Exec.bit(cpu, hw, 0x4, :b)
  def cb_instruction(0x68, cpu, hw), do: Exec.bit(cpu, hw, 0x5, :b)
  def cb_instruction(0x70, cpu, hw), do: Exec.bit(cpu, hw, 0x6, :b)
  def cb_instruction(0x78, cpu, hw), do: Exec.bit(cpu, hw, 0x7, :b)
  def cb_instruction(0x41, cpu, hw), do: Exec.bit(cpu, hw, 0x0, :c)
  def cb_instruction(0x49, cpu, hw), do: Exec.bit(cpu, hw, 0x1, :c)
  def cb_instruction(0x51, cpu, hw), do: Exec.bit(cpu, hw, 0x2, :c)
  def cb_instruction(0x59, cpu, hw), do: Exec.bit(cpu, hw, 0x3, :c)
  def cb_instruction(0x61, cpu, hw), do: Exec.bit(cpu, hw, 0x4, :c)
  def cb_instruction(0x69, cpu, hw), do: Exec.bit(cpu, hw, 0x5, :c)
  def cb_instruction(0x71, cpu, hw), do: Exec.bit(cpu, hw, 0x6, :c)
  def cb_instruction(0x79, cpu, hw), do: Exec.bit(cpu, hw, 0x7, :c)
  def cb_instruction(0x42, cpu, hw), do: Exec.bit(cpu, hw, 0x0, :d)
  def cb_instruction(0x4a, cpu, hw), do: Exec.bit(cpu, hw, 0x1, :d)
  def cb_instruction(0x52, cpu, hw), do: Exec.bit(cpu, hw, 0x2, :d)
  def cb_instruction(0x5a, cpu, hw), do: Exec.bit(cpu, hw, 0x3, :d)
  def cb_instruction(0x62, cpu, hw), do: Exec.bit(cpu, hw, 0x4, :d)
  def cb_instruction(0x6a, cpu, hw), do: Exec.bit(cpu, hw, 0x5, :d)
  def cb_instruction(0x72, cpu, hw), do: Exec.bit(cpu, hw, 0x6, :d)
  def cb_instruction(0x7a, cpu, hw), do: Exec.bit(cpu, hw, 0x7, :d)
  def cb_instruction(0x43, cpu, hw), do: Exec.bit(cpu, hw, 0x0, :e)
  def cb_instruction(0x4b, cpu, hw), do: Exec.bit(cpu, hw, 0x1, :e)
  def cb_instruction(0x53, cpu, hw), do: Exec.bit(cpu, hw, 0x2, :e)
  def cb_instruction(0x5b, cpu, hw), do: Exec.bit(cpu, hw, 0x3, :e)
  def cb_instruction(0x63, cpu, hw), do: Exec.bit(cpu, hw, 0x4, :e)
  def cb_instruction(0x6b, cpu, hw), do: Exec.bit(cpu, hw, 0x5, :e)
  def cb_instruction(0x73, cpu, hw), do: Exec.bit(cpu, hw, 0x6, :e)
  def cb_instruction(0x7b, cpu, hw), do: Exec.bit(cpu, hw, 0x7, :e)
  def cb_instruction(0x44, cpu, hw), do: Exec.bit(cpu, hw, 0x0, :h)
  def cb_instruction(0x4c, cpu, hw), do: Exec.bit(cpu, hw, 0x1, :h)
  def cb_instruction(0x54, cpu, hw), do: Exec.bit(cpu, hw, 0x2, :h)
  def cb_instruction(0x5c, cpu, hw), do: Exec.bit(cpu, hw, 0x3, :h)
  def cb_instruction(0x64, cpu, hw), do: Exec.bit(cpu, hw, 0x4, :h)
  def cb_instruction(0x6c, cpu, hw), do: Exec.bit(cpu, hw, 0x5, :h)
  def cb_instruction(0x74, cpu, hw), do: Exec.bit(cpu, hw, 0x6, :h)
  def cb_instruction(0x7c, cpu, hw), do: Exec.bit(cpu, hw, 0x7, :h)
  def cb_instruction(0x45, cpu, hw), do: Exec.bit(cpu, hw, 0x0, :l)
  def cb_instruction(0x4d, cpu, hw), do: Exec.bit(cpu, hw, 0x1, :l)
  def cb_instruction(0x55, cpu, hw), do: Exec.bit(cpu, hw, 0x2, :l)
  def cb_instruction(0x5d, cpu, hw), do: Exec.bit(cpu, hw, 0x3, :l)
  def cb_instruction(0x65, cpu, hw), do: Exec.bit(cpu, hw, 0x4, :l)
  def cb_instruction(0x6d, cpu, hw), do: Exec.bit(cpu, hw, 0x5, :l)
  def cb_instruction(0x75, cpu, hw), do: Exec.bit(cpu, hw, 0x6, :l)
  def cb_instruction(0x7d, cpu, hw), do: Exec.bit(cpu, hw, 0x7, :l)
  def cb_instruction(0x46, cpu, hw), do: Exec.bit(cpu, hw, 0x0, :hl)
  def cb_instruction(0x4e, cpu, hw), do: Exec.bit(cpu, hw, 0x1, :hl)
  def cb_instruction(0x56, cpu, hw), do: Exec.bit(cpu, hw, 0x2, :hl)
  def cb_instruction(0x5e, cpu, hw), do: Exec.bit(cpu, hw, 0x3, :hl)
  def cb_instruction(0x66, cpu, hw), do: Exec.bit(cpu, hw, 0x4, :hl)
  def cb_instruction(0x6e, cpu, hw), do: Exec.bit(cpu, hw, 0x5, :hl)
  def cb_instruction(0x76, cpu, hw), do: Exec.bit(cpu, hw, 0x6, :hl)
  def cb_instruction(0x7e, cpu, hw), do: Exec.bit(cpu, hw, 0x7, :hl)
  def cb_instruction(0xc7, cpu, hw), do: Exec.set(cpu, hw, 0x0, :a)
  def cb_instruction(0xcf, cpu, hw), do: Exec.set(cpu, hw, 0x1, :a)
  def cb_instruction(0xd7, cpu, hw), do: Exec.set(cpu, hw, 0x2, :a)
  def cb_instruction(0xdf, cpu, hw), do: Exec.set(cpu, hw, 0x3, :a)
  def cb_instruction(0xe7, cpu, hw), do: Exec.set(cpu, hw, 0x4, :a)
  def cb_instruction(0xef, cpu, hw), do: Exec.set(cpu, hw, 0x5, :a)
  def cb_instruction(0xf7, cpu, hw), do: Exec.set(cpu, hw, 0x6, :a)
  def cb_instruction(0xff, cpu, hw), do: Exec.set(cpu, hw, 0x7, :a)
  def cb_instruction(0xc0, cpu, hw), do: Exec.set(cpu, hw, 0x0, :b)
  def cb_instruction(0xc8, cpu, hw), do: Exec.set(cpu, hw, 0x1, :b)
  def cb_instruction(0xd0, cpu, hw), do: Exec.set(cpu, hw, 0x2, :b)
  def cb_instruction(0xd8, cpu, hw), do: Exec.set(cpu, hw, 0x3, :b)
  def cb_instruction(0xe0, cpu, hw), do: Exec.set(cpu, hw, 0x4, :b)
  def cb_instruction(0xe8, cpu, hw), do: Exec.set(cpu, hw, 0x5, :b)
  def cb_instruction(0xf0, cpu, hw), do: Exec.set(cpu, hw, 0x6, :b)
  def cb_instruction(0xf8, cpu, hw), do: Exec.set(cpu, hw, 0x7, :b)
  def cb_instruction(0xc1, cpu, hw), do: Exec.set(cpu, hw, 0x0, :c)
  def cb_instruction(0xc9, cpu, hw), do: Exec.set(cpu, hw, 0x1, :c)
  def cb_instruction(0xd1, cpu, hw), do: Exec.set(cpu, hw, 0x2, :c)
  def cb_instruction(0xd9, cpu, hw), do: Exec.set(cpu, hw, 0x3, :c)
  def cb_instruction(0xe1, cpu, hw), do: Exec.set(cpu, hw, 0x4, :c)
  def cb_instruction(0xe9, cpu, hw), do: Exec.set(cpu, hw, 0x5, :c)
  def cb_instruction(0xf1, cpu, hw), do: Exec.set(cpu, hw, 0x6, :c)
  def cb_instruction(0xf9, cpu, hw), do: Exec.set(cpu, hw, 0x7, :c)
  def cb_instruction(0xc2, cpu, hw), do: Exec.set(cpu, hw, 0x0, :d)
  def cb_instruction(0xca, cpu, hw), do: Exec.set(cpu, hw, 0x1, :d)
  def cb_instruction(0xd2, cpu, hw), do: Exec.set(cpu, hw, 0x2, :d)
  def cb_instruction(0xda, cpu, hw), do: Exec.set(cpu, hw, 0x3, :d)
  def cb_instruction(0xe2, cpu, hw), do: Exec.set(cpu, hw, 0x4, :d)
  def cb_instruction(0xea, cpu, hw), do: Exec.set(cpu, hw, 0x5, :d)
  def cb_instruction(0xf2, cpu, hw), do: Exec.set(cpu, hw, 0x6, :d)
  def cb_instruction(0xfa, cpu, hw), do: Exec.set(cpu, hw, 0x7, :d)
  def cb_instruction(0xc3, cpu, hw), do: Exec.set(cpu, hw, 0x0, :e)
  def cb_instruction(0xcb, cpu, hw), do: Exec.set(cpu, hw, 0x1, :e)
  def cb_instruction(0xd3, cpu, hw), do: Exec.set(cpu, hw, 0x2, :e)
  def cb_instruction(0xdb, cpu, hw), do: Exec.set(cpu, hw, 0x3, :e)
  def cb_instruction(0xe3, cpu, hw), do: Exec.set(cpu, hw, 0x4, :e)
  def cb_instruction(0xeb, cpu, hw), do: Exec.set(cpu, hw, 0x5, :e)
  def cb_instruction(0xf3, cpu, hw), do: Exec.set(cpu, hw, 0x6, :e)
  def cb_instruction(0xfb, cpu, hw), do: Exec.set(cpu, hw, 0x7, :e)
  def cb_instruction(0xc4, cpu, hw), do: Exec.set(cpu, hw, 0x0, :h)
  def cb_instruction(0xcc, cpu, hw), do: Exec.set(cpu, hw, 0x1, :h)
  def cb_instruction(0xd4, cpu, hw), do: Exec.set(cpu, hw, 0x2, :h)
  def cb_instruction(0xdc, cpu, hw), do: Exec.set(cpu, hw, 0x3, :h)
  def cb_instruction(0xe4, cpu, hw), do: Exec.set(cpu, hw, 0x4, :h)
  def cb_instruction(0xec, cpu, hw), do: Exec.set(cpu, hw, 0x5, :h)
  def cb_instruction(0xf4, cpu, hw), do: Exec.set(cpu, hw, 0x6, :h)
  def cb_instruction(0xfc, cpu, hw), do: Exec.set(cpu, hw, 0x7, :h)
  def cb_instruction(0xc5, cpu, hw), do: Exec.set(cpu, hw, 0x0, :l)
  def cb_instruction(0xcd, cpu, hw), do: Exec.set(cpu, hw, 0x1, :l)
  def cb_instruction(0xd5, cpu, hw), do: Exec.set(cpu, hw, 0x2, :l)
  def cb_instruction(0xdd, cpu, hw), do: Exec.set(cpu, hw, 0x3, :l)
  def cb_instruction(0xe5, cpu, hw), do: Exec.set(cpu, hw, 0x4, :l)
  def cb_instruction(0xed, cpu, hw), do: Exec.set(cpu, hw, 0x5, :l)
  def cb_instruction(0xf5, cpu, hw), do: Exec.set(cpu, hw, 0x6, :l)
  def cb_instruction(0xfd, cpu, hw), do: Exec.set(cpu, hw, 0x7, :l)
  def cb_instruction(0xc6, cpu, hw), do: Exec.set(cpu, hw, 0x0, :hl)
  def cb_instruction(0xce, cpu, hw), do: Exec.set(cpu, hw, 0x1, :hl)
  def cb_instruction(0xd6, cpu, hw), do: Exec.set(cpu, hw, 0x2, :hl)
  def cb_instruction(0xde, cpu, hw), do: Exec.set(cpu, hw, 0x3, :hl)
  def cb_instruction(0xe6, cpu, hw), do: Exec.set(cpu, hw, 0x4, :hl)
  def cb_instruction(0xee, cpu, hw), do: Exec.set(cpu, hw, 0x5, :hl)
  def cb_instruction(0xf6, cpu, hw), do: Exec.set(cpu, hw, 0x6, :hl)
  def cb_instruction(0xfe, cpu, hw), do: Exec.set(cpu, hw, 0x7, :hl)
  def cb_instruction(0x87, cpu, hw), do: Exec.res(cpu, hw, 0x0, :a)
  def cb_instruction(0x8f, cpu, hw), do: Exec.res(cpu, hw, 0x1, :a)
  def cb_instruction(0x97, cpu, hw), do: Exec.res(cpu, hw, 0x2, :a)
  def cb_instruction(0x9f, cpu, hw), do: Exec.res(cpu, hw, 0x3, :a)
  def cb_instruction(0xa7, cpu, hw), do: Exec.res(cpu, hw, 0x4, :a)
  def cb_instruction(0xaf, cpu, hw), do: Exec.res(cpu, hw, 0x5, :a)
  def cb_instruction(0xb7, cpu, hw), do: Exec.res(cpu, hw, 0x6, :a)
  def cb_instruction(0xbf, cpu, hw), do: Exec.res(cpu, hw, 0x7, :a)
  def cb_instruction(0x80, cpu, hw), do: Exec.res(cpu, hw, 0x0, :b)
  def cb_instruction(0x88, cpu, hw), do: Exec.res(cpu, hw, 0x1, :b)
  def cb_instruction(0x90, cpu, hw), do: Exec.res(cpu, hw, 0x2, :b)
  def cb_instruction(0x98, cpu, hw), do: Exec.res(cpu, hw, 0x3, :b)
  def cb_instruction(0xa0, cpu, hw), do: Exec.res(cpu, hw, 0x4, :b)
  def cb_instruction(0xa8, cpu, hw), do: Exec.res(cpu, hw, 0x5, :b)
  def cb_instruction(0xb0, cpu, hw), do: Exec.res(cpu, hw, 0x6, :b)
  def cb_instruction(0xb8, cpu, hw), do: Exec.res(cpu, hw, 0x7, :b)
  def cb_instruction(0x81, cpu, hw), do: Exec.res(cpu, hw, 0x0, :c)
  def cb_instruction(0x89, cpu, hw), do: Exec.res(cpu, hw, 0x1, :c)
  def cb_instruction(0x91, cpu, hw), do: Exec.res(cpu, hw, 0x2, :c)
  def cb_instruction(0x99, cpu, hw), do: Exec.res(cpu, hw, 0x3, :c)
  def cb_instruction(0xa1, cpu, hw), do: Exec.res(cpu, hw, 0x4, :c)
  def cb_instruction(0xa9, cpu, hw), do: Exec.res(cpu, hw, 0x5, :c)
  def cb_instruction(0xb1, cpu, hw), do: Exec.res(cpu, hw, 0x6, :c)
  def cb_instruction(0xb9, cpu, hw), do: Exec.res(cpu, hw, 0x7, :c)
  def cb_instruction(0x82, cpu, hw), do: Exec.res(cpu, hw, 0x0, :d)
  def cb_instruction(0x8a, cpu, hw), do: Exec.res(cpu, hw, 0x1, :d)
  def cb_instruction(0x92, cpu, hw), do: Exec.res(cpu, hw, 0x2, :d)
  def cb_instruction(0x9a, cpu, hw), do: Exec.res(cpu, hw, 0x3, :d)
  def cb_instruction(0xa2, cpu, hw), do: Exec.res(cpu, hw, 0x4, :d)
  def cb_instruction(0xaa, cpu, hw), do: Exec.res(cpu, hw, 0x5, :d)
  def cb_instruction(0xb2, cpu, hw), do: Exec.res(cpu, hw, 0x6, :d)
  def cb_instruction(0xba, cpu, hw), do: Exec.res(cpu, hw, 0x7, :d)
  def cb_instruction(0x83, cpu, hw), do: Exec.res(cpu, hw, 0x0, :e)
  def cb_instruction(0x8b, cpu, hw), do: Exec.res(cpu, hw, 0x1, :e)
  def cb_instruction(0x93, cpu, hw), do: Exec.res(cpu, hw, 0x2, :e)
  def cb_instruction(0x9b, cpu, hw), do: Exec.res(cpu, hw, 0x3, :e)
  def cb_instruction(0xa3, cpu, hw), do: Exec.res(cpu, hw, 0x4, :e)
  def cb_instruction(0xab, cpu, hw), do: Exec.res(cpu, hw, 0x5, :e)
  def cb_instruction(0xb3, cpu, hw), do: Exec.res(cpu, hw, 0x6, :e)
  def cb_instruction(0xbb, cpu, hw), do: Exec.res(cpu, hw, 0x7, :e)
  def cb_instruction(0x84, cpu, hw), do: Exec.res(cpu, hw, 0x0, :h)
  def cb_instruction(0x8c, cpu, hw), do: Exec.res(cpu, hw, 0x1, :h)
  def cb_instruction(0x94, cpu, hw), do: Exec.res(cpu, hw, 0x2, :h)
  def cb_instruction(0x9c, cpu, hw), do: Exec.res(cpu, hw, 0x3, :h)
  def cb_instruction(0xa4, cpu, hw), do: Exec.res(cpu, hw, 0x4, :h)
  def cb_instruction(0xac, cpu, hw), do: Exec.res(cpu, hw, 0x5, :h)
  def cb_instruction(0xb4, cpu, hw), do: Exec.res(cpu, hw, 0x6, :h)
  def cb_instruction(0xbc, cpu, hw), do: Exec.res(cpu, hw, 0x7, :h)
  def cb_instruction(0x85, cpu, hw), do: Exec.res(cpu, hw, 0x0, :l)
  def cb_instruction(0x8d, cpu, hw), do: Exec.res(cpu, hw, 0x1, :l)
  def cb_instruction(0x95, cpu, hw), do: Exec.res(cpu, hw, 0x2, :l)
  def cb_instruction(0x9d, cpu, hw), do: Exec.res(cpu, hw, 0x3, :l)
  def cb_instruction(0xa5, cpu, hw), do: Exec.res(cpu, hw, 0x4, :l)
  def cb_instruction(0xad, cpu, hw), do: Exec.res(cpu, hw, 0x5, :l)
  def cb_instruction(0xb5, cpu, hw), do: Exec.res(cpu, hw, 0x6, :l)
  def cb_instruction(0xbd, cpu, hw), do: Exec.res(cpu, hw, 0x7, :l)
  def cb_instruction(0x86, cpu, hw), do: Exec.res(cpu, hw, 0x0, :hl)
  def cb_instruction(0x8e, cpu, hw), do: Exec.res(cpu, hw, 0x1, :hl)
  def cb_instruction(0x96, cpu, hw), do: Exec.res(cpu, hw, 0x2, :hl)
  def cb_instruction(0x9e, cpu, hw), do: Exec.res(cpu, hw, 0x3, :hl)
  def cb_instruction(0xa6, cpu, hw), do: Exec.res(cpu, hw, 0x4, :hl)
  def cb_instruction(0xae, cpu, hw), do: Exec.res(cpu, hw, 0x5, :hl)
  def cb_instruction(0xb6, cpu, hw), do: Exec.res(cpu, hw, 0x6, :hl)
  def cb_instruction(0xbe, cpu, hw), do: Exec.res(cpu, hw, 0x7, :hl)
end
