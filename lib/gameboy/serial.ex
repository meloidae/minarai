defmodule Gameboy.Serial do
  defstruct sb: 0x00,
            sc: 0x00

  # Implementations of read/write are temporary

  def serial_data(serial), do: serial.sb
  def set_serial_data(serial, value), do: Map.put(serial, :sb, value)

  def serial_control(serial), do: serial.sc
  def set_serial_control(serial, value) do
    # Debug output
    if value === 0x81 do
      char = serial_data(serial)
      IO.write(<<char>>)
    end
    Map.put(serial, :sc, value)
  end
end
