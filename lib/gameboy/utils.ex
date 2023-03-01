defmodule Gameboy.Utils do
  def to_hex(num, min_digits \\ 4) do
    num_string = Integer.to_string(num, 16)
    zeros = min_digits - String.length(num_string)
    if zeros > 0, do: "#{String.duplicate("0", zeros)}#{num_string}", else: num_string
  end

  def break_point(%{cpu: cpu} = _gb, target_pc \\ 0x001c) do
    cpu.pc == target_pc
  end

  def measure(function) do
    {t, v} = function
             |> :timer.tc
    {t |> Kernel./(1_000_000), v}
  end

  @stats_table :stats_table
  @fn_counter_table :fn_counter_table
  @mem_counter_table :mem_counter_table
  def stats_table, do: @stats_table

  def init_stats_table do
    :ets.new(@stats_table, [:named_table, :public])
    :ets.insert(@stats_table, {:counter, 0})
  end

  def store_timestamp do
    # Stores current statistical information to ets
    # Returns how many stats points are stored at that moment
    index = :ets.lookup_element(@stats_table, :counter, 2)
    curr_time = System.monotonic_time()
    mem = :erlang.memory(:total)
    info = :erlang.process_info(self(), [:memory, :total_heap_size, :heap_size, :stack_size])
    :ets.insert(@stats_table, {index, curr_time, mem, info})
    :ets.insert(@stats_table, {:counter, index + 1})
    index + 1
  end

  def store_cycle(cycle) do
    :ets.insert(@stats_table, {:total_cycle, cycle})
  end

  def get_cycle() do
    case :ets.lookup(@stats_table, :total_cycle) do
      [] ->
        0
      [{:total_cycle, cycle}] ->
        cycle
    end
  end

  def save_frame_stats(path) do
    index = :ets.lookup_element(@stats_table, :counter, 2)
    index = index - 1
    last = :ets.lookup_element(@stats_table, index, 2)
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
    fn_counts = :ets.tab2list(@fn_counter_table)
    if fn_counts != [] do
      fn_counts = Enum.sort(fn_counts, fn {_, i}, {_, j} -> i >= j end)
      File.open("log/fn_counts.txt", [:write], fn file ->
        fn_counts |> Enum.each(fn {name, count} ->
          IO.write(file, "#{name}\t#{count}\n")
        end)
      end)
    end
  end

  def get_frame_counter do
    case :ets.lookup(@stats_table, :counter) do
      [{_, index} | _] ->
        index
      _ ->
        -1
    end
  end

  def fn_counter_table, do: @fn_counter_table

  def init_counter_table do
    :ets.new(@fn_counter_table, [:named_table, :public])
    :ets.new(@mem_counter_table, [:named_table, :public])
  end

  def update_fn_counter(name) do
    :ets.update_counter(@fn_counter_table, name, 1, {name, 0})
  end

  def update_mem_counter(name) do
    :ets.update_counter(@mem_counter_table, name, 1, {name, 0})
  end

  def is_plain_string(code) do
    # Check if given code (as a string) represents a plain string as AST
    ast = Code.string_to_quoted!(code)
    is_binary(ast)
  end

  def compile_template(template_path, props) when is_tuple(props) do
    compile_template(template_path, [props])
  end
  def compile_template(template_path, props) do
    template_string = File.read!(template_path)
    compile_template_string(template_string, props)
  end
  def compile_template_string(string, []) do
    Code.compile_string(string)
  end
  def compile_template_string(string, [{k, v} | rest]) do
    key_string = "@{#{k}}"
    compile_template_string(String.replace(string, key_string, v), rest)
  end
end
