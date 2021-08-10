defmodule Minarai.Text do
  @zero_bin  ".####" <>
             ".#..#" <>
             ".#..#" <>
             ".#..#" <>
             ".#..#" <>
             ".#..#" <>
             ".####"
  @one_bin   "....#" <>
             "....#" <>
             "....#" <>
             "....#" <>
             "....#" <>
             "....#" <>
             "....#"
  @two_bin   ".####" <>
             "....#" <>
             "....#" <>
             ".####" <>
             ".#..." <>
             ".#..." <>
             ".####"
  @three_bin ".####" <>
             "....#" <>
             "....#" <>
             ".####" <>
             "....#" <>
             "....#" <>
             ".####"
  @four_bin  ".#..#" <>
             ".#..#" <>
             ".#..#" <>
             ".####" <>
             "....#" <>
             "....#" <>
             "....#"
  @five_bin  ".####" <>
             ".#..." <>
             ".#..." <>
             ".####" <>
             "....#" <>
             "....#" <>
             ".####"
  @six_bin   ".####" <>
             ".#..." <>
             ".#..." <>
             ".####" <>
             ".#..#" <>
             ".#..#" <>
             ".####"
  @seven_bin ".####" <>
             "....#" <>
             "....#" <>
             "....#" <>
             "....#" <>
             "....#" <>
             "....#"
  @eight_bin ".####" <>
             ".#..#" <>
             ".#..#" <>
             ".####" <>
             ".#..#" <>
             ".#..#" <>
             ".####"
  @nine_bin  ".####" <>
             ".#..#" <>
             ".#..#" <>
             ".####" <>
             "....#" <>
             "....#" <>
             ".####"

  @black <<0, 0, 0>>
  @white <<255, 255, 255>>

  @zero @zero_bin
  |> :binary.bin_to_list()
  |> Stream.map(fn c -> if c === ?#, do: @white, else: @black end)
  |> Enum.chunk_every(5)
  |> Enum.map(fn r -> IO.iodata_to_binary(r) end)
  @one @one_bin
  |> :binary.bin_to_list()
  |> Stream.map(fn c -> if c === ?#, do: @white, else: @black end)
  |> Enum.chunk_every(5)
  |> Enum.map(fn r -> IO.iodata_to_binary(r) end)
  @two @two_bin
  |> :binary.bin_to_list()
  |> Stream.map(fn c -> if c === ?#, do: @white, else: @black end)
  |> Enum.chunk_every(5)
  |> Enum.map(fn r -> IO.iodata_to_binary(r) end)
  @three @three_bin
  |> :binary.bin_to_list()
  |> Stream.map(fn c -> if c === ?#, do: @white, else: @black end)
  |> Enum.chunk_every(5)
  |> Enum.map(fn r -> IO.iodata_to_binary(r) end)
  @four @four_bin
  |> :binary.bin_to_list()
  |> Stream.map(fn c -> if c === ?#, do: @white, else: @black end)
  |> Enum.chunk_every(5)
  |> Enum.map(fn r -> IO.iodata_to_binary(r) end)
  @five @five_bin
  |> :binary.bin_to_list()
  |> Stream.map(fn c -> if c === ?#, do: @white, else: @black end)
  |> Enum.chunk_every(5)
  |> Enum.map(fn r -> IO.iodata_to_binary(r) end)
  @six @six_bin
  |> :binary.bin_to_list()
  |> Stream.map(fn c -> if c === ?#, do: @white, else: @black end)
  |> Enum.chunk_every(5)
  |> Enum.map(fn r -> IO.iodata_to_binary(r) end)
  @seven @seven_bin
  |> :binary.bin_to_list()
  |> Stream.map(fn c -> if c === ?#, do: @white, else: @black end)
  |> Enum.chunk_every(5)
  |> Enum.map(fn r -> IO.iodata_to_binary(r) end)
  @eight @eight_bin
  |> :binary.bin_to_list()
  |> Stream.map(fn c -> if c === ?#, do: @white, else: @black end)
  |> Enum.chunk_every(5)
  |> Enum.map(fn r -> IO.iodata_to_binary(r) end)
  @nine @nine_bin
  |> :binary.bin_to_list()
  |> Stream.map(fn c -> if c === ?#, do: @white, else: @black end)
  |> Enum.chunk_every(5)
  |> Enum.map(fn r -> IO.iodata_to_binary(r) end)

  @digits {@zero, @one, @two, @three, @four, @five, @six, @seven, @eight, @nine}

  @digit_width 5
  @digit_height 7

  def number_binary(num) do
    num = trunc(num)
    digits = Integer.digits(num)
    num_digits = length(digits)
    [head | digits] = digits
    # buffer = make_binary(digits, elem(@digits, head))
    buffer = try do
      make_binary(digits, elem(@digits, head))
    rescue
      _ ->
        IO.puts("num = #{num}")
        receive do
          _ ->
            :ok
        end
    end
    %{w: num_digits * @digit_width, h: @digit_height, buffer: buffer}
  end

  defp make_binary([], rows), do: IO.iodata_to_binary(rows)
  defp make_binary([digit | rest], rows) do
    rows = Stream.zip(rows, elem(@digits, digit))
    |> Enum.map(fn {x, y} -> [x | y] end)
    make_binary(rest, rows)
  end

end
