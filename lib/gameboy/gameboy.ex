defmodule Gameboy do
  alias Gameboy.Hardware
  alias Gameboy.Cpu
  import Gameboy.Cpu, only: [fetch_next: 3, handle_interrupt: 2]
  import Gameboy.Cpu.Decode, only: [decode_exec: 2]

  defstruct cpu: struct(Cpu), hw: struct(Hardware)

  def init do
    cpu = Cpu.init()
    hw = Hardware.init()
    %Gameboy{cpu: cpu, hw: hw}
  end

  def step(%{cpu: cpu, hw: hw} = gb) do
    # Handle interrupts
    {cpu, hw} = handle_interrupt(cpu, hw)
    {cpu, hw} = case cpu.state do
      :running ->
        {cpu, hw} = fetch_next(cpu, hw, cpu.pc)
        {cpu, hw} = decode_exec(cpu, hw)
      :haltbug ->
        # Halt bug. Fetch but don't increment pc
        pc = cpu.pc
        {cpu, hw} = fetch_next(cpu, hw, pc)
        cpu = Map.put(cpu, :pc, pc)
        {cpu, hw} = decode_exec(Map.put(cpu, :state, :running), hw)
      _ ->
        {cpu, hw}
    end
    %{gb | cpu: cpu, hw: hw}
  end
end
