# frozen_string_literal: true

require 'spec_helper'
describe 'apt::ppa' do
  let :pre_condition do
    'class { "apt": }'
  end

  describe 'defaults' do
    let :facts do
      {
        os: {
          family: 'Debian',
          name: 'Ubuntu',
          release: {
            major: '14',
            full: '14.04',
          },
          distro: {
            codename: 'trusty',
            id: 'Ubuntu',
          },
        },
      }
    end

    let(:title) { 'ppa:needs/such.substitution/wow+type' }

    it { is_expected.not_to contain_package('python-software-properties') }
    it {
      is_expected.to contain_exec('add-apt-repository-ppa:needs/such.substitution/wow+type').that_notifies('Class[Apt::Update]').with(environment: [],
                                                                                                                                      command: '/usr/bin/add-apt-repository -y ppa:needs/such.substitution/wow+type || (rm /etc/apt/sources.list.d/needs-such_substitution-wow_type-trusty.list && false)', # rubocop:disable Layout/LineLength
                                                                                                                                      unless: '/usr/bin/test -f /etc/apt/sources.list.d/needs-such_substitution-wow_type-trusty.list && /usr/bin/test -f /etc/apt/trusted.gpg.d/needs-such_substitution-wow_type.gpg', # rubocop:disable Layout/LineLength
                                                                                                                                      user: 'root',
                                                                                                                                      logoutput: 'on_failure')
    }
  end

  describe 'Ubuntu 15.10 sources.list filename' do
    let :facts do
      {
        os: {
          family: 'Debian',
          name: 'Ubuntu',
          release: {
            major: '15',
            full: '15.10',
          },
          distro: {
            codename: 'wily',
            id: 'Ubuntu',
          },
        },
      }
    end

    let(:title) { 'ppa:user/foo' }

    it {
      is_expected.to contain_exec('add-apt-repository-ppa:user/foo').that_notifies('Class[Apt::Update]').with(environment: [],
                                                                                                              command: '/usr/bin/add-apt-repository -y ppa:user/foo || (rm /etc/apt/sources.list.d/user-ubuntu-foo-wily.list && false)', # rubocop:disable Layout/LineLength
                                                                                                              unless: '/usr/bin/test -f /etc/apt/sources.list.d/user-ubuntu-foo-wily.list && /usr/bin/test -f /etc/apt/trusted.gpg.d/user_ubuntu_foo.gpg', # rubocop:disable Layout/LineLength
                                                                                                              user: 'root',
                                                                                                              logoutput: 'on_failure')
    }
  end

  describe 'package_name => software-properties-common' do
    let :pre_condition do
      'class { "apt": }'
    end
    let :params do
      {
        package_name: 'software-properties-common',
        package_manage: true,
      }
    end
    let :facts do
      {
        os: {
          family: 'Debian',
          name: 'Ubuntu',
          release: {
            major: '14',
            full: '14.04',
          },
          distro: {
            codename: 'trusty',
            id: 'Ubuntu',
          },
        },
      }
    end

    let(:title) { 'ppa:needs/such.substitution/wow' }

    it { is_expected.to contain_package('software-properties-common') }
    it {
      is_expected.to contain_exec('add-apt-repository-ppa:needs/such.substitution/wow').that_notifies('Class[Apt::Update]').with('environment' => [],
                                                                                                                                 'command'     => '/usr/bin/add-apt-repository -y ppa:needs/such.substitution/wow || (rm /etc/apt/sources.list.d/needs-such_substitution-wow-trusty.list && false)', # rubocop:disable Layout/LineLength
                                                                                                                                 'unless'      => '/usr/bin/test -f /etc/apt/sources.list.d/needs-such_substitution-wow-trusty.list && /usr/bin/test -f /etc/apt/trusted.gpg.d/needs-such_substitution-wow.gpg', # rubocop:disable Layout/LineLength
                                                                                                                                 'user'        => 'root',
                                                                                                                                 'logoutput'   => 'on_failure')
    }

    it {
      is_expected.to contain_file('/etc/apt/sources.list.d/needs-such_substitution-wow-trusty.list').that_requires('Exec[add-apt-repository-ppa:needs/such.substitution/wow]').with('ensure' => 'file')
    }
  end

  describe 'package_manage => false' do
    let :pre_condition do
      'class { "apt": }'
    end
    let :facts do
      {
        os: {
          family: 'Debian',
          name: 'Ubuntu',
          release: {
            major: '14',
            full: '14.04',
          },
          distro: {
            codename: 'trusty',
            id: 'Ubuntu',
          },
        },
      }
    end
    let :params do
      {
        package_manage: false,
      }
    end

    let(:title) { 'ppa:needs/such.substitution/wow' }

    it { is_expected.not_to contain_package('python-software-properties') }
    it {
      is_expected.to contain_exec('add-apt-repository-ppa:needs/such.substitution/wow').that_notifies('Class[Apt::Update]').with('environment' => [],
                                                                                                                                 'command'     => '/usr/bin/add-apt-repository -y ppa:needs/such.substitution/wow || (rm /etc/apt/sources.list.d/needs-such_substitution-wow-trusty.list && false)', # rubocop:disable Layout/LineLength
                                                                                                                                 'unless'      => '/usr/bin/test -f /etc/apt/sources.list.d/needs-such_substitution-wow-trusty.list && /usr/bin/test -f /etc/apt/trusted.gpg.d/needs-such_substitution-wow.gpg', # rubocop:disable Layout/LineLength
                                                                                                                                 'user'        => 'root',
                                                                                                                                 'logoutput'   => 'on_failure')
    }

    it {
      is_expected.to contain_file('/etc/apt/sources.list.d/needs-such_substitution-wow-trusty.list').that_requires('Exec[add-apt-repository-ppa:needs/such.substitution/wow]').with('ensure' => 'file')
    }
  end

  describe 'apt included, no proxy' do
    let :pre_condition do
      'class { "apt": }
      apt::ppa { "ppa:user/foo2": }
      '
    end
    let :facts do
      {
        os: {
          family: 'Debian',
          name: 'Ubuntu',
          release: {
            major: '14',
            full: '14.04',
          },
          distro: {
            codename: 'trusty',
            id: 'Ubuntu',
          },
        },
      }
    end
    let :params do
      {
        options: '',
        package_manage: true,
        require: 'Apt::Ppa[ppa:user/foo2]',
      }
    end
    let(:title) { 'ppa:user/foo' }

    it { is_expected.to compile.with_all_deps }
    it { is_expected.to contain_package('software-properties-common') }
    it {
      is_expected.to contain_exec('add-apt-repository-ppa:user/foo').that_notifies('Class[Apt::Update]').with(environment: [],
                                                                                                              command: '/usr/bin/add-apt-repository  ppa:user/foo || (rm /etc/apt/sources.list.d/user-foo-trusty.list && false)', # rubocop:disable Layout/LineLength
                                                                                                              unless: '/usr/bin/test -f /etc/apt/sources.list.d/user-foo-trusty.list && /usr/bin/test -f /etc/apt/trusted.gpg.d/user-foo.gpg', # rubocop:disable Layout/LineLength
                                                                                                              user: 'root',
                                                                                                              logoutput: 'on_failure')
    }
  end

  describe 'apt included, proxy host' do
    let :pre_condition do
      'class { "apt":
        proxy => { "host" => "localhost" },
      }'
    end
    let :facts do
      {
        os: {
          family: 'Debian',
          name: 'Ubuntu',
          release: {
            major: '14',
            full: '14.04',
          },
          distro: {
            codename: 'trusty',
            id: 'Ubuntu',
          },
        },
      }
    end
    let :params do
      {
        'options' => '',
        'package_manage' => true,
      }
    end
    let(:title) { 'ppa:user/foo' }

    it { is_expected.to contain_package('software-properties-common') }
    it {
      is_expected.to contain_exec('add-apt-repository-ppa:user/foo').that_notifies('Class[Apt::Update]').with(environment: ['http_proxy=http://localhost:8080'],
                                                                                                              command: '/usr/bin/add-apt-repository  ppa:user/foo || (rm /etc/apt/sources.list.d/user-foo-trusty.list && false)', # rubocop:disable Layout/LineLength
                                                                                                              unless: '/usr/bin/test -f /etc/apt/sources.list.d/user-foo-trusty.list && /usr/bin/test -f /etc/apt/trusted.gpg.d/user-foo.gpg', # rubocop:disable Layout/LineLength
                                                                                                              user: 'root',
                                                                                                              logoutput: 'on_failure')
    }
  end

  describe 'apt included, proxy host and port' do
    let :pre_condition do
      'class { "apt":
        proxy => { "host" => "localhost", "port" => 8180 },
      }'
    end
    let :facts do
      {
        os: {
          family: 'Debian',
          name: 'Ubuntu',
          release: {
            major: '14',
            full: '14.04',
          },
          distro: {
            codename: 'trusty',
            id: 'Ubuntu',
          },
        },
      }
    end
    let :params do
      {
        options: '',
        package_manage: true,
      }
    end
    let(:title) { 'ppa:user/foo' }

    it { is_expected.to contain_package('software-properties-common') }
    it {
      is_expected.to contain_exec('add-apt-repository-ppa:user/foo').that_notifies('Class[Apt::Update]').with(environment: ['http_proxy=http://localhost:8180'],
                                                                                                              command: '/usr/bin/add-apt-repository  ppa:user/foo || (rm /etc/apt/sources.list.d/user-foo-trusty.list && false)', # rubocop:disable Layout/LineLength
                                                                                                              unless: '/usr/bin/test -f /etc/apt/sources.list.d/user-foo-trusty.list && /usr/bin/test -f /etc/apt/trusted.gpg.d/user-foo.gpg', # rubocop:disable Layout/LineLength
                                                                                                              user: 'root',
                                                                                                              logoutput: 'on_failure')
    }
  end

  describe 'apt included, proxy host and port and https' do
    let :pre_condition do
      'class { "apt":
        proxy => { "host" => "localhost", "port" => 8180, "https" => true },
      }'
    end
    let :facts do
      {
        os: {
          family: 'Debian',
          name: 'Ubuntu',
          release: {
            major: '14',
            full: '14.04',
          },
          distro: {
            codename: 'trusty',
            id: 'Ubuntu',
          },
        },
      }
    end
    let :params do
      {
        options: '',
        package_manage: true,
      }
    end
    let(:title) { 'ppa:user/foo' }

    it { is_expected.to contain_package('software-properties-common') }
    it {
      is_expected.to contain_exec('add-apt-repository-ppa:user/foo').that_notifies('Class[Apt::Update]').with(environment: ['http_proxy=http://localhost:8180', 'https_proxy=https://localhost:8180'],
                                                                                                              command: '/usr/bin/add-apt-repository  ppa:user/foo || (rm /etc/apt/sources.list.d/user-foo-trusty.list && false)', # rubocop:disable Layout/LineLength
                                                                                                              unless: '/usr/bin/test -f /etc/apt/sources.list.d/user-foo-trusty.list && /usr/bin/test -f /etc/apt/trusted.gpg.d/user-foo.gpg', # rubocop:disable Layout/LineLength
                                                                                                              user: 'root',
                                                                                                              logoutput: 'on_failure')
    }
  end

  describe 'ensure absent' do
    let :pre_condition do
      'class { "apt": }'
    end
    let :facts do
      {
        os: {
          family: 'Debian',
          name: 'Ubuntu',
          release: {
            major: '14',
            full: '14.04',
          },
          distro: {
            codename: 'trusty',
            id: 'Ubuntu',
          },
        },
      }
    end
    let(:title) { 'ppa:user/foo' }
    let :params do
      {
        ensure: 'absent',
      }
    end

    it {
      is_expected.to contain_file('/etc/apt/sources.list.d/user-foo-trusty.list').that_notifies('Class[Apt::Update]').with(ensure: 'absent')
    }
  end

  context 'with validation' do
    describe 'no release' do
      let :facts do
        {
          os: {
            family: 'Debian',
            name: 'Ubuntu',
            release: {
              major: '14',
              full: '14.04',
            },
            distro: {
              codename: nil,
              id: 'Ubuntu',
            },
          },
        }
      end
      let(:title) { 'ppa:user/foo' }

      it do
        is_expected.to raise_error(Puppet::Error, %r{os.distro.codename fact not available: release parameter required})
      end
    end

    describe 'not ubuntu' do
      let :facts do
        {
          os: {
            family: 'Debian',
            name: 'Debian',
            release: {
              major: '6',
              full: '6.0.7',
            },
            distro: {
              codename: 'wheezy',
              id: 'Debian',
            },
          },
        }
      end
      let(:title) { 'ppa:user/foo' }

      it do
        is_expected.to raise_error(Puppet::Error, %r{not currently supported on Debian})
      end
    end
  end
end
