defmodule Gameboy do
  alias Gameboy.Hardware
  alias Gameboy.Cpu
  alias Gameboy.SimplePpu, as: Ppu
  import Gameboy.Cpu, only: [fetch_next: 3, handle_interrupt: 2]
  import Gameboy.Cpu.Decode, only: [decode_exec: 2]
  import Gameboy.Cpu.Disassemble, only: [disassemble: 3]
  alias Gameboy.Joypad
  alias Gameboy.Interrupts
  alias Gameboy.Utils


  def init(opts \\ nil) do
    cpu = Cpu.init()
    hw = Hardware.init(opts)
    # IO.puts("#{inspect(:erlang.process_info(self()))}")
    if :persistent_term.get({Minarai, :record_stats}, false) do
      Utils.init_stats_table()
    end
    {cpu, hw}
  end

  def step({cpu, hw} = gb) do
    {cpu, hw} = receive do
      {:save, path} ->
        save_state(gb, path)
        gb
      {:load, path} ->
        load_state(path)
      {:save_latency, path} ->
        if :persistent_term.get({Minarai, :record_stats}, false) do
          Utils.save_frame_stats(path)
        else
          IO.puts("--record_stats option is not enabled")
        end
        gb
      {:key_down, key_name} ->
        hw = Hardware.keydown(hw, key_name)
        {cpu, hw}
      {:key_up, key_name} ->
        hw = Hardware.keyup(hw, key_name)
        {cpu, hw}
    after
      0 ->
        gb
    end
    # Handle interrupts
    {%{pc: pc, state: state} = cpu, hw} = handle_interrupt(cpu, hw)
    case state do
      :running ->
        {cpu, hw} = fetch_next(cpu, hw, pc)
        decode_exec(cpu, hw)
      :haltbug ->
        # Halt bug. Fetch but don't increment pc
        {cpu, hw} = fetch_next(cpu, hw, pc)
        cpu = %{cpu | pc: pc, state: :running}
        decode_exec(cpu, hw)
      :halt ->
        # IO.puts("Halt")
        {cpu, Hardware.sync_cycle(hw)}
      _ -> # stop?
        # IO.puts("stop")
        # gb
        {cpu, hw}
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
  defp debug_loop({%{cpu: %{pc: pc}}, _} = gb) when pc >= @break, do: debug_step(gb)
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

  def save_state(gb, path \\ "state.save") do
    IO.puts("Saving the game state to #{path}")
    File.write!(path, :erlang.term_to_binary(gb), [:write])
  end

  def load_state(path \\ "state.save") do
    state = path 
            |> File.read!()
            |> :erlang.binary_to_term()
    IO.puts("Loading the game state from #{path}")
    state
  end

end
