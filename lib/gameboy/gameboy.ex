defmodule Gameboy do
  alias Gameboy.Hardware
  alias Gameboy.Cpu
  # alias Gameboy.Ppu
  alias Gameboy.SimplePpu, as: Ppu
  import Gameboy.Cpu, only: [fetch_next: 3, handle_interrupt: 2]
  import Gameboy.Cpu.Decode, only: [decode_exec: 2]
  import Gameboy.Cpu.Disassemble, only: [disassemble: 3]
  alias Gameboy.Utils

  defstruct cpu: struct(Cpu), hw: struct(Hardware)

  def init(opts \\ nil) do
    cpu = Cpu.init()
    hw = Hardware.init(opts)
    %Gameboy{cpu: cpu, hw: hw}
  end

  def step(%{cpu: cpu, hw: hw} = gb) do
    # Handle interrupts
    {cpu, hw} = handle_interrupt(cpu, hw)
    case cpu.state do
      :running ->
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
        # IO.puts("Halt bug")
        pc = cpu.pc
        {cpu, hw} = fetch_next(cpu, hw, pc)
        cpu = %{cpu | pc: pc, state: :running}
        {cpu, hw} = decode_exec(cpu, hw)
        %{gb | cpu: cpu, hw: hw}
      :halt ->
        # IO.puts("Halt")
        # pc = cpu.pc
        # IO.puts("#{disassemble(gb.cpu.opcode, gb.cpu, gb.hw)}")
        %{gb | cpu: cpu, hw: Hardware.sync_cycle(hw)}
      _ -> # stop?
        # IO.puts("stop")
        gb
    end
  end

  def start(opts \\ []) do
    gb = Gameboy.init(opts)
    loop(gb)
  end

  defp loop(gb), do: loop(Gameboy.step(gb))

  @break 0x1000
  def debug_start(opts \\ []) do
    gb = Gameboy.init(opts)
    debug_loop(gb)
  end

  # defp debug_loop(gb) when gb.cpu.pc === @break, do: debug_step(gb)
  defp debug_loop(gb) when gb.cpu.pc >= @break, do: debug_step(gb)
  defp debug_loop(gb), do: debug_loop(Gameboy.step(gb))

  defp debug_step(gb) do
    # IO.puts("#{disassemble(gb.cpu.opcode, gb.cpu, gb.hw)}")
    # IO.puts("#{inspect(gb.cpu)}")
    # IO.puts("#{inspect(gb.hw.ppu.counter)}")
    # IO.puts("#{Utils.to_hex(gb.hw.ppu.lcdc)}")
    # receive do
    #  :step ->
    #    true
    #end

    debug_step(Gameboy.step(gb))
  end

  def save_state(gb, path \\ "state.gb") do
    File.write!(path, :erlang.term_to_binary(gb), [:write])
  end

  def load_state(path \\ "state.gb") do
    path
    |> File.read!()
    |> :erlang.binary_to_term()
  end

end
