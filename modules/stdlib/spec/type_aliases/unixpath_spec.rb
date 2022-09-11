# frozen_string_literal: true

require 'spec_helper'

describe 'Stdlib::Unixpath' do
  describe 'valid handling' do
    ['/usr2/username/bin:/usr/local/bin:/usr/bin:.', '/var/tmp', '/Users/helencampbell/workspace/puppetlabs-stdlib', '/var/ůťƒ8', '/var/ネット', '/var//tmp', '/var/../tmp'].each do |value|
      describe value.inspect do
        it { is_expected.to allow_value(value) }
      end
    end
  end

  describe 'invalid path handling' do
    context 'with garbage inputs' do
      [
        nil,
        [nil],
        [nil, nil],
        { 'foo' => 'bar' },
        {},
        '',
        "\n/var/tmp",
        "\n/var/tmp\n",
        "/var/tmp\n",
        'C:/whatever',
        '\\var\\tmp',
        '\\Users/hc/wksp/stdlib',
        '*/Users//nope',
        "var\ůťƒ8",
        "var\ネット",
      ].each do |value|
        describe value.inspect do
          it { is_expected.not_to allow_value(value) }
        end
      end
    end
  end
end
