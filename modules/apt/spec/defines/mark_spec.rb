# frozen_string_literal: true

require 'spec_helper'

describe 'apt::mark', type: :define do
  let :title do
    'my_source'
  end

  let :facts do
    {
      os: {
        family: 'Debian',
        name: 'Debian',
        release: {
          major: '9',
          full: '9.0',
        },
        distro: {
          codename: 'stretch',
          id: 'Debian',
        },
      },
    }
  end

  context 'with correct seting' do
    let :params do
      {
        'setting' => 'manual',
      }
    end

    it {
      is_expected.to contain_exec('apt-mark manual my_source')
    }
  end

  describe 'with wrong setting' do
    let :params do
      {
        'setting' => 'foobar',
      }
    end

    it do
      is_expected.to raise_error(Puppet::PreformattedError, %r{expects a match for Enum\['auto', 'hold', 'manual', 'unhold'\], got 'foobar'})
    end
  end

  [
    'package',
    'package1',
    'package_name',
    'package-name',
  ].each do |value|
    describe 'with a valid resource title' do
      let :title do
        value
      end

      let :params do
        {
          'setting' => 'manual',
        }
      end

      it do
        is_expected.to contain_exec("apt-mark manual #{title}")
      end
    end
  end

  [
    '|| ls -la ||',
    'packakge with space',
    'package<>|',
    '|| touch /tmp/foo.txt ||',
  ].each do |value|
    describe 'with an invalid resource title' do
      let :title do
        value
      end

      let :params do
        {
          'setting' => 'manual',
        }
      end

      it do
        is_expected.to raise_error(Puppet::PreformattedError, %r{Invalid package name: #{title}})
      end
    end
  end
end
