defmodule Gameboy.Utils do
  def to_hex(num, min_digits \\ 4) do
    num_string = Integer.to_string(num, 16)
    zeros = min_digits - String.length(num_string)
    if zeros > 0, do: "#{String.duplicate("0", zeros)}#{num_string}", else: num_string
  end

  def break_point(%{cpu: cpu} = gb, target_pc \\ 0x000f) do
    cpu.regs.pc >= target_pc
  end
end
