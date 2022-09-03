require 'spec_helper_acceptance'

pp = <<-PUPPETCODE
  include icinga::repos
PUPPETCODE

describe 'icinga repositories' do
  context 'icinga::repos with defaults' do
    it { idempotent_apply(pp) }
  end
end
