require 'spec_helper'

describe 'zookeeper', type: :class do
  _, os_facts = on_supported_os.first

  os_facts[:os]['hardware'] = 'x86_64'
  os_facts[:ipaddress] = '192.168.1.1'

  let(:facts) { os_facts }
  let(:user) { 'zookeeper' }
  let(:group) { 'zookeeper' }

  os_info = get_os_info(os_facts)

  service_name = os_info[:service_name]
  environment_file = os_info[:environment_file]
  init_provider = os_info[:init_provider]
  should_install_zookeeperd = os_info[:should_install_zookeeperd]

  it { is_expected.to contain_class('zookeeper::config') }
  it { is_expected.to contain_class('zookeeper::install') }
  it { is_expected.to contain_class('zookeeper::service') }
  it { is_expected.to compile.with_all_deps }
  it { is_expected.to contain_service(service_name) }
  it { is_expected.to contain_service(service_name).that_subscribes_to('File[/etc/zookeeper/conf/myid]') }
  it { is_expected.to contain_service(service_name).that_subscribes_to('File[/etc/zookeeper/conf/zoo.cfg]') }
  it { is_expected.to contain_service(service_name).that_subscribes_to("File[#{environment_file}]") }
  it { is_expected.to contain_service(service_name).that_subscribes_to('File[/etc/zookeeper/conf/log4j.properties]') }

  context 'skip service restart' do
    let(:params) do
      {
        restart_on_change: false,
      }
    end

    it { is_expected.to contain_service(service_name) }
    it { is_expected.not_to contain_service(service_name).that_subscribes_to('File[/etc/zookeeper/conf/myid]') }
    it { is_expected.not_to contain_service(service_name).that_subscribes_to('File[/etc/zookeeper/conf/zoo.cfg]') }
    it { is_expected.not_to contain_service(service_name).that_subscribes_to("File[#{environment_file}]") }
    it { is_expected.not_to contain_service(service_name).that_subscribes_to('File[/etc/zookeeper/conf/log4j.properties]') }
  end

  context 'allow installing multiple packages' do
    let(:params) do
      {
        packages: ['zookeeper', 'zookeeper-bin'],
      }
    end

    it { is_expected.to compile.with_all_deps }
    it { is_expected.to contain_package('zookeeper').with(ensure: 'present') }
    it { is_expected.to contain_package('zookeeper-bin').with(ensure: 'present') }
    it { is_expected.to contain_service(service_name).with(ensure: 'running') }
    # datastore exec is not included by default
    it { is_expected.not_to contain_exec('initialize_datastore') }

    it { is_expected.to contain_user('zookeeper').with(ensure: 'present') }
    it { is_expected.to contain_group('zookeeper').with(ensure: 'present') }
  end

  context 'Cloudera packaging' do
    let(:params) do
      {
        packages: ['zookeeper', 'zookeeper-server'],
        service_name: 'zookeeper-server',
        initialize_datastore: true,
      }
    end

    it { is_expected.to contain_package('zookeeper').with(ensure: 'present') }
    it { is_expected.to contain_package('zookeeper-server').with(ensure: 'present') }
    it { is_expected.to contain_service('zookeeper-server').with(ensure: 'running') }
    it { is_expected.to contain_exec('initialize_datastore') }
  end

  context 'setting minSessionTimeout' do
    let(:params) do
      {
        min_session_timeout: 3000,
      }
    end

    it do
      is_expected.to contain_file(
        '/etc/zookeeper/conf/zoo.cfg',
      ).with_content(%r{minSessionTimeout=3000})
    end
  end

  context 'setting maxSessionTimeout' do
    let(:params) do
      {
        max_session_timeout: 60_000,
      }
    end

    it do
      is_expected.to contain_file(
        '/etc/zookeeper/conf/zoo.cfg',
      ).with_content(%r{maxSessionTimeout=60000})
    end
  end

  context 'disable service management' do
    let(:params) do
      {
        manage_service: false,
      }
    end

    it { is_expected.to contain_package('zookeeper').with(ensure: 'present') }
    it { is_expected.not_to contain_service(service_name).with(ensure: 'running') }
    it { is_expected.not_to contain_class('zookeeper::service') }
  end

  if %r{RedHat|Suse}.match?(os_facts[:os]['family'])
    context 'Do not use cloudera by default' do
      it { is_expected.to compile.with_all_deps }
      it { is_expected.to contain_class('zookeeper::install::repo') }
      it { is_expected.not_to contain_yumrepo('cloudera-cdh5') }
    end

    context 'custom RPM repo' do
      let(:params) do
        {
          repo: {
            'name'  => 'myrepo',
            'url'   => 'http://repo.url',
            'descr' => 'custom repo',
          },
          cdhver: '5',
        }
      end

      it { is_expected.to compile.with_all_deps }
      it { is_expected.to contain_class('zookeeper::install::repo') }

      it { is_expected.to contain_yumrepo('myrepo').with(baseurl: 'http://repo.url') }
    end
  end

  context 'service provider' do
    context 'autodetect provider' do
      it { is_expected.to contain_package('zookeeper').with(ensure: 'present') }

      if %r{RedHat|Suse}.match?(os_facts[:os]['family'])
        it { is_expected.to contain_package('zookeeper-server').with(ensure: 'present') }
      else
        it { is_expected.not_to contain_package('zookeeper-server').with(ensure: 'present') }
      end

      it do
        is_expected.to contain_service(service_name).with(ensure: 'running',
                                                          provider: init_provider)
      end
    end

    it { is_expected.to contain_class('zookeeper::service') }
  end

  context 'allow passing specific version' do
    let(:version) { '3.4.5+dfsg-1' }

    let(:params) do
      {
        ensure: version,
      }
    end

    it { is_expected.to contain_package('zookeeper').with(ensure: version) }

    if should_install_zookeeperd
      it { is_expected.to contain_package('zookeeperd').with(ensure: version) }
    else
      it { is_expected.not_to contain_package('zookeeperd').with(ensure: version) }
    end

    it { is_expected.to contain_user('zookeeper').with(ensure: 'present') }
  end

  context 'set pid file for init provider' do
    let(:params) do
      {
        zoo_dir: '/usr/lib/zookeeper',
        log_dir: '/var/log/zookeeper',
        manage_service: true,
        manage_service_file: true,
        service_provider: 'init',
      }
    end

    it do
      is_expected.to contain_file(
        '/etc/zookeeper/conf/log4j.properties',
      ).with_content(%r{zookeeper.log.dir=/var/log/zookeeper})
    end

    context 'set service provider' do
      it { is_expected.to contain_package('zookeeper').with(ensure: 'present') }
      it do
        is_expected.to contain_service(service_name).with(ensure: 'running',
                                                          provider: 'init')
      end
    end

    if %r{RedHat|Suse}.match?(os_facts[:os]['family'])
      it do
        is_expected.to contain_file(
          "/etc/init.d/#{service_name}",
        ).with_content(%r{pidfile=/var/run/zookeeper.pid})
      end
    else
      it do
        is_expected.to contain_file(
          environment_file,
        ).with_content(%r{PIDFILE=/var/run/zookeeper.pid})
      end
    end
  end

  context 'create env file' do
    it do
      is_expected.to contain_file(
        environment_file,
      )
    end
  end

  context 'managed by exhibitor' do
    let(:params) do
      {
        service_provider: 'exhibitor',
        service_name: 'zookeeper',
        cfg_dir: '/opt/zookeeper/conf',
      }
    end

    it { is_expected.not_to contain_class('zookeeper::service') }
    it { is_expected.not_to contain_service(service_name) }
    it { is_expected.not_to contain_file('/opt/zookeeper/conf/zoo.cfg') }
    it { is_expected.not_to contain_file('/opt/zookeeper/conf/myid') }
  end

  context 'install from archive' do
    let(:params) do
      {
        install_method: 'archive',
        archive_version: '3.4.9',
      }
    end

    it { is_expected.to compile.with_all_deps }
    it { is_expected.to contain_class('Zookeeper::Install::Archive') }

    it { is_expected.not_to contain_package('zookeeper').with(ensure: 'present') }
    it { is_expected.to contain_service(service_name).with(ensure: 'running') }

    it { is_expected.to contain_user('zookeeper').with(ensure: 'present') }
    it { is_expected.to contain_group('zookeeper').with(ensure: 'present') }
  end

  context 'configure secure port only' do
    let(:params) do
      {
        ssl: true,
        client_port: 2181,
        secure_client_port: 2182,
        secure_port_only: true,
      }
    end

    it { is_expected.to compile.with_all_deps }
    it { is_expected.not_to contain_file('/etc/zookeeper/conf/zoo.cfg').with_content(%r{^clientPort=2181}) }
    it { is_expected.to contain_file('/etc/zookeeper/conf/zoo.cfg').with_content(%r{^secureClientPort=2182}) }
  end
end
