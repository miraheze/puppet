require 'socket'

Facter.add(:virtual_ip_address) do
  has_weight 100
  setcode do
    ip = Socket.ip_address_list[2].ip_address
  end
end
