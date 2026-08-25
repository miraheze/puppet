# frozen_string_literal: true

require 'spec_helper'

describe 'Chrony::Servers' do
  [
    ['ntp1.example.com', 'ntp2.example.com'],
    {
      'ntp1.example.com' => [],
      'ntp2.example.com' => ['maxpoll 6'],
    },
    {},
    [],
    {
      'ntp1.example.com' => :undef,
    },
  ].each do |value|
    describe value.inspect do
      it { is_expected.to allow_value(value) }
    end
  end
end
