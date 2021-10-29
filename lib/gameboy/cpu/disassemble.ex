defmodule Gameboy.Cpu.Disassemble do
  alias Gameboy.Cpu
  alias Gameboy.Utils

  def disassemble(0x7f, cpu, hw), do: ld(cpu, hw, :a, :a)
  def disassemble(0x78, cpu, hw), do: ld(cpu, hw, :a, :b)
  def disassemble(0x79, cpu, hw), do: ld(cpu, hw, :a, :c)
  def disassemble(0x7a, cpu, hw), do: ld(cpu, hw, :a, :d)
  def disassemble(0x7b, cpu, hw), do: ld(cpu, hw, :a, :e)
  def disassemble(0x7c, cpu, hw), do: ld(cpu, hw, :a, :h)
  def disassemble(0x7d, cpu, hw), do: ld(cpu, hw, :a, :l)
  def disassemble(0x7e, cpu, hw), do: ld(cpu, hw, :a, :hl)
  def disassemble(0x47, cpu, hw), do: ld(cpu, hw, :b, :a)

  def disassemble(0x40, cpu, hw), do: ld(cpu, hw, :b, :b)
  # def disassemble(0x40, cpu, hw), do: debug(cpu, hw)

  def disassemble(0x41, cpu, hw), do: ld(cpu, hw, :b, :c)
  def disassemble(0x42, cpu, hw), do: ld(cpu, hw, :b, :d)
  def disassemble(0x43, cpu, hw), do: ld(cpu, hw, :b, :e)
  def disassemble(0x44, cpu, hw), do: ld(cpu, hw, :b, :h)
  def disassemble(0x45, cpu, hw), do: ld(cpu, hw, :b, :l)
  def disassemble(0x46, cpu, hw), do: ld(cpu, hw, :b, :hl)
  def disassemble(0x4f, cpu, hw), do: ld(cpu, hw, :c, :a)
  def disassemble(0x48, cpu, hw), do: ld(cpu, hw, :c, :b)
  def disassemble(0x49, cpu, hw), do: ld(cpu, hw, :c, :c)
  def disassemble(0x4a, cpu, hw), do: ld(cpu, hw, :c, :d)
  def disassemble(0x4b, cpu, hw), do: ld(cpu, hw, :c, :e)
  def disassemble(0x4c, cpu, hw), do: ld(cpu, hw, :c, :h)
  def disassemble(0x4d, cpu, hw), do: ld(cpu, hw, :c, :l)
  def disassemble(0x4e, cpu, hw), do: ld(cpu, hw, :c, :hl)
  def disassemble(0x57, cpu, hw), do: ld(cpu, hw, :d, :a)
  def disassemble(0x50, cpu, hw), do: ld(cpu, hw, :d, :b)
  def disassemble(0x51, cpu, hw), do: ld(cpu, hw, :d, :c)
  def disassemble(0x52, cpu, hw), do: ld(cpu, hw, :d, :d)
  def disassemble(0x53, cpu, hw), do: ld(cpu, hw, :d, :e)
  def disassemble(0x54, cpu, hw), do: ld(cpu, hw, :d, :h)
  def disassemble(0x55, cpu, hw), do: ld(cpu, hw, :d, :l)
  def disassemble(0x56, cpu, hw), do: ld(cpu, hw, :d, :hl)
  def disassemble(0x5f, cpu, hw), do: ld(cpu, hw, :e, :a)
  def disassemble(0x58, cpu, hw), do: ld(cpu, hw, :e, :b)
  def disassemble(0x59, cpu, hw), do: ld(cpu, hw, :e, :c)
  def disassemble(0x5a, cpu, hw), do: ld(cpu, hw, :e, :d)
  def disassemble(0x5b, cpu, hw), do: ld(cpu, hw, :e, :e)
  def disassemble(0x5c, cpu, hw), do: ld(cpu, hw, :e, :h)
  def disassemble(0x5d, cpu, hw), do: ld(cpu, hw, :e, :l)
  def disassemble(0x5e, cpu, hw), do: ld(cpu, hw, :e, :hl)
  def disassemble(0x67, cpu, hw), do: ld(cpu, hw, :h, :a)
  def disassemble(0x60, cpu, hw), do: ld(cpu, hw, :h, :b)
  def disassemble(0x61, cpu, hw), do: ld(cpu, hw, :h, :c)
  def disassemble(0x62, cpu, hw), do: ld(cpu, hw, :h, :d)
  def disassemble(0x63, cpu, hw), do: ld(cpu, hw, :h, :e)
  def disassemble(0x64, cpu, hw), do: ld(cpu, hw, :h, :h)
  def disassemble(0x65, cpu, hw), do: ld(cpu, hw, :h, :l)
  def disassemble(0x66, cpu, hw), do: ld(cpu, hw, :h, :hl)
  def disassemble(0x6f, cpu, hw), do: ld(cpu, hw, :l, :a)
  def disassemble(0x68, cpu, hw), do: ld(cpu, hw, :l, :b)
  def disassemble(0x69, cpu, hw), do: ld(cpu, hw, :l, :c)
  def disassemble(0x6a, cpu, hw), do: ld(cpu, hw, :l, :d)
  def disassemble(0x6b, cpu, hw), do: ld(cpu, hw, :l, :e)
  def disassemble(0x6c, cpu, hw), do: ld(cpu, hw, :l, :h)
  def disassemble(0x6d, cpu, hw), do: ld(cpu, hw, :l, :l)
  def disassemble(0x6e, cpu, hw), do: ld(cpu, hw, :l, :hl)
  def disassemble(0x3e, cpu, hw), do: ld(cpu, hw, :a, :imm)
  def disassemble(0x06, cpu, hw), do: ld(cpu, hw, :b, :imm)
  def disassemble(0x0e, cpu, hw), do: ld(cpu, hw, :c, :imm)
  def disassemble(0x16, cpu, hw), do: ld(cpu, hw, :d, :imm)
  def disassemble(0x1e, cpu, hw), do: ld(cpu, hw, :e, :imm)
  def disassemble(0x26, cpu, hw), do: ld(cpu, hw, :h, :imm)
  def disassemble(0x2e, cpu, hw), do: ld(cpu, hw, :l, :imm)
  def disassemble(0x36, cpu, hw), do: ld(cpu, hw, :hl, :imm)
  def disassemble(0x77, cpu, hw), do: ld(cpu, hw, :hl, :a)
  def disassemble(0x70, cpu, hw), do: ld(cpu, hw, :hl, :b)
  def disassemble(0x71, cpu, hw), do: ld(cpu, hw, :hl, :c)
  def disassemble(0x72, cpu, hw), do: ld(cpu, hw, :hl, :d)
  def disassemble(0x73, cpu, hw), do: ld(cpu, hw, :hl, :e)
  def disassemble(0x74, cpu, hw), do: ld(cpu, hw, :hl, :h)
  def disassemble(0x75, cpu, hw), do: ld(cpu, hw, :hl, :l)
  def disassemble(0x0a, cpu, hw), do: ld(cpu, hw, :a, :bc)
  def disassemble(0x1a, cpu, hw), do: ld(cpu, hw, :a, :de)
  def disassemble(0xfa, cpu, hw), do: ld(cpu, hw, :a, :immaddr)
  def disassemble(0x3a, cpu, hw), do: ld(cpu, hw, :a, :hld)
  def disassemble(0x2a, cpu, hw), do: ld(cpu, hw, :a, :hli)
  def disassemble(0xf0, cpu, hw), do: ld(cpu, hw, :a, :hi)
  def disassemble(0xf2, cpu, hw), do: ld(cpu, hw, :a, :hic)
  def disassemble(0x02, cpu, hw), do: ld(cpu, hw, :bc, :a)
  def disassemble(0x12, cpu, hw), do: ld(cpu, hw, :de, :a)
  def disassemble(0xea, cpu, hw), do: ld(cpu, hw, :immaddr, :a)
  def disassemble(0x32, cpu, hw), do: ld(cpu, hw, :hld, :a)
  def disassemble(0x22, cpu, hw), do: ld(cpu, hw, :hli, :a)
  def disassemble(0xe0, cpu, hw), do: ld(cpu, hw, :hi, :a)
  def disassemble(0xe2, cpu, hw), do: ld(cpu, hw, :hic, :a)

  # 8-bit arithmetic
  def disassemble(0x87, cpu, hw), do: add(cpu, hw, :a, :a)
  def disassemble(0x80, cpu, hw), do: add(cpu, hw, :a, :b)
  def disassemble(0x81, cpu, hw), do: add(cpu, hw, :a, :c)
  def disassemble(0x82, cpu, hw), do: add(cpu, hw, :a, :d)
  def disassemble(0x83, cpu, hw), do: add(cpu, hw, :a, :e)
  def disassemble(0x84, cpu, hw), do: add(cpu, hw, :a, :h)
  def disassemble(0x85, cpu, hw), do: add(cpu, hw, :a, :l)
  def disassemble(0x86, cpu, hw), do: add(cpu, hw, :a, :hl)
  def disassemble(0xc6, cpu, hw), do: add(cpu, hw, :a, :imm)
  def disassemble(0x8f, cpu, hw), do: adc(cpu, hw, :a, :a)
  def disassemble(0x88, cpu, hw), do: adc(cpu, hw, :a, :b)
  def disassemble(0x89, cpu, hw), do: adc(cpu, hw, :a, :c)
  def disassemble(0x8a, cpu, hw), do: adc(cpu, hw, :a, :d)
  def disassemble(0x8b, cpu, hw), do: adc(cpu, hw, :a, :e)
  def disassemble(0x8c, cpu, hw), do: adc(cpu, hw, :a, :h)
  def disassemble(0x8d, cpu, hw), do: adc(cpu, hw, :a, :l)
  def disassemble(0x8e, cpu, hw), do: adc(cpu, hw, :a, :hl)
  def disassemble(0xce, cpu, hw), do: adc(cpu, hw, :a, :imm)
  def disassemble(0x97, cpu, hw), do: sub(cpu, hw, :a, :a)
  def disassemble(0x90, cpu, hw), do: sub(cpu, hw, :a, :b)
  def disassemble(0x91, cpu, hw), do: sub(cpu, hw, :a, :c)
  def disassemble(0x92, cpu, hw), do: sub(cpu, hw, :a, :d)
  def disassemble(0x93, cpu, hw), do: sub(cpu, hw, :a, :e)
  def disassemble(0x94, cpu, hw), do: sub(cpu, hw, :a, :h)
  def disassemble(0x95, cpu, hw), do: sub(cpu, hw, :a, :l)
  def disassemble(0x96, cpu, hw), do: sub(cpu, hw, :a, :hl)
  def disassemble(0xd6, cpu, hw), do: sub(cpu, hw, :a, :imm)
  def disassemble(0x9f, cpu, hw), do: sbc(cpu, hw, :a, :a)
  def disassemble(0x98, cpu, hw), do: sbc(cpu, hw, :a, :b)
  def disassemble(0x99, cpu, hw), do: sbc(cpu, hw, :a, :c)
  def disassemble(0x9a, cpu, hw), do: sbc(cpu, hw, :a, :d)
  def disassemble(0x9b, cpu, hw), do: sbc(cpu, hw, :a, :e)
  def disassemble(0x9c, cpu, hw), do: sbc(cpu, hw, :a, :h)
  def disassemble(0x9d, cpu, hw), do: sbc(cpu, hw, :a, :l)
  def disassemble(0x9e, cpu, hw), do: sbc(cpu, hw, :a, :hl)
  def disassemble(0xde, cpu, hw), do: sbc(cpu, hw, :a, :imm)
  def disassemble(0xa7, cpu, hw), do: and_op(cpu, hw, :a, :a)
  def disassemble(0xa0, cpu, hw), do: and_op(cpu, hw, :a, :b)
  def disassemble(0xa1, cpu, hw), do: and_op(cpu, hw, :a, :c)
  def disassemble(0xa2, cpu, hw), do: and_op(cpu, hw, :a, :d)
  def disassemble(0xa3, cpu, hw), do: and_op(cpu, hw, :a, :e)
  def disassemble(0xa4, cpu, hw), do: and_op(cpu, hw, :a, :h)
  def disassemble(0xa5, cpu, hw), do: and_op(cpu, hw, :a, :l)
  def disassemble(0xa6, cpu, hw), do: and_op(cpu, hw, :a, :hl)
  def disassemble(0xe6, cpu, hw), do: and_op(cpu, hw, :a, :imm)
  def disassemble(0xb7, cpu, hw), do: or_op(cpu, hw, :a, :a)
  def disassemble(0xb0, cpu, hw), do: or_op(cpu, hw, :a, :b)
  def disassemble(0xb1, cpu, hw), do: or_op(cpu, hw, :a, :c)
  def disassemble(0xb2, cpu, hw), do: or_op(cpu, hw, :a, :d)
  def disassemble(0xb3, cpu, hw), do: or_op(cpu, hw, :a, :e)
  def disassemble(0xb4, cpu, hw), do: or_op(cpu, hw, :a, :h)
  def disassemble(0xb5, cpu, hw), do: or_op(cpu, hw, :a, :l)
  def disassemble(0xb6, cpu, hw), do: or_op(cpu, hw, :a, :hl)
  def disassemble(0xf6, cpu, hw), do: or_op(cpu, hw, :a, :imm)
  def disassemble(0xaf, cpu, hw), do: xor(cpu, hw, :a, :a)
  def disassemble(0xa8, cpu, hw), do: xor(cpu, hw, :a, :b)
  def disassemble(0xa9, cpu, hw), do: xor(cpu, hw, :a, :c)
  def disassemble(0xaa, cpu, hw), do: xor(cpu, hw, :a, :d)
  def disassemble(0xab, cpu, hw), do: xor(cpu, hw, :a, :e)
  def disassemble(0xac, cpu, hw), do: xor(cpu, hw, :a, :h)
  def disassemble(0xad, cpu, hw), do: xor(cpu, hw, :a, :l)
  def disassemble(0xae, cpu, hw), do: xor(cpu, hw, :a, :hl)
  def disassemble(0xee, cpu, hw), do: xor(cpu, hw, :a, :imm)
  def disassemble(0xbf, cpu, hw), do: cp(cpu, hw, :a, :a)
  def disassemble(0xb8, cpu, hw), do: cp(cpu, hw, :a, :b)
  def disassemble(0xb9, cpu, hw), do: cp(cpu, hw, :a, :c)
  def disassemble(0xba, cpu, hw), do: cp(cpu, hw, :a, :d)
  def disassemble(0xbb, cpu, hw), do: cp(cpu, hw, :a, :e)
  def disassemble(0xbc, cpu, hw), do: cp(cpu, hw, :a, :h)
  def disassemble(0xbd, cpu, hw), do: cp(cpu, hw, :a, :l)
  def disassemble(0xbe, cpu, hw), do: cp(cpu, hw, :a, :hl)
  def disassemble(0xfe, cpu, hw), do: cp(cpu, hw, :a, :imm)
  def disassemble(0x3c, cpu, hw), do: inc(cpu, hw, :a)
  def disassemble(0x04, cpu, hw), do: inc(cpu, hw, :b)
  def disassemble(0x0c, cpu, hw), do: inc(cpu, hw, :c)
  def disassemble(0x14, cpu, hw), do: inc(cpu, hw, :d)
  def disassemble(0x1c, cpu, hw), do: inc(cpu, hw, :e)
  def disassemble(0x24, cpu, hw), do: inc(cpu, hw, :h)
  def disassemble(0x2c, cpu, hw), do: inc(cpu, hw, :l)
  def disassemble(0x34, cpu, hw), do: inc(cpu, hw, :hl)
  def disassemble(0x3d, cpu, hw), do: dec(cpu, hw, :a)
  def disassemble(0x05, cpu, hw), do: dec(cpu, hw, :b)
  def disassemble(0x0d, cpu, hw), do: dec(cpu, hw, :c)
  def disassemble(0x15, cpu, hw), do: dec(cpu, hw, :d)
  def disassemble(0x1d, cpu, hw), do: dec(cpu, hw, :e)
  def disassemble(0x25, cpu, hw), do: dec(cpu, hw, :h)
  def disassemble(0x2d, cpu, hw), do: dec(cpu, hw, :l)
  def disassemble(0x35, cpu, hw), do: dec(cpu, hw, :hl)
  def disassemble(0x07, cpu, hw), do: rlc(cpu, hw, :a)
  def disassemble(0x17, cpu, hw), do: rl(cpu, hw, :a)
  def disassemble(0x0f, cpu, hw), do: rrc(cpu, hw, :a)
  def disassemble(0x1f, cpu, hw), do: rr(cpu, hw, :a)

  # Control instrunctions
  def disassemble(0xc3, cpu, hw), do: jp_nn(cpu, hw)
  def disassemble(0xe9, cpu, hw), do: jp_hl(cpu, hw)
  def disassemble(0x18, cpu, hw), do: jr_n(cpu, hw)
  def disassemble(0xcd, cpu, hw), do: call_nn(cpu, hw)
  def disassemble(0xc9, cpu, hw), do: ret(cpu, hw)
  def disassemble(0xd9, cpu, hw), do: reti(cpu, hw)
  def disassemble(0xc2, cpu, hw), do: jp_cc_nn(cpu, hw, :nz)
  def disassemble(0xca, cpu, hw), do: jp_cc_nn(cpu, hw, :z)
  def disassemble(0xd2, cpu, hw), do: jp_cc_nn(cpu, hw, :nc)
  def disassemble(0xda, cpu, hw), do: jp_cc_nn(cpu, hw, :c)
  def disassemble(0x20, cpu, hw), do: jr_cc_n(cpu, hw, :nz)
  def disassemble(0x28, cpu, hw), do: jr_cc_n(cpu, hw, :z)
  def disassemble(0x30, cpu, hw), do: jr_cc_n(cpu, hw, :nc)
  def disassemble(0x38, cpu, hw), do: jr_cc_n(cpu, hw, :c)
  def disassemble(0xc4, cpu, hw), do: call_cc_nn(cpu, hw, :nz)
  def disassemble(0xcc, cpu, hw), do: call_cc_nn(cpu, hw, :z)
  def disassemble(0xd4, cpu, hw), do: call_cc_nn(cpu, hw, :nc)
  def disassemble(0xdc, cpu, hw), do: call_cc_nn(cpu, hw, :c)
  def disassemble(0xc0, cpu, hw), do: ret_cc(cpu, hw, :nz)
  def disassemble(0xc8, cpu, hw), do: ret_cc(cpu, hw, :z)
  def disassemble(0xd0, cpu, hw), do: ret_cc(cpu, hw, :nc)
  def disassemble(0xd8, cpu, hw), do: ret_cc(cpu, hw, :c)
  def disassemble(0xc7, cpu, hw), do: rst(cpu, hw, 0x00)
  def disassemble(0xcf, cpu, hw), do: rst(cpu, hw, 0x08)
  def disassemble(0xd7, cpu, hw), do: rst(cpu, hw, 0x10)
  def disassemble(0xdf, cpu, hw), do: rst(cpu, hw, 0x18)
  def disassemble(0xe7, cpu, hw), do: rst(cpu, hw, 0x20)
  def disassemble(0xef, cpu, hw), do: rst(cpu, hw, 0x28)
  def disassemble(0xf7, cpu, hw), do: rst(cpu, hw, 0x30)
  def disassemble(0xff, cpu, hw), do: rst(cpu, hw, 0x38)

  # Miscellaneous
  def disassemble(0x76, cpu, hw), do: halt(cpu, hw)
  def disassemble(0x10, cpu, hw), do: stop(cpu, hw)
  def disassemble(0xf3, cpu, hw), do: di(cpu, hw)
  def disassemble(0xfb, cpu, hw), do: ei(cpu, hw)
  def disassemble(0x3f, cpu, hw), do: ccf(cpu, hw)
  def disassemble(0x37, cpu, hw), do: scf(cpu, hw)
  def disassemble(0x00, cpu, hw), do: nop(cpu, hw)
  def disassemble(0x27, cpu, hw), do: daa(cpu, hw)
  def disassemble(0x2f, cpu, hw), do: cpl(cpu, hw)

  # 16-bit loads/pop/push
  def disassemble(0x01, cpu, hw), do: ld16_rr_nn(cpu, hw, :bc)
  def disassemble(0x11, cpu, hw), do: ld16_rr_nn(cpu, hw, :de)
  def disassemble(0x21, cpu, hw), do: ld16_rr_nn(cpu, hw, :hl)
  def disassemble(0x31, cpu, hw), do: ld16_rr_nn(cpu, hw, :sp)
  def disassemble(0xf9, cpu, hw), do: ld16_sp_hl(cpu, hw)
  def disassemble(0xf8, cpu, hw), do: ld16_hl_sp_n(cpu, hw)
  def disassemble(0x08, cpu, hw), do: ld16_nn_sp(cpu, hw)
  def disassemble(0xf5, cpu, hw), do: push16_rr(cpu, hw, :af)
  def disassemble(0xc5, cpu, hw), do: push16_rr(cpu, hw, :bc)
  def disassemble(0xd5, cpu, hw), do: push16_rr(cpu, hw, :de)
  def disassemble(0xe5, cpu, hw), do: push16_rr(cpu, hw, :hl)
  def disassemble(0xf1, cpu, hw), do: pop16_rr(cpu, hw, :af)
  def disassemble(0xc1, cpu, hw), do: pop16_rr(cpu, hw, :bc)
  def disassemble(0xd1, cpu, hw), do: pop16_rr(cpu, hw, :de)
  def disassemble(0xe1, cpu, hw), do: pop16_rr(cpu, hw, :hl)

  # 16-bit arithmetic
  def disassemble(0x09, cpu, hw), do: add16_hl_rr(cpu, hw, :bc)
  def disassemble(0x19, cpu, hw), do: add16_hl_rr(cpu, hw, :de)
  def disassemble(0x29, cpu, hw), do: add16_hl_rr(cpu, hw, :hl)
  def disassemble(0x39, cpu, hw), do: add16_hl_rr(cpu, hw, :sp)
  def disassemble(0xe8, cpu, hw), do: add16_sp_n(cpu, hw)
  def disassemble(0x03, cpu, hw), do: inc16_rr(cpu, hw, :bc)
  def disassemble(0x13, cpu, hw), do: inc16_rr(cpu, hw, :de)
  def disassemble(0x23, cpu, hw), do: inc16_rr(cpu, hw, :hl)
  def disassemble(0x33, cpu, hw), do: inc16_rr(cpu, hw, :sp)
  def disassemble(0x0b, cpu, hw), do: dec16_rr(cpu, hw, :bc)
  def disassemble(0x1b, cpu, hw), do: dec16_rr(cpu, hw, :de)
  def disassemble(0x2b, cpu, hw), do: dec16_rr(cpu, hw, :hl)
  def disassemble(0x3b, cpu, hw), do: dec16_rr(cpu, hw, :sp)

  def disassemble(0xcb, cpu, hw), do: cb_prefix(cpu, hw)

  defp ld(_cpu, _hw, dst, src) do
    "ld #{to_str(dst)}, #{to_str(src)}"
  end

  defp add(_cpu, _hw, dst, src) do
    "add #{to_str(dst)}, #{to_str(src)}"
  end

  defp adc(_cpu, _hw, dst, src) do
    "adc #{to_str(dst)}, #{to_str(src)}"
  end

  defp sub(_cpu, _hw, dst, src) do
    "sub #{to_str(dst)}, #{to_str(src)}"
  end

  defp sbc(_cpu, _hw, dst, src) do
    "sbc #{to_str(dst)}, #{to_str(src)}"
  end

  defp and_op(_cpu, _hw, dst, src) do
    "and #{to_str(dst)}, #{to_str(src)}"
  end

  defp or_op(_cpu, _hw, dst, src) do
    "or #{to_str(dst)}, #{to_str(src)}"
  end

  defp xor(_cpu, _hw, dst, src) do
    "xor #{to_str(dst)}, #{to_str(src)}"
  end

  defp cp(_cpu, _hw, dst, src) do
    "cp #{to_str(dst)}, #{to_str(src)}"
  end

  defp inc(_cpu, _hw, dst) do
    "inc #{to_str(dst)}"
  end

  defp dec(_cpu, _hw, dst) do
    "dec #{to_str(dst)}"
  end

  defp rlc(_cpu, _hw, dst) do
    "rlc #{to_str(dst)}"
  end

  defp rl(_cpu, _hw, dst) do
    "rl #{to_str(dst)}"
  end

  defp rrc(_cpu, _hw, dst) do
    "rrc #{to_str(dst)}"
  end

  defp rr(_cpu, _hw, dst) do
    "rr #{to_str(dst)}"
  end

  defp jp_nn(_cpu, _hw) do
    "jp nn"
  end

  defp jp_hl(_cpu, _hw) do
    "jp hl"
  end

  defp jr_n(_cpu, _hw) do
    "jr"
  end

  defp call_nn(_cpu, _hw) do
    "call nn"
  end

  defp ret(_cpu, _hw) do
    "ret"
  end

  defp reti(_cpu, _hw) do
    "reti"
  end

  defp jp_cc_nn(_cpu, _hw, flag) do
    "jp #{to_str(flag)}, nn"
  end

  defp jr_cc_n(_cpu, _hw, flag) do
    "jr #{to_str(flag)}, n"
  end

  defp call_cc_nn(_cpu, _hw, flag) do
    "call #{to_str(flag)}, nn"
  end

  defp ret_cc(_cpu, _hw, flag) do
    "ret #{to_str(flag)}"
  end

  defp rst(_cpu, _hw, addr) do
    "ret 0x#{Utils.to_hex(addr)}"
  end

  defp halt(_cpu, _hw) do
    "halt"
  end

  defp stop(_cpu, _hw) do
    "stop"
  end

  defp di(_cpu, _hw) do
    "di"
  end

  defp ei(_cpu, _hw) do
    "ei"
  end

  defp ccf(_cpu, _hw) do
    "ccf"
  end

  defp scf(_cpu, _hw) do
    "scf"
  end

  defp nop(_cpu, _hw) do
    "nop"
  end

  defp daa(_cpu, _hw) do
    "daa"
  end

  defp cpl(_cpu, _hw) do
    "cpl"
  end

  defp ld16_rr_nn(_cpu, _hw, dst) do
    "ld #{to_str(dst)}, nn"
  end

  defp ld16_sp_hl(_cpu, _hw) do
    "ld sp, hl"
  end

  defp ld16_hl_sp_n(_cpu, _hw) do
    "ldhl sp, n"
  end

  defp ld16_nn_sp(_cpu, _hw) do
    "ld nn, sp"
  end

  defp add16_hl_rr(_cpu, _hw, src) do
    "add hl, #{to_str(src)}"
  end

  defp add16_sp_n(_cpu, _hw) do
    "add sp, n"
  end

  defp inc16_rr(_cpu, _hw, dst) do
    "inc #{to_str(dst)}"
  end

  defp dec16_rr(_cpu, _hw, dst) do
    "dec #{to_str(dst)}"
  end

  defp push16_rr(_cpu, _hw, dst) do
    "push #{to_str(dst)}"
  end

  defp pop16_rr(_cpu, _hw, dst) do
    "pop #{to_str(dst)}"
  end

  defp cb_prefix(_cpu, _hw) do
    "cb_prefix"
  end

  @compile {:inline, :to_str, 1}
  defp to_str(x) do
    Atom.to_string(x)
  end
end
