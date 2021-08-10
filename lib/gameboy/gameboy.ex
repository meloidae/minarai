defmodule Gameboy do
  alias Gameboy.Hardware
  alias Gameboy.Cpu
  # alias Gameboy.Ppu
  alias Gameboy.SimplePpu, as: Ppu
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
    case cpu.state do
      :running ->
        # {cpu, hw} = fetch_next(cpu, hw, cpu.pc)
        # {cpu, hw} = decode_exec(cpu, hw)
        {cpu, hw} = fetch_next(cpu, hw, cpu.pc)
        {cpu, hw} = decode_exec(cpu, hw)
        # {cpu, hw} = try do
        #   decode_exec(cpu, hw)
        # rescue
        #   e in RuntimeError ->
        #     IO.puts("#{inspect(e)}")
        #     raise "#{inspect(cpu)}"
        # end
        %{gb | cpu: cpu, hw: hw}
      :haltbug ->
        # Halt bug. Fetch but don't increment pc
        pc = cpu.pc
        {cpu, hw} = fetch_next(cpu, hw, pc)
        cpu = %{cpu | pc: pc, state: :running}
        {cpu, hw} = decode_exec(cpu, hw)
        %{gb | cpu: cpu, hw: hw}
      :halt ->
        Map.put(gb, :hw, Hardware.sync_cycle(hw))
      _ -> # stop?
        gb
    end
  end

  def start() do
    gb = Gameboy.init()
    loop(gb)
  end

  defp loop(gb), do: loop(Gameboy.step(gb))

  @break 0x100
  def debug_start() do
    gb = Gameboy.init()
    debug_loop(gb)
  end

  defp debug_loop(gb) when gb.cpu.pc === @break, do: debug_step(gb)
  defp debug_loop(gb), do: debug_loop(Gameboy.step(gb))

  defp debug_step(gb) do
    # IO.puts("#{inspect(gb.cpu)}")
    # receive do
    #   :step ->
    #     true
    # end

    debug_step(Gameboy.step(gb))
  end
end
