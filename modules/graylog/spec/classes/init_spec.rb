require 'spec_helper'
describe 'graylog' do
  context 'with default values for all parameters' do
    it { is_expected.to contain_class('graylog') }
  end
end
