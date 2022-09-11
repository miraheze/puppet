# frozen_string_literal: true

require 'spec_helper'

describe 'Stdlib::HTTPUrl' do
  describe 'valid handling' do
    ['https://hello.com', 'https://notcreative.org', 'https://canstillaccepthttps.co.uk', 'http://anhttp.com', 'http://runningoutofideas.gov',
     'http://', 'http://graphemica.com/❤', 'http://graphemica.com/緩', 'HTTPS://FOO.COM', 'HTTP://BAR.COM'].each do |value|
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
        "\nhttp://hello.com",
        "\nhttp://hello.com\n",
        "http://hello.com\n",
        'httds://notquiteright.org',
        'hptts:/nah',
        'https;//notrightbutclose.org',
        'hts://graphemica.com/❤',
        'https:graphemica.com/緩',
      ].each do |value|
        describe value.inspect do
          it { is_expected.not_to allow_value(value) }
        end
      end
    end
  end
end
