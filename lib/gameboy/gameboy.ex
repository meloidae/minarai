defmodule Gameboy do
  alias Gameboy.Hardware
  # alias Gameboy.Cpu
  alias Gameboy.RecordCpu, as: Cpu
  # import Gameboy.Cpu, only: [fetch_next: 3, handle_interrupt: 2]
  # import Gameboy.Cpu.Decode, only: [decode_exec: 2]
  import Gameboy.Cpu.Decode, only: [cpu_step: 2]
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
    # Store read-only terms
    # cartrom = Hardware.get_cart(hw).rom
    # {bootrom, _} = Hardware.get_bootrom(hw)
    # :persistent_term.put({Minarai, :cartrom}, cartrom)
    # :persistent_term.put({Minarai, :bootrom}, bootrom)
    {cpu, hw}
  end

  def step({cpu, hw} = gb) do
    hw = receive do
      {:save, path} ->
        save_state(gb, path)
        hw
      {:load, path} ->
        load_state(path)
      {:save_latency, path} ->
        if :persistent_term.get({Minarai, :record_stats}, false) do
          Utils.save_frame_stats(path)
        else
          IO.puts("--record_stats option is not enabled")
        end
        hw
      {:key_down, key_name} ->
        Hardware.keydown(hw, key_name)
      {:key_up, key_name} ->
        Hardware.keyup(hw, key_name)
      _ ->
        hw
    after
      0 ->
        hw
    end
    cpu_step(cpu, hw)
  end

  # def start(opts \\ []) do
  #   gb = Gameboy.init(opts)
  #   loop(gb)
  # end

  # def run({cpu, hw}) do
  #   loop({cpu, hw})
  # end
  # defp loop(gb), do: loop(Gameboy.step(gb))

  @counter_limit 17556 * 200
  def start_chain(gb) do
    ui_pid = :ets.lookup_element(:gb_process, :logic_pid, 2)
    :erlang.trace(self(), true, [:garbage_collection, tracer: ui_pid])
    :ets.update_element(:gb_process, :logic_pid, {2, self()})
    loop_and_chain(0, gb)
  end
  defp loop_and_chain(@counter_limit, gb) do
    Process.spawn(fn -> start_chain(gb) end, [:link])
  end
  defp loop_and_chain(counter, {_cpu, _hw} = gb), do: loop_and_chain(counter + 1, Gameboy.step(gb))

  def resume(pid, gb) do
    send(pid, {:resume, gb})
    # gb_bin = :erlang.term_to_binary(gb)
    # send(pid, {:resume_bin, gb_bin})
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
