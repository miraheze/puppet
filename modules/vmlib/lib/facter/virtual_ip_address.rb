require 'socket'

Facter.add(:virtual_ip_address) do
  has_weight 100
  setcode do
    if Facter.value('virtual') == 'kvm'
      ip = Facter.value('ipaddress')
    else
      ip = Socket.ip_address_list[2].ip_address
    end
  end
end
