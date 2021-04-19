# frozen_string_literal: true

require 'spec_helper'

describe 'apt::source', type: :define do
  GPG_KEY_ID = '6F6B15509CF8E59E6E469F327F438280EF8D349F'

  let :title do
    'my_source'
  end

  let :facts do
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

  context 'with mostly defaults' do
    let :params do
      {
        'include' => { 'deb' => false, 'src' => true },
        'location' => 'http://debian.mirror.iweb.ca/debian/',
      }
    end

    it {
      is_expected.to contain_apt__setting('list-my_source').with_content(%r{# my_source\ndeb-src http://debian.mirror.iweb.ca/debian/ jessie main\n})
    }
  end

  context 'with no defaults' do
    let :params do
      {
        'comment'        => 'foo',
        'location'       => 'http://debian.mirror.iweb.ca/debian/',
        'release'        => 'sid',
        'repos'          => 'testing',
        'include'        => { 'src' => false },
        'key'            => GPG_KEY_ID,
        'pin'            => '10',
        'architecture'   => 'x86_64',
        'allow_unsigned' => true,
      }
    end

    it {
      is_expected.to contain_apt__setting('list-my_source').with_content(%r{# foo\ndeb \[arch=x86_64 trusted=yes\] http://debian.mirror.iweb.ca/debian/ sid testing\n})
                                                           .without_content(%r{deb-src})
    }

    it {
      is_expected.to contain_apt__pin('my_source').that_comes_before('Apt::Setting[list-my_source]').with('ensure' => 'present',
                                                                                                          'priority' => '10',
                                                                                                          'origin'   => 'debian.mirror.iweb.ca')
    }

    it {
      is_expected.to contain_apt__key("Add key: #{GPG_KEY_ID} from Apt::Source my_source").that_comes_before('Apt::Setting[list-my_source]').with('ensure' => 'present',
                                                                                                                                                  'id' => GPG_KEY_ID)
    }
  end

  context 'when allow_unsigned true' do
    let :params do
      {
        'include'        => { 'src' => false },
        'location'       => 'http://debian.mirror.iweb.ca/debian/',
        'allow_unsigned' => true,
      }
    end

    it { is_expected.to contain_apt__setting('list-my_source').with_content(%r{# my_source\ndeb \[trusted=yes\] http://debian.mirror.iweb.ca/debian/ jessie main\n}) }
  end

  context 'with architecture equals x86_64' do
    let :params do
      {
        'location'     => 'http://debian.mirror.iweb.ca/debian/',
        'architecture' => 'x86_64',
      }
    end

    it {
      is_expected.to contain_apt__setting('list-my_source').with_content(%r{# my_source\ndeb \[arch=x86_64\] http://debian.mirror.iweb.ca/debian/ jessie main\n})
    }
  end

  context 'with ensure => absent' do
    let :params do
      {
        'ensure' => 'absent',
      }
    end

    it {
      is_expected.to contain_apt__setting('list-my_source').with('ensure' => 'absent')
    }
  end

  describe 'validation' do
    context 'with no release' do
      let :facts do
        {
          os: {
            family: 'Debian',
            name: 'Debian',
            release: {
              major: '8',
              full: '8.0',
            },
            distro: {
              id: 'Debian',
            },
          },
        }
      end

      it do
        is_expected.to raise_error(Puppet::Error, %r{os.distro.codename fact not available: release parameter required})
      end
    end
  end
end
