defmodule Gameboy do
  alias Gameboy.Hardware
  alias Gameboy.Cpu
  alias Gameboy.Ppu
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

  def start() do
    gb = Gameboy.init()
    loop(gb)
  end

  defp loop(gb) do
    gb = Gameboy.step(gb)
    ppu = if gb.hw.ppu.screen.ready do
      send(Info, {:animate_frame, Ppu.screen_buffer(gb.hw.ppu)})
      # send(Info, :animate_frame)
      # ScreenServer.animate(gb.hw.ppu.screen.buffer)
      Ppu.flush_screen_buffer(gb.hw.ppu)
    else
      gb.hw.ppu
    end
    loop(put_in(gb.hw.ppu, ppu))
  end
end
