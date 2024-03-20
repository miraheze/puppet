require 'spec_helper'

shared_examples 'zookeeper install' do |os_facts|
  # load class, handle custom params
  let :pre_condition do
    'class {"zookeeper":
       snap_retain_count => 1,
    }'
  end

  it { is_expected.to contain_package('zookeeper') }

  os_info = get_os_info(os_facts)

  should_install_cron = os_info[:should_install_cron]
  should_install_zookeeperd = os_info[:should_install_zookeeperd]
  zookeeper_shell = os_info[:zookeeper_shell]

  it { is_expected.to contain_class('zookeeper::post_install') }
  it { is_expected.to compile.with_all_deps }

  if should_install_zookeeperd
    it { is_expected.to contain_package('zookeeperd') }
  else
    it { is_expected.not_to contain_package('zookeeperd') }
  end

  if should_install_cron
    it { is_expected.to contain_package('cron') }
  else
    it { is_expected.not_to contain_package('cron') }
  end

  it 'installs cron script' do
    cron_exists = contain_cron__job('zookeeper-cleanup').with('ensure' => 'present',
                                                              'command'   => '/usr/share/zookeeper/bin/zkCleanup.sh /var/lib/zookeeper 1',
                                                              'user'      => 'zookeeper',
                                                              'hour'      => '2',
                                                              'minute' => '42')

    if should_install_cron
      is_expected.to cron_exists
    else
      is_expected.not_to cron_exists
    end
  end

  it 'installs cron script' do
    cron_exists = contain_cron__job('zookeeper-cleanup').with('ensure' => 'present',
                                                              'command'   => '/usr/share/zookeeper/bin/zkCleanup.sh /var/lib/zookeeper 1',
                                                              'user'      => 'zookeeper',
                                                              'hour'      => '2',
                                                              'minute' => '42')

    if should_install_cron
      is_expected.to cron_exists
    else
      is_expected.not_to cron_exists
    end
  end

  context 'without cron' do
    let :pre_condition do
      'class {"zookeeper":
         snap_retain_count => 0,
       }'
    end

    it { is_expected.to contain_package('zookeeper') }
    it { is_expected.not_to contain_package('cron') }

    if should_install_zookeeperd
      it { is_expected.to contain_package('zookeeperd') }
    else
      it { is_expected.not_to contain_package('zookeeperd') }
    end
  end

  context 'with cron' do
    let :pre_condition do
      'class {"zookeeper":
         snap_retain_count => 5,
         manual_clean      => true,
       }'
    end

    it { is_expected.to contain_package('zookeeper') }
    it { is_expected.to contain_package('cron') }

    it 'installs cron script' do
      is_expected.to contain_cron__job('zookeeper-cleanup').with('ensure' => 'present',
                                                                 'command'   => '/usr/share/zookeeper/bin/zkCleanup.sh /var/lib/zookeeper 5',
                                                                 'user'      => 'zookeeper',
                                                                 'hour'      => '2',
                                                                 'minute' => '42')
    end
  end

  context 'allow changing package names' do
    let :pre_condition do
      'class {"zookeeper":
         packages => [ "zookeeper", "zookeeper-server" ],
       }'
    end

    it { is_expected.to contain_package('zookeeper') }
    it { is_expected.to contain_package('zookeeper-server') }
    it { is_expected.not_to contain_package('zookeeperd') }
  end

  context 'allow installing multiple packages' do
    let :pre_condition do
      'class {"zookeeper":
         packages => [ "zookeeper", "zookeeper-devel" ],
       }'
    end

    it { is_expected.to contain_package('zookeeper') }
    it { is_expected.to contain_package('zookeeper-devel') }
  end

  context 'with java installation' do
    let(:user) { 'zookeeper' }
    let(:group) { 'zookeeper' }

    let :pre_condition do
      'class {"zookeeper":
         install_java => true,
         java_package => "java-1.7.0-openjdk",
       }'
    end

    it do
      is_expected.to contain_package('java-1.7.0-openjdk').with('ensure' => 'present')
    end
    it do
      is_expected.to contain_package('zookeeper').with('ensure' => 'present')
    end
  end

  context 'with java installation fail when no packge provided' do
    let :pre_condition do
      'class {"zookeeper":
         install_java => true,
       }'
    end

    it do
      expect {
        is_expected.to compile
      }.to raise_error(%r{Java installation is required})
    end
  end

  context 'removing package' do
    let :pre_condition do
      'class {"zookeeper":
         ensure => absent,
       }'
    end

    it do
      is_expected.to contain_package('zookeeper').with('ensure' => 'absent')
    end
    if should_install_zookeeperd
      it do
        is_expected.to contain_package('zookeeperd').with('ensure' => 'absent')
      end
    else
      it do
        is_expected.not_to contain_package('zookeeperd').with('ensure' => 'present')
      end
    end
    it { is_expected.not_to contain_package('cron') }
  end

  # create user with proper shell #50 (https://github.com/deric/puppet-zookeeper/issues/50)
  context 'ensure user resource exists' do
    it do
      is_expected.to contain_user('zookeeper').with('ensure' => 'present',
                                                    'shell' => zookeeper_shell)
    end
  end

  context 'user account' do
    let :pre_condition do
      'class {"zookeeper":
         ensure_account => "present",
       }'
    end

    it do
      is_expected.to contain_user('zookeeper').with(ensure: 'present')
    end

    context 'remove user accounts' do
      let :pre_condition do
        'class {"zookeeper":
          ensure_account => "absent",
        }'
      end

      it do
        is_expected.to contain_user('zookeeper').with(ensure: 'absent')
      end
    end

    context 'do not manage user accounts' do
      let :pre_condition do
        'class {"zookeeper":
          ensure_account => false,
        }'
      end

      it { is_expected.not_to contain_user('zookeeper') }
    end
  end

  context 'installing 3.4.8 from tar archive' do
    let(:install_dir) { '/opt' }
    let(:zoo_dir) { '/opt/zookeeper' }
    let(:vers) { '3.4.8' }
    let(:mirror_url) { 'http://archive.apache.org/dist' }
    let(:basefilename) { "zookeeper-#{vers}.tar.gz" }
    let(:package_url) { "#{mirror_url}/zookeeper/zookeeper-#{vers}/zookeeper-#{vers}.tar.gz" }
    let(:extract_path) { "#{zoo_dir}-#{vers}" }

    let :pre_condition do
      'class {"zookeeper":
         install_method => "archive",
         archive_version => "3.4.8",
         archive_install_dir => "/opt",
         zoo_dir => "/opt/zookeeper",
       }'
    end

    it do
      is_expected.to contain_file(zoo_dir).with(ensure: 'link',
                                                target: extract_path)
    end
    it do
      is_expected.to contain_archive("#{install_dir}/#{basefilename}").with(extract_path: install_dir,
                                                                            source: package_url,
                                                                            creates: extract_path,
                                                                            user: 'root',
                                                                            group: 'root')
    end

    it do
      is_expected.to contain_file('/etc/zookeeper').with(ensure: 'directory',
                                                         owner: 'zookeeper',
                                                         group: 'zookeeper')
    end
  end

  context 'installing 3.5.5 from tar archive' do
    let(:install_dir) { '/opt' }
    let(:zoo_dir) { '/opt/zookeeper' }
    let(:vers) { '3.5.5' }
    let(:mirror_url) { 'https://downloads.apache.org/zookeeper' }
    let(:basefilename) { "apache-zookeeper-#{vers}-bin.tar.gz" }
    let(:package_url) { "#{mirror_url}/zookeeper-#{vers}/apache-zookeeper-#{vers}-bin.tar.gz" }
    let(:extract_path) { "/opt/apache-zookeeper-#{vers}-bin" }

    let :pre_condition do
      'class {"zookeeper":
         install_method => "archive",
         archive_version => "3.5.5",
         archive_install_dir => "/opt",
         zoo_dir => "/opt/zookeeper",
       }'
    end

    it do
      is_expected.to contain_file(zoo_dir).with(ensure: 'link',
                                                target: extract_path)
    end

    it do
      is_expected.to contain_archive("#{install_dir}/#{basefilename}").with(extract_path: install_dir,
                                                                            source: package_url,
                                                                            creates: extract_path,
                                                                            user: 'root',
                                                                            group: 'root')
    end

    it do
      is_expected.to contain_file('/etc/zookeeper').with(ensure: 'directory',
                                                         owner: 'zookeeper',
                                                         group: 'zookeeper')
    end
  end

  context 'installing 3.4.8 from tar archive over proxy server' do
    let(:install_dir) { '/opt' }
    let(:zoo_dir) { '/opt/zookeeper' }
    let(:vers) { '3.4.8' }
    let(:mirror_url) { 'http://archive.apache.org/dist' }
    let(:basefilename) { "zookeeper-#{vers}.tar.gz" }
    let(:package_url) { "#{mirror_url}/zookeeper/zookeeper-#{vers}/zookeeper-#{vers}.tar.gz" }
    let(:extract_path) { "#{zoo_dir}-#{vers}" }

    let :pre_condition do
      'class {"zookeeper":
         install_method => "archive",
         proxy_server => "http://10.0.0.1:8080",
         archive_version => "3.4.8",
         archive_install_dir => "/opt",
         zoo_dir => "/opt/zookeeper",
       }'
    end

    it do
      is_expected.to contain_file(zoo_dir).with(ensure: 'link',
                                                target: extract_path)
    end
    it do
      is_expected.to contain_archive("#{install_dir}/#{basefilename}").with(extract_path:  install_dir,
                                                                            source:        package_url,
                                                                            creates:       extract_path,
                                                                            proxy_server:  'http://10.0.0.1:8080',
                                                                            user:          'root',
                                                                            group:         'root')
    end

    it do
      is_expected.to contain_file('/etc/zookeeper').with(ensure: 'directory',
                                                         owner: 'zookeeper',
                                                         group: 'zookeeper')
    end
  end
end

describe 'zookeeper::install' do
  let(:user) { 'zookeeper' }
  let(:group) { 'zookeeper' }

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) do
        os_facts
      end

      include_examples 'zookeeper install', os_facts
    end
  end
end
