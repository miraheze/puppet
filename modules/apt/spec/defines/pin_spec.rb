# frozen_string_literal: true

require 'spec_helper'
describe 'apt::pin', type: :define do
  let :pre_condition do
    'class { "apt": }'
  end
  let(:facts) do
    {
      os: {
        family: 'Debian',
        name: 'Debian',
        release: {
          major: '8',
          full: '8.0',
        },
        distro: {
          codename: 'jessie',
          id: 'Debian',
        },
      },
    }
  end
  let(:title) { 'my_pin' }

  context 'with defaults' do
    it { is_expected.to contain_apt__setting('pref-my_pin').with_content(%r{Explanation: : my_pin\nPackage: \*\nPin: release a=my_pin\nPin-Priority: 0\n}) }
  end

  context 'with set version' do
    let :params do
      {
        'packages' => 'vim',
        'version'  => '1',
      }
    end

    it { is_expected.to contain_apt__setting('pref-my_pin').with_content(%r{Explanation: : my_pin\nPackage: vim\nPin: version 1\nPin-Priority: 0\n}) }
  end

  context 'with set origin' do
    let :params do
      {
        'packages' => 'vim',
        'origin'   => 'test',
      }
    end

    it { is_expected.to contain_apt__setting('pref-my_pin').with_content(%r{Explanation: : my_pin\nPackage: vim\nPin: origin test\nPin-Priority: 0\n}) }
  end

  context 'without defaults' do
    let :params do
      {
        'explanation'     => 'foo',
        'order'           => 99,
        'release'         => '1',
        'codename'        => 'bar',
        'release_version' => '2',
        'component'       => 'baz',
        'originator'      => 'foobar',
        'label'           => 'foobaz',
        'priority'        => 10,
      }
    end

    it { is_expected.to contain_apt__setting('pref-my_pin').with_content(%r{Explanation: foo\nPackage: \*\nPin: release a=1, n=bar, v=2, c=baz, o=foobar, l=foobaz\nPin-Priority: 10\n}) }
    it {
      is_expected.to contain_apt__setting('pref-my_pin').with('priority' => 99)
    }
  end

  context 'with ensure absent' do
    let :params do
      {
        'ensure' => 'absent',
      }
    end

    it {
      is_expected.to contain_apt__setting('pref-my_pin').with('ensure' => 'absent')
    }
  end

  context 'with bad characters' do
    let(:title) { 'such  bad && wow!' }

    it { is_expected.to contain_apt__setting('pref-such__bad____wow_') }
  end

  describe 'validation' do
    context 'with invalid order' do
      let :params do
        {
          'order' => 'foo',
        }
      end

      it do
        is_expected.to raise_error(Puppet::Error, %r{expects an Integer value, got String})
      end
    end

    context 'with packages == * and version' do
      let :params do
        {
          'version' => '1',
        }
      end

      it do
        is_expected.to raise_error(Puppet::Error, %r{parameter version cannot be used in general form})
      end
    end

    context 'with packages == * and release and origin' do
      let :params do
        {
          'origin'  => 'test',
          'release' => 'foo',
        }
      end

      it do
        is_expected.to raise_error(Puppet::Error, %r{parameters release and origin are mutually exclusive})
      end
    end

    context 'with specific release and origin' do
      let :params do
        {
          'release'  => 'foo',
          'origin'   => 'test',
          'packages' => 'vim',
        }
      end

      it do
        is_expected.to raise_error(Puppet::Error, %r{parameters release, origin, and version are mutually exclusive})
      end
    end

    context 'with specific version and origin' do
      let :params do
        {
          'version'  => '1',
          'origin'   => 'test',
          'packages' => 'vim',
        }
      end

      it do
        is_expected.to raise_error(Puppet::Error, %r{parameters release, origin, and version are mutually exclusive})
      end
    end
  end
end
