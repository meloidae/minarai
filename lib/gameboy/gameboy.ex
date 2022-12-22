defmodule Gameboy do
  alias Gameboy.Hardware
  # alias Gameboy.Cpu
  alias Gameboy.RecordCpu, as: Cpu
  alias Gameboy.Hardware, as: Hardware
  # import Gameboy.Cpu, only: [fetch_next: 3, handle_interrupt: 2]
  # import Gameboy.Cpu.Decode, only: [decode_exec: 2]
  import Gameboy.Cpu.Decode, only: [cpu_step: 2, instruction: 3]
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
      Utils.init_counter_table()
    end
    {cpu, hw}
  end

  @counter_limit 17556 * 200
  def run(@counter_limit, cpu, hw) do
    Process.spawn(fn -> start_next({cpu, hw}) end, [:link])
  end
  def run(counter, cpu, hw) do
    receive do
      {:save, path} ->
        save_state({cpu, hw}, path)
        cpu_run(counter, cpu, hw)
      {:load, path} ->
        {cpu, hw} = load_state(path)
        cpu_run(counter, cpu, hw)
      {:save_latency, path} ->
        if :persistent_term.get({Minarai, :record_stats}, false) do
          Utils.save_frame_stats(path)
        else
          IO.puts("--record_stats option is not enabled")
        end
        cpu_run(counter, cpu, hw)
      {:key_down, key_name} ->
        cpu_run(counter, cpu, Hardware.keydown(hw, key_name))
      {:key_up, key_name} ->
        cpu_run(counter, cpu, Hardware.keyup(hw, key_name))
      _ ->
        cpu_run(counter, cpu, hw)
    after
      0 ->
        cpu_run(counter, cpu, hw)
    end
  end

  def cpu_run(counter, cpu, hw) do
    {cpu, hw} = Cpu.handle_interrupt(cpu, hw)
    state = Cpu.state(cpu)
    case state do
      :running ->
        {cpu, hw} = Cpu.fetch_next(cpu, hw, Cpu.read_register(cpu, :pc))
        cpu_decode_exec(counter, cpu, hw)
      :haltbug ->
        # Halt bug. Fetch but don't increment pc
        pc = Cpu.read_register(cpu, :pc)
        {cpu, hw} = Cpu.fetch_next(cpu, hw, pc)
        cpu = Cpu.write_register(cpu, :pc, pc)
              |> Cpu.set_state(:running)
        cpu_decode_exec(counter, cpu, hw)
      :halt ->
        # IO.puts("Halt")
        run(counter + 1, cpu, Hardware.sync_cycle(hw))
      _ -> # stop?
        # IO.puts("stop")
        run(counter + 1, cpu, hw)
    end
  end

  def cpu_decode_exec(counter, cpu, hw) do
    opcode = Cpu.opcode(cpu)
    delayed_ime = Cpu.delayed_ime(cpu)
    if delayed_ime == nil do
      {cpu, hw} = instruction(opcode, cpu, hw)
      run(counter + 1, cpu, hw)
    else
      {cpu, hw} = instruction(opcode, cpu, hw)
      run(counter + 1, Cpu.apply_delayed_ime(cpu, delayed_ime), hw)
    end
  end

  def start_next({cpu, hw}) do
    ui_pid = :ets.lookup_element(:gb_process, :logic_pid, 2)
    :erlang.trace(self(), true, [:garbage_collection, tracer: ui_pid])
    :ets.update_element(:gb_process, :logic_pid, {2, self()})
    run(0, cpu, hw)
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
