defmodule Gameboy do
  alias Gameboy.Hardware
  alias Gameboy.CPU
  import Gameboy.CPU, only: [fetch_next: 3, handle_interrupt: 2]
  import Gameboy.CPU.Decode, only: [decode_exec: 2]

  defstruct cpu: struct(CPU), hw: struct(Hardware), ppu: 0

  def init do
    cpu = CPU.init()
    hw = Hardware.init()
    %Gameboy{cpu: cpu, hw: hw}
  end

  def step(%{cpu: cpu, hw: hw} = gb) do
    # Handle interrupts
    {cpu, hw} = handle_interrupt(cpu, hw)
    {cpu, hw} = case cpu.state do
      :running ->
        {cpu, hw} = fetch_next(cpu, hw, cpu.regs.pc)
        {cpu, hw} = decode_exec(cpu, hw)
      :haltbug ->
        # Halt bug. Fetch but don't increment pc
        pc = cpu.regs.pc
        {cpu, hw} = fetch_next(cpu, hw, pc)
        cpu = put_in(cpu.regs.pc, pc)
        {cpu, hw} = decode_exec(put_in(cpu.state, :running), hw)
      _ ->
        {cpu, hw}
    end
    %{gb | cpu: cpu, hw: hw}
  end
end
