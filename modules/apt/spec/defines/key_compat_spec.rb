# frozen_string_literal: true

require 'spec_helper'

def contains_apt_key_example(title)
  { id: title,
    ensure: 'present',
    source: 'http://apt.puppetlabs.com/pubkey.gpg',
    server: 'pgp.mit.edu',
    content: params[:content],
    options: 'debug' }
end

def apt_key_example(title)
  { id: title,
    ensure: 'present',
    source: nil,
    server: 'keyserver.ubuntu.com',
    content: nil,
    keyserver_options: nil }
end

describe 'apt::key', type: :define do
  GPG_KEY_ID = '6F6B15509CF8E59E6E469F327F438280EF8D349F'

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

  let :pre_condition do
    'include apt'
  end

  describe 'normal operation' do
    describe 'default options' do
      it {
        is_expected.to contain_apt_key(title).with(id: title,
                                                   ensure: 'present',
                                                   source: nil,
                                                   server: 'keyserver.ubuntu.com',
                                                   content: nil)
      }
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
        is_expected.to contain_apt_key(title).with(id: GPG_KEY_ID,
                                                   ensure: 'present',
                                                   source: nil,
                                                   server: 'keyserver.ubuntu.com',
                                                   content: nil)
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
        is_expected.to contain_apt_key(title).with(id: title,
                                                   ensure: 'absent',
                                                   source: nil,
                                                   server: 'keyserver.ubuntu.com',
                                                   content: nil)
      end
      it 'contains the apt_key absent anchor' do
        is_expected.to contain_anchor("apt_key #{title} absent")
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
        is_expected.to contain_apt_key(title).with(contains_apt_key_example(title))
      end
      it 'contains the apt_key present anchor' do
        is_expected.to contain_anchor("apt_key #{title} present")
      end
    end

    context 'when domain has dash' do
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
    context 'with url and port number' do
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
    context 'when domain begins with a dash' do
      let(:params) do
        {
          server: '-pgp.mit.edu',
        }
      end

      it 'fails' do
        is_expected .to raise_error(%r{expects a match})
      end
    end

    context 'when domain begins with dot' do
      let(:params) do
        {
          server: '.pgp.mit.edu',
        }
      end

      it 'fails' do
        is_expected .to raise_error(%r{expects a match})
      end
    end

    context 'when domain ends with dot' do
      let(:params) do
        {
          server: 'pgp.mit.edu.',
        }
      end

      it 'fails' do
        is_expected .to raise_error(%r{expects a match})
      end
    end
    context 'when url character limit is exceeded' do
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
    context 'with incorrect protocol for  url' do
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
    context 'with url begin with a dash' do
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

    context 'with invalid keyserver_options' do
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
      let :params do
        {
          ensure: 'foo',
        }
      end

      it 'fails' do
        is_expected.to raise_error(%r{Enum\['absent', 'present', 'refreshed'\]})
      end
    end

    describe 'duplication - two apt::key resources for same key, different titles' do
      let :pre_condition do
        "#{super()}\napt::key { 'duplicate': id => '#{title}', }"
      end

      it 'contains the duplicate apt::key resource' do
        is_expected.to contain_apt__key('duplicate').with(id: title,
                                                          ensure: 'present')
      end

      it 'contains the original apt::key resource' do
        is_expected.to contain_apt__key(title).with(id: title,
                                                    ensure: 'present')
      end

      it 'contains the native apt_key' do
        is_expected.to contain_apt_key('duplicate').with(apt_key_example(title))
      end

      it 'does not contain the original apt_key' do
        is_expected.not_to contain_apt_key(title)
      end
    end

    describe 'duplication - two apt::key resources, different ensure' do
      let :pre_condition do
        "#{super()}\napt::key { 'duplicate': id => '#{title}', ensure => 'absent', }"
      end

      it 'informs the user of the impossibility' do
        is_expected.to raise_error(%r{already ensured as absent})
      end
    end
  end
end
