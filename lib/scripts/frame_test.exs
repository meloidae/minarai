defmodule Gameboy.Test.Frame do
  # alias Mix.Tasks.Profile.Fprof
  # def run_frame(gb) when gb.hw.counter >= 70224, do: gb
  def run_frame({_, %{counter: counter}} = gb) when counter >= 70224, do: gb
  def run_frame(gb), do: run_frame(Gameboy.step(gb))
  def run_frames_fps(gb, 0, fps_info), do: {gb, fps_info}
  # def run_frames_fps(gb, 6 = n, fps_info) do
  #   start_time = System.monotonic_time()
  #   Fprof.profile(fn -> run_frame(gb) end, [:callers, :details])
  #   gb = run_frame(gb)
  #   end_time = System.monotonic_time()
  #   {cpu, hw} = gb
  #   gb = {cpu, Map.put(hw, :counter, 0)}
  #   fps = 1_000 / System.convert_time_unit(end_time - start_time, :native, :millisecond)
  #   run_frames_fps(gb, n - 1, [fps | fps_info])
  # end
  def run_frames_fps(gb, n, fps_info) do
    start_time = System.monotonic_time()
    gb = run_frame(gb)
    end_time = System.monotonic_time()
    {cpu, hw} = gb
    gb = {cpu, Map.put(hw, :counter, 0)}
    fps = 1_000 / System.convert_time_unit(end_time - start_time, :native, :millisecond)
    run_frames_fps(gb, n - 1, [fps | fps_info])
  end

  def run_frames(gb, 0), do: gb
  def run_frames(gb, n) do
    run_frames(run_frame(gb), n - 1)
  end
end

# frames = 20 * 60
frames = 60
# gb = Gameboy.init()
{cpu, hw} = "state.gb"
            |> File.read!()
            |> :erlang.binary_to_term()
gb = {cpu, Map.put(hw, :counter, 0)}

{_gb, fps_info} = Gameboy.Test.Frame.run_frames_fps(gb, frames, [])
for {i, fps} <- Stream.zip(Stream.iterate(0, &(&1 + 1)), Enum.reverse(fps_info)) do
  IO.puts("#{i}: #{fps}")
end
avg = Enum.sum(fps_info) / length(fps_info)
IO.puts("Avg: #{avg}")
