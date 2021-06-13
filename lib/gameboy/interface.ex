defprotocol Gameboy.HardwareInterface do
  def synced_read(hw, addr)
  def synced_read_high(hw, addr)
  def synced_write(hw, addr, data)
  def synced_write_high(hw, addr, data)
  def sync_cycle(hw)
end

