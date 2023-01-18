defmodule Gameboy do
  import Bitwise

  alias Gameboy.Hardware
  # alias Gameboy.Cpu
  # alias Gameboy.RecordCpu, as: Cpu
  alias Gameboy.SmallCpu, as: Cpu
  alias Gameboy.Hardware, as: Hardware
  # import Gameboy.Cpu, only: [fetch_next: 3, handle_interrupt: 2]
  # import Gameboy.Cpu.Decode, only: [decode_exec: 2]
  # import Gameboy.Cpu.Decode, only: [cpu_step: 2, instruction: 3]
  import Gameboy.Cpu.Decode, only: [instruction: 3]
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

  @compile {:inline, cpu_run: 3}
  def cpu_run(counter, cpu, hw) do
    # cpu_tick(counter, cpu, hw)
    cpu_prestep(counter, cpu, hw)
  end

  def cpu_tick(counter, cpu, hw) do
    {cpu, hw} = Cpu.handle_interrupt(cpu, hw)
    state = Cpu.state(cpu)
    case state do
      :running ->
        {cpu, hw} = Cpu.fetch_next(cpu, hw, Cpu.read_register(cpu, :pc))
        # Cpu.fetch_next(counter, cpu, hw, Cpu.read_register(cpu, :pc), &cpu_decode_exec/3)
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

  def cpu_prestep(counter, cpu, hw) do
    case Hardware.check_interrupt(hw) do
      {addr, mask} ->
        cond do
          Cpu.ime(cpu) ->
            pc = Cpu.read_register(cpu, :pc)
            sp = Cpu.read_register(cpu, :sp)
            # Add 8 cycles
            hw = Hardware.sync_cycle(hw) |> Hardware.sync_cycle()
            # Push value of pc on to stack
            low = pc &&& 0xff
            high = pc >>> 8
            sp = (sp - 1) &&& 0xffff
            hw = Hardware.synced_write(hw, sp, high)
            sp = (sp - 1) &&& 0xffff
            hw = Hardware.synced_write(hw, sp, low)
            # Acknowledge interrupt
            hw = Hardware.acknowledge_interrupt(hw, mask)
            # Change pc to address specified by interrupt and switch to running state
            cpu = Cpu.post_interrupt(cpu, sp, addr)
            cpu_step(counter, cpu, hw)
          Cpu.state(cpu) != :haltbug ->
            cpu = Cpu.set_state(cpu, :running)
            cpu_step(counter, cpu, hw)
          true ->
            cpu_step(counter, cpu, hw)
        end
      _ ->
        # No interrupt is requested
        cpu_step(counter, cpu, hw)
    end
  end

  def cpu_step(counter, cpu, hw) do
    case Cpu.state(cpu) do
      :running ->
        # {cpu, hw} = Cpu.fetch_next(cpu, hw, Cpu.read_register(cpu, :pc))
        # cpu_decode_exec(counter, cpu, hw)
        cpu_fetch_decode_exec(counter, cpu, hw, Cpu.read_register(cpu, :pc))
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

  def cpu_fetch_decode_exec(counter, cpu, hw, addr) do
    {opcode, hw} = Hardware.synced_read(hw, addr)
    if :persistent_term.get({Minarai, :count_fn_calls}, false) do
      Utils.update_counter(disassemble(opcode, cpu, hw))
    end
    cpu_decode_exec(counter, Cpu.post_fetch(cpu, addr, opcode), hw)
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
