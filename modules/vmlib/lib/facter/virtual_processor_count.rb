# facter v3 is reporting processor count incorrectly, to work around this we are using the etc module.

require 'etc'

Facter.add(:virtual_processor_count) do
  has_weight 100
  setcode do
    processors = Etc.nprocessors
  end
end
