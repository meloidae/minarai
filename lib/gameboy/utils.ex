defmodule Gameboy.Utils do
  def to_hex(num, min_digits \\ 4) do
    num_string = Integer.to_string(num, 16)
    zeros = min_digits - String.length(num_string)
    if zeros > 0, do: "#{String.duplicate("0", zeros)}#{num_string}", else: num_string
  end

  def break_point(%{cpu: cpu} = gb, target_pc \\ 0x001c) do
    cpu.pc == target_pc
  end

  def measure(function) do
    {t, v} = function
             |> :timer.tc
    {t |> Kernel./(1_000_000), v}
  end

  @stats_table :stats_table
  def stats_table_name, do: @stats_table

  def init_stats_table do
    :ets.new(@stats_table, [:named_table])
    :ets.insert(@stats_table, {:counter, 0})
  end

  def store_timestamp do
    # Stores current statistical information to ets
    # Returns how many stats points are stored at that moment
    [{_, index} | _] = :ets.lookup(@stats_table, :counter)
    curr_time = System.monotonic_time()
    mem = :erlang.memory(:total)
    info = :erlang.process_info(self(), [:memory, :total_heap_size, :heap_size, :stack_size])
    :ets.insert(@stats_table, {index, curr_time, mem, info})
    :ets.insert(@stats_table, {:counter, index + 1})
    index + 1
  end

  def save_frame_stats(path) do
    [{_, index} | _] = :ets.lookup(@stats_table, :counter)
    index = index - 1
    [{_, last, _, _} | _] = :ets.lookup(@stats_table, index)
    {stats, _} = index - 1..0
    |> Enum.reduce({[], last}, fn i, {acc, future} ->
      [{_, now, total_memory, [memory: memory, total_heap_size: total_heap_size, heap_size: heap_size, stack_size: stack_size]} | _] = :ets.lookup(@stats_table, i)
      diff = System.convert_time_unit(future - now, :native, :microsecond)
             |> round()
      {["#{i + 1},#{diff},#{total_memory},#{memory},#{total_heap_size},#{heap_size},#{stack_size}\n" | acc], now}
    end)
    stats = IO.iodata_to_binary(stats)
    File.open(path, [:write], fn file ->
      IO.write(file, "frame,latency,total_memory,memory,total_heap_size,heap_size,stack_size\n")
      IO.write(file, stats)
    end)
    IO.puts("Stats saved to: #{path}")
    # Reset index value
    :ets.insert(@stats_table, {:counter, 0})
  end
end
