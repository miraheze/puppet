# frozen_string_literal: true

require 'spec_helper'

GPG_KEY_ID = '6F6B15509CF8E59E6E469F327F438280EF8D349F'

title_key_example = { id: GPG_KEY_ID,
                      ensure: 'present',
                      source: nil,
                      server: 'keyserver.ubuntu.com',
                      content: nil,
                      options: nil }

def default_apt_key_example(title)
  { id: title,
    ensure: 'present',
    source: nil,
    server: 'keyserver.ubuntu.com',
    content: nil,
    options: nil,
    refresh: false }
end

def bunch_things_apt_key_example(title, params)
  { id: title,
    ensure: 'present',
    source: 'http://apt.puppetlabs.com/pubkey.gpg',
    server: 'pgp.mit.edu',
    content: params[:content],
    options: 'debug' }
end

def absent_apt_key(title)
  { id: title,
    ensure: 'absent',
    source: nil,
    server: 'keyserver.ubuntu.com',
    content: nil,
    keyserver: nil }
end

describe 'apt::key' do
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

  let :title do
    GPG_KEY_ID
  end

  describe 'normal operation' do
    describe 'default options' do
      it 'contains the apt_key' do
        is_expected.to contain_apt_key(title).with(default_apt_key_example(title))
      end
      it 'contains the apt_key present anchor' do
        is_expected.to contain_anchor("apt_key #{title} present")
      end
    end

    describe 'title and key =>' do
      let :title do
        'puppetlabs'
      end

      let :params do
        {
          id: GPG_KEY_ID,
        }
      end

      it 'contains the apt_key' do
        is_expected.to contain_apt_key(title).with(title_key_example)
      end
      it 'contains the apt_key present anchor' do
        is_expected.to contain_anchor("apt_key #{GPG_KEY_ID} present")
      end
    end

    describe 'ensure => absent' do
      let :params do
        {
          ensure: 'absent',
        }
      end

      it 'contains the apt_key' do
        is_expected.to contain_apt_key(title).with(absent_apt_key(title))
      end
      it 'contains the apt_key absent anchor' do
        is_expected.to contain_anchor("apt_key #{title} absent")
      end
    end

    describe 'ensure => refreshed' do
      let :params do
        {
          ensure: 'refreshed',
        }
      end

      it 'contains the apt_key with refresh => true' do
        is_expected.to contain_apt_key(title).with(
          ensure: 'present',
          refresh: true,
        )
      end
    end

    describe 'set a bunch of things!' do
      let :params do
        {
          content: 'GPG key content',
          source: 'http://apt.puppetlabs.com/pubkey.gpg',
          server: 'pgp.mit.edu',
          options: 'debug',
        }
      end

      it 'contains the apt_key' do
        is_expected.to contain_apt_key(title).with(bunch_things_apt_key_example(title, params))
      end
      it 'contains the apt_key present anchor' do
        is_expected.to contain_anchor("apt_key #{title} present")
      end
    end

    context 'when domain with dash' do
      let(:params) do
        {
          server: 'p-gp.m-it.edu',
        }
      end

      it 'contains the apt_key' do
        is_expected.to contain_apt_key(title).with(id: title,
                                                   server: 'p-gp.m-it.edu')
      end
    end

    context 'with url' do
      let :params do
        {
          server: 'hkp://pgp.mit.edu',
        }
      end

      it 'contains the apt_key' do
        is_expected.to contain_apt_key(title).with(id: title,
                                                   server: 'hkp://pgp.mit.edu')
      end
    end
    context 'when url with port number' do
      let :params do
        {
          server: 'hkp://pgp.mit.edu:80',
        }
      end

      it 'contains the apt_key' do
        is_expected.to contain_apt_key(title).with(id: title,
                                                   server: 'hkp://pgp.mit.edu:80')
      end
    end
  end

  describe 'validation' do
    context 'when domain begin with dash' do
      let(:params) do
        {
          server: '-pgp.mit.edu',
        }
      end

      it 'fails' do
        is_expected .to raise_error(%r{expects a match})
      end
    end

    context 'when domain begin with dot' do
      let(:params) do
        {
          server: '.pgp.mit.edu',
        }
      end

      it 'fails' do
        is_expected .to raise_error(%r{expects a match})
      end
    end

    context 'when domain end with dot' do
      let(:params) do
        {
          server: 'pgp.mit.edu.',
        }
      end

      it 'fails' do
        is_expected .to raise_error(%r{expects a match})
      end
    end
    context 'when character url exceeded' do
      let :params do
        {
          server: 'hkp://pgpiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii.mit.edu',
        }
      end

      it 'fails' do
        is_expected.to raise_error(%r{expects a match})
      end
    end
    context 'with incorrect port number url' do
      let :params do
        {
          server: 'hkp://pgp.mit.edu:8008080',
        }
      end

      it 'fails' do
        is_expected.to raise_error(%r{expects a match})
      end
    end
    context 'with incorrect protocol for url' do
      let :params do
        {
          server: 'abc://pgp.mit.edu:80',
        }
      end

      it 'fails' do
        is_expected.to raise_error(%r{expects a match})
      end
    end
    context 'with missing port number url' do
      let :params do
        {
          server: 'hkp://pgp.mit.edu:',
        }
      end

      it 'fails' do
        is_expected.to raise_error(%r{expects a match})
      end
    end
    context 'with url ending with a dot' do
      let :params do
        {
          server: 'hkp://pgp.mit.edu.',
        }
      end

      it 'fails' do
        is_expected.to raise_error(%r{expects a match})
      end
    end
    context 'when url begins with a dash' do
      let(:params) do
        {
          server: 'hkp://-pgp.mit.edu',
        }
      end

      it 'fails' do
        is_expected.to raise_error(%r{expects a match})
      end
    end
    context 'with invalid key' do
      let :title do
        'Out of rum. Why? Why are we out of rum?'
      end

      it 'fails' do
        is_expected.to raise_error(%r{expects a match})
      end
    end

    context 'with invalid source' do
      let :params do
        {
          source: 'afp://puppetlabs.com/key.gpg',
        }
      end

      it 'fails' do
        is_expected.to raise_error(%r{evaluating a Resource})
      end
    end

    context 'with invalid content' do
      let :params do
        {
          content: [],
        }
      end

      it 'fails' do
        is_expected.to raise_error(%r{expects a})
      end
    end

    context 'with invalid server' do
      let :params do
        {
          server: 'two bottles of rum',
        }
      end

      it 'fails' do
        is_expected.to raise_error(%r{expects a match})
      end
    end

    context 'with invalid options' do
      let :params do
        {
          options: {},
        }
      end

      it 'fails' do
        is_expected.to raise_error(%r{expects a})
      end
    end

    context 'with invalid ensure' do
      ['foo', 'aabsent', 'absenta', 'apresent', 'presenta', 'refresh', 'arefreshed', 'refresheda'].each do |param|
        let :params do
          {
            ensure: param,
          }
        end

        it 'fails' do
          is_expected.to raise_error(%r{for Enum\['absent', 'present', 'refreshed'\], got})
        end
      end
    end

    describe 'duplication - two apt::key resources for same key, different titles' do
      let :pre_condition do
        "class { 'apt': }
        apt::key { 'duplicate': id => '#{title}', }"
      end

      it 'contains two apt::key resource - duplicate' do
        is_expected.to contain_apt__key('duplicate').with(id: title,
                                                          ensure: 'present')
      end
      it 'contains two apt::key resource - title' do
        is_expected.to contain_apt__key(title).with(id: title,
                                                    ensure: 'present')
      end

      it 'contains only a single apt_key - duplicate' do
        is_expected.to contain_apt_key('duplicate').with(default_apt_key_example(title))
      end
      it 'contains only a single apt_key - no title' do
        is_expected.not_to contain_apt_key(title)
      end
    end

    describe 'duplication - two apt::key resources, different ensure' do
      let :pre_condition do
        "class { 'apt': }
        apt::key { 'duplicate': id => '#{title}', ensure => 'absent', }"
      end

      it 'informs the user of the impossibility' do
        is_expected.to raise_error(%r{already ensured as absent})
      end
    end
  end

  describe 'defaults' do
    context 'when setting keyserver on the apt class' do
      let :pre_condition do
        'class { "apt":
          keyserver => "keyserver.example.com",
        }'
      end

      it 'uses default keyserver' do
        is_expected.to contain_apt_key(title).with_server('keyserver.example.com')
      end
    end

    context 'when setting key_options on the apt class' do
      let :pre_condition do
        'class { "apt":
          key_options => "http-proxy=http://proxy.example.com:8080",
        }'
      end

      it 'uses default keyserver' do
        is_expected.to contain_apt_key(title).with_options('http-proxy=http://proxy.example.com:8080')
      end
    end
  end
end
