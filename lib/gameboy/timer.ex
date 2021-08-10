defmodule Gameboy.Timer do
  use Bitwise
  alias Gameboy.Timer
  alias Gameboy.Interrupts

  defstruct tima: 0x00,
            tma: 0x00,
            tac: 0x00,
            ref: nil,
            counter: 0x00, # internal counter
            overflow: false # true if there was an overflow for tima in the previoius cycle

  @timer_enable 0..0xff
  |> Enum.map(fn x -> (x &&& 0x4) != 0 end)
  |> List.to_tuple()
            
  @counter_mask 0..0xff
  |> Enum.map(fn x -> 
    case x &&& 0b11 do
      0b00 -> 1 <<< 7
      0b01 -> 1 <<< 1
      0b10 -> 1 <<< 3
      _ -> 1 <<< 5
    end
  end)
  |> List.to_tuple()


  def init do
    # ref = :atomics.new(1, [signed: false])
    # %Timer{ref: ref}
    %Timer{}
  end

  @compile {:inline, check_counter_bit: 2}
  defp check_counter_bit(counter, tac), do: (counter &&& elem(@counter_mask, tac)) != 0

  # Any read to a timer register requires updating counters first
  def div_cycle(timer, intr) do
    timer = cycle(timer, intr)
    {timer.counter >>> 6, timer}
  end

  def set_div_cycle(timer, intr) do
    timer = cycle(timer, intr)
    # When writing to div, div is set to 0.
    # If the counter bit of div is 1, then its change to 0 causes a fallen edge, so tima is incremented
    timer = if check_counter_bit(timer.counter, timer.tac) do
      new_tima = timer.tima + 1
      if new_tima > 0xff do
        %{timer | tima: 0, overflow: true}
      else
        %{timer | tima: new_tima}
      end
    else
      timer
    end
    %{timer | counter: 0}
  end

  def tima_cycle(timer, intr) do
    timer = cycle(timer, intr)
    {timer.tima, timer}
  end

  def set_tima_cycle(timer, intr, value) do
    overflow = timer.overflow
    timer = cycle(timer, intr)
    if overflow do
      # In a cycle following the overflow, write to tima is ignored and overwritten by vaue in tma
      timer
    else
      # If write to tima occurs in a cycle of overflow, loading from tma in the following cycle is canceled
      # That is why overflow is set to false here
      %{timer | tima: value, overflow: false}
    end
  end

  def tma_cycle(timer, intr) do
    timer = cycle(timer, intr)
    {timer.tma, timer}
  end

  def set_tma_cycle(timer, intr, value) do
    overflow = timer.overflow
    timer = cycle(timer, intr)
    if overflow do
      # If tma is written in a cycle following an overflow, the new vaue of tma is loaded to tima
      %{timer | tma: value, tima: value}
    else
      %{timer | tma: value}
    end
  end

  def tac_cycle(timer, intr) do
    timer = cycle(timer, intr)
    {timer.tac, timer}
  end

  @tac_value 0..0xff
  |> Enum.map(fn x ->
    lower_bits = x &&& 0b111
    0b11111000 ||| lower_bits
  end)
  |> List.to_tuple()
  def set_tac_cycle(timer, intr, value) do
    timer = cycle(timer, intr)
    old_bit = elem(@timer_enable, timer.tac) and check_counter_bit(timer.counter, timer.tac)
    new_tac = elem(@tac_value, value)
    new_bit = elem(@timer_enable, new_tac) and check_counter_bit(timer.counter, new_tac)
    # If counter bit goes from 1 -> 0, there's a fallen edge, so increment
    # This happens even when counter bit to monitor is changed
    # Same thing occurs when the timer is disabled
    if old_bit and !new_bit do
      new_tima = timer.tima + 1
      if new_tima > 0xff do
        %{timer | tima: 0, overflow: true, tac: new_tac}
      else
        %{timer | tima: new_tima, tac: new_tac}
      end
    else
      %{timer | tac: new_tac}
    end
  end

  def cycle(timer, intr) do
    if timer.overflow do
      # Request interrupt
      # Timer interrupt and load from tma is delayed 1 cycle from an actual overflow
      Interrupts.request(intr, :timer)
      %{timer | counter: (timer.counter + 1) &&& 0xffff, tima: timer.tima, overflow: false}
    else
      if elem(@timer_enable, timer.tac) and check_counter_bit(timer.counter, timer.tac) do
        new_counter = (timer.counter + 1) &&& 0xffff
        # Detected a fallen edge on a counter bit = increment, ex. 0x0111 -> 0x1000
        if !check_counter_bit(new_counter, timer.tac) do
          new_tima = timer.tima + 1
          if new_tima > 0xff do # tima overflow
            %{timer | counter: new_counter, tima: 0, overflow: true}
          else
            %{timer | counter: new_counter, tima: new_tima}
          end
        else
          %{timer | counter: (timer.counter + 1) &&& 0xffff}
        end
      else
        %{timer | counter: (timer.counter + 1) &&& 0xffff}
      end
    end
    # :atomics.add(timer.ref, 1, 1)
  end

end
