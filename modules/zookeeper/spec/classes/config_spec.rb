require 'spec_helper'

shared_examples 'zookeeper parameters' do |_os_facts, precond|
  # load class, handle custom params
  let :pre_condition do
    precond
  end

  it do
    is_expected.to contain_file(cfg_dir).with('ensure'  => 'directory',
                                              'owner'   => user,
                                              'group'   => group)
  end

  it do
    is_expected.to contain_file(log_dir).with('ensure'  => 'directory',
                                              'owner'   => user,
                                              'group'   => group)
  end

  it do
    is_expected.to contain_file(id_file).with('ensure'  => 'file',
                                              'owner'   => user,
                                              'group'   => group).with_content(myid)
  end
end

shared_examples 'zookeeper common' do |os_facts|
  os_info = get_os_info(os_facts)

  environment_file = os_info[:environment_file]

  context 'extra parameters' do
    # set custom params
    let :pre_condition do
      'class {"zookeeper":
         log4j_prop => "ERROR",
         snap_count => 15000,
         pre_alloc_size => 131072,
       }'
    end

    it do
      is_expected.to contain_file(environment_file).with_content(%r{ERROR})
      is_expected.to contain_file(environment_file).with_content(%r{ZOOCFG})
      # CLASSPATH won't be overriden for all install methods
      # is_expected.to contain_file(environment_file).with_content(%r{CLASSPATH})
    end

    it do
      is_expected.to contain_file('/etc/zookeeper/conf/zoo.cfg').with_content(%r{snapCount=15000})
    end

    it do
      is_expected.to contain_file('/etc/zookeeper/conf/zoo.cfg').with_content(%r{preAllocSize=131072})
    end

    # leave the default value to be determined by ZooKeeper
    it 'does not set maxClientCnxns by default' do
      # due to problem with should_not not matching, we're using more complicated way
      is_expected.to contain_file(
        '/etc/zookeeper/conf/zoo.cfg',
      ).with_content(%r{^#maxClientCnxns=})
    end

    # by default do not set client IP address
    it do
      is_expected.to contain_file(
        '/etc/zookeeper/conf/zoo.cfg',
      ).with_content(%r{^#clientPortAddress=})
    end
  end

  context 'extra environment_file parameter' do
    # set custom params
    let :pre_condition do
      'class {"zookeeper":
         log4j_prop => "ERROR",
         environment_file => "java.env",
       }'
    end

    it do
      is_expected.to contain_file('/etc/zookeeper/conf/java.env').with_content(%r{ERROR})
      is_expected.not_to contain_file('/etc/zookeeper/environment')
    end
  end

  context 'max allowed connections' do
    let :pre_condition do
      'class {"zookeeper":
         max_allowed_connections => 15,
       }'
    end

    it do
      is_expected.to contain_file(
        '/etc/zookeeper/conf/zoo.cfg',
      ).with_content(%r{maxClientCnxns=15})
    end
  end

  context 'set client ip address' do
    let :pre_condition do
      'class {"zookeeper":
         client_ip => "192.168.1.1",
       }'
    end

    it do
      is_expected.to contain_file(
        '/etc/zookeeper/conf/zoo.cfg',
      ).with_content(%r{clientPortAddress=192.168.1.1})
    end
  end

  context 'setting tick time' do
    let :pre_condition do
      'class {"zookeeper":
         tick_time => 3000,
       }'
    end

    it do
      is_expected.to contain_file('/etc/zookeeper/conf/zoo.cfg').with_content(%r{tickTime=3000})
    end
  end

  context 'setting init and sync limit' do
    let :pre_condition do
      'class {"zookeeper":
         init_limit => 15,
         sync_limit => 10,
       }'
    end

    it do
      is_expected.to contain_file('/etc/zookeeper/conf/zoo.cfg').with_content(%r{initLimit=15})
    end

    it do
      is_expected.to contain_file('/etc/zookeeper/conf/zoo.cfg').with_content(%r{syncLimit=10})
    end
  end

  context 'setting leader' do
    let :pre_condition do
      'class {"zookeeper":
         leader => false,
       }'
    end

    it do
      is_expected.to contain_file('/etc/zookeeper/conf/zoo.cfg').with_content(%r{leaderServes=no})
    end
  end

  context 'myid link' do
    let :pre_condition do
      'class {"zookeeper":}'
    end

    it do
      is_expected.to contain_file(
        '/var/lib/zookeeper/myid',
      ).with('ensure' => 'link',
             'target' => '/etc/zookeeper/conf/myid')
    end
  end

  context 'without datalogstore parameter' do
    let :pre_condition do
      'class {"zookeeper":}'
    end

    it do
      is_expected.to contain_file(
        '/etc/zookeeper/conf/zoo.cfg',
      ).with_content(%r{# dataLogDir=/disk2/zookeeper})
    end
  end

  context 'with datalogstore parameter' do
    let :pre_condition do
      'class {"zookeeper":
         datalogstore => "/zookeeper/transaction/device",
       }'
    end

    let(:datalogstore) { '/zookeeper/transaction/device' }

    it do
      is_expected.to contain_file(datalogstore).with('ensure' => 'directory')
    end

    it do
      is_expected.to contain_file(
        '/etc/zookeeper/conf/zoo.cfg',
      ).with_content(%r{dataLogDir=/zookeeper/transaction/device})
    end
  end

  context 'setting quorum of servers with custom ports' do
    let :pre_condition do
      'class {"zookeeper":
         election_port => 3000,
         leader_port   => 4000,
         servers       => ["192.168.1.1", "192.168.1.2"],
       }'
    end

    it do
      is_expected.to contain_file(
        '/etc/zookeeper/conf/zoo.cfg',
      ).with_content(%r{server.1=192.168.1.1:3000:4000})
    end

    it do
      is_expected.to contain_file(
        '/etc/zookeeper/conf/zoo.cfg',
      ).with_content(%r{server.2=192.168.1.2:3000:4000})
    end
  end

  context 'setting quorum of servers with custom ports with servers as hash' do
    let :pre_condition do
      'class {"zookeeper":
         election_port => 3000,
         leader_port   => 4000,
         servers       => {"12" => "192.168.1.1", "23" => "192.168.1.2"},
       }'
    end

    it do
      is_expected.to contain_file(
        '/etc/zookeeper/conf/zoo.cfg',
      ).with_content(%r{server.12=192.168.1.1:3000:4000})
    end

    it do
      is_expected.to contain_file(
        '/etc/zookeeper/conf/zoo.cfg',
      ).with_content(%r{server.23=192.168.1.2:3000:4000})
    end
  end

  context 'setting quorum of servers with default ports' do
    let :pre_condition do
      'class {"zookeeper":
         servers => ["192.168.1.1", "192.168.1.2"]
       }'
    end

    it do
      is_expected.to contain_file(
        '/etc/zookeeper/conf/zoo.cfg',
      ).with_content(%r{server.1=192.168.1.1:2888:3888})
    end

    it do
      is_expected.to contain_file(
        '/etc/zookeeper/conf/zoo.cfg',
      ).with_content(%r{server.2=192.168.1.2:2888:3888})
    end
  end

  context 'setting quorum of servers with default ports with servers as hash' do
    let :pre_condition do
      'class {"zookeeper":
         servers => {"12" => "192.168.1.1", "23" => "192.168.1.2"},
       }'
    end

    it do
      is_expected.to contain_file(
        '/etc/zookeeper/conf/zoo.cfg',
      ).with_content(%r{server.12=192.168.1.1:2888:3888})
    end

    it do
      is_expected.to contain_file(
        '/etc/zookeeper/conf/zoo.cfg',
      ).with_content(%r{server.23=192.168.1.2:2888:3888})
    end
  end

  context 'setting quorum of servers with default ports with observer' do
    let :pre_condition do
      'class {"zookeeper":
         servers   => ["192.168.1.1", "192.168.1.2", "192.168.1.3", "192.168.1.4", "192.168.1.5"],
         observers => ["192.168.1.4", "192.168.1.5"]
       }'
    end

    it do
      is_expected.to contain_file(
        '/etc/zookeeper/conf/zoo.cfg',
      ).with_content(%r{server.1=192.168.1.1:2888:3888})
    end

    it do
      is_expected.not_to contain_file(
        '/etc/zookeeper/conf/zoo.cfg',
      ).with_content(%r{server.1=192.168.1.1:2888:3888:observer})
    end

    it do
      is_expected.to contain_file(
        '/etc/zookeeper/conf/zoo.cfg',
      ).with_content(%r{server.2=192.168.1.2:2888:3888})
    end

    it do
      is_expected.not_to contain_file(
        '/etc/zookeeper/conf/zoo.cfg',
      ).with_content(%r{server.2=192.168.1.2:2888:3888:observer})
    end

    it do
      is_expected.to contain_file(
        '/etc/zookeeper/conf/zoo.cfg',
      ).with_content(%r{server.3=192.168.1.3:2888:3888})
    end

    it do
      is_expected.not_to contain_file(
        '/etc/zookeeper/conf/zoo.cfg',
      ).with_content(%r{server.3=192.168.1.3:2888:3888:observer})
    end

    it do
      is_expected.to contain_file(
        '/etc/zookeeper/conf/zoo.cfg',
      ).with_content(%r{server.4=192.168.1.4:2888:3888:observer})
    end

    it do
      is_expected.to contain_file(
        '/etc/zookeeper/conf/zoo.cfg',
      ).with_content(%r{server.5=192.168.1.5:2888:3888:observer})
    end
  end

  context 'setting quorum of servers with default ports with observer with servers as hash' do
    let :pre_condition do
      'class {"zookeeper":
         servers   => {"12" => "192.168.1.1",
                       "23" => "192.168.1.2",
                       "34" => "192.168.1.3",
                       "45" => "192.168.1.4",
                       "56" => "192.168.1.5"},
         observers => ["192.168.1.4", "192.168.1.5"]
       }'
    end

    it do
      is_expected.to contain_file(
        '/etc/zookeeper/conf/zoo.cfg',
      ).with_content(%r{server.12=192.168.1.1:2888:3888})
    end

    it do
      is_expected.not_to contain_file(
        '/etc/zookeeper/conf/zoo.cfg',
      ).with_content(%r{server.12=192.168.1.1:2888:3888:observer})
    end

    it do
      is_expected.to contain_file(
        '/etc/zookeeper/conf/zoo.cfg',
      ).with_content(%r{server.23=192.168.1.2:2888:3888})
    end

    it do
      is_expected.not_to contain_file(
        '/etc/zookeeper/conf/zoo.cfg',
      ).with_content(%r{server.23=192.168.1.2:2888:3888:observer})
    end

    it do
      is_expected.to contain_file(
        '/etc/zookeeper/conf/zoo.cfg',
      ).with_content(%r{server.34=192.168.1.3:2888:3888})
    end

    it do
      is_expected.not_to contain_file(
        '/etc/zookeeper/conf/zoo.cfg',
      ).with_content(%r{server.34=192.168.1.3:2888:3888:observer})
    end

    it do
      is_expected.to contain_file(
        '/etc/zookeeper/conf/zoo.cfg',
      ).with_content(%r{server.45=192.168.1.4:2888:3888:observer})
    end

    it do
      is_expected.to contain_file(
        '/etc/zookeeper/conf/zoo.cfg',
      ).with_content(%r{server.56=192.168.1.5:2888:3888:observer})
    end
  end

  context 'setting minSessionTimeout' do
    let :pre_condition do
      'class {"zookeeper":
         min_session_timeout => 5000
       }'
    end

    it do
      is_expected.to contain_file(
        '/etc/zookeeper/conf/zoo.cfg',
      ).with_content(%r{minSessionTimeout=5000})
    end
  end

  context 'setting maxSessionTimeout' do
    let :pre_condition do
      'class {"zookeeper":
         max_session_timeout => 50000
       }'
    end

    it do
      is_expected.to contain_file(
        '/etc/zookeeper/conf/zoo.cfg',
      ).with_content(%r{maxSessionTimeout=50000})
    end
  end

  context 'make sure port is not included in server IP/hostname' do
    let :pre_condition do
      'class {"zookeeper":
         servers => ["192.168.1.1:2888", "192.168.1.2:2333"]
       }'
    end

    it do
      is_expected.to contain_file(
        '/etc/zookeeper/conf/zoo.cfg',
      ).with_content(%r{server.1=192.168.1.1:2888:3888})
    end

    it do
      is_expected.to contain_file(
        '/etc/zookeeper/conf/zoo.cfg',
      ).with_content(%r{server.2=192.168.1.2:2888:3888})
    end
  end

  context 'configure logging' do
    context 'by default set to INFO' do
      let :pre_condition do
        'class {"zookeeper": }'
      end

      it do
        is_expected.to contain_file(
          '/etc/zookeeper/conf/log4j.properties',
        ).with_content(%r{zookeeper.log.threshold=INFO})
      end

      it do
        is_expected.to contain_file(
          '/etc/zookeeper/conf/log4j.properties',
        ).with_content(%r{zookeeper.console.threshold=INFO})
      end
    end

    context 'allow changing rollingfile loglevel' do
      let :pre_condition do
        'class {"zookeeper":
           rollingfile_threshold => "TRACE",
         }'
      end

      it do
        is_expected.to contain_file(
          '/etc/zookeeper/conf/log4j.properties',
        ).with_content(%r{zookeeper.log.threshold=TRACE})
      end
    end

    context 'allow changing console loglevel' do
      let :pre_condition do
        'class {"zookeeper":
           console_threshold => "TRACE",
         }'
      end

      it do
        is_expected.to contain_file(
          '/etc/zookeeper/conf/log4j.properties',
        ).with_content(%r{zookeeper.console.threshold=TRACE})
      end
    end

    context 'allow changing tracefile loglevel' do
      let :pre_condition do
        'class {"zookeeper":
           tracefile_threshold => "DEBUG",
         }'
      end

      it do
        is_expected.to contain_file(
          '/etc/zookeeper/conf/log4j.properties',
        ).with_content(%r{log4j.appender.TRACEFILE.Threshold=DEBUG})
      end
    end

    context 'setting 4lw whitelist' do
      let :pre_condition do
        'class {"zookeeper":
           whitelist_4lw => ["ruok","stat"]
         }'
      end

      it do
        is_expected.to contain_file(
          '/etc/zookeeper/conf/zoo.cfg',
        ).with_content(%r{4lw.commands.whitelist=ruok,stat})
      end
    end

    context 'setting metrics provider' do
      let :pre_condition do
        'class {"zookeeper":
          metrics_provider_classname => "org.apache.zookeeper.metrics.prometheus.PrometheusMetricsProvider",
          metrics_provider_http_port => 7007,
         }'
      end

      it do
        is_expected.to contain_file(
          '/etc/zookeeper/conf/zoo.cfg',
        ).with_content(%r{^metricsProvider.className=org.apache.zookeeper.metrics.prometheus.PrometheusMetricsProvider})
      end

      it do
        is_expected.to contain_file(
          '/etc/zookeeper/conf/zoo.cfg',
        ).with_content(%r{^metricsProvider.httpPort=7007})
      end
    end

    context 'set global outstanding limit' do
      let :pre_condition do
        'class {"zookeeper":
           global_outstanding_limit => 2000
         }'
      end

      it do
        is_expected.to contain_file(
          '/etc/zookeeper/conf/zoo.cfg',
        ).with_content(%r{globalOutstandingLimit=2000})
      end
    end

    context 'set portUnification' do
      let :pre_condition do
        'class {"zookeeper":
           port_unification => true
         }'
      end

      it do
        is_expected.to contain_file(
          '/etc/zookeeper/conf/zoo.cfg',
        ).with_content(%r{portUnification=true})
      end
    end

    context 'default does not set portUnification' do
      let :pre_condition do
        'class {"zookeeper":}'
      end

      it do
        is_expected.not_to contain_file(
          '/etc/zookeeper/conf/zoo.cfg',
        ).with_content(%r{portUnification})
      end
    end
  end
  context 'setting metrics provider' do
    let :pre_condition do
      'class {"zookeeper":
        metrics_provider_classname => "org.apache.zookeeper.metrics.prometheus.PrometheusMetricsProvider",
        metrics_provider_http_port => 7007,
        metrics_provider_export_jvm_info => false,
       }'
    end

    it do
      is_expected.to contain_file(
        '/etc/zookeeper/conf/zoo.cfg',
      ).with_content(%r{metricsProvider.className=org.apache.zookeeper.metrics.prometheus.PrometheusMetricsProvider})
    end

    it do
      is_expected.to contain_file(
        '/etc/zookeeper/conf/zoo.cfg',
      ).with_content(%r{metricsProvider.httpPort=7007})
    end
    it do
      is_expected.to contain_file(
        '/etc/zookeeper/conf/zoo.cfg',
      ).with_content(%r{metricsProvider.exportJvmInfo=false})
    end
  end
end

describe 'zookeeper::config' do
  _, os_facts = on_supported_os.first

  os_facts[:os]['hardware'] = 'x86_64'
  os_facts[:ipaddress] = '192.168.1.1'
  let(:facts) { os_facts }

  context 'with default parameters' do
    let(:user)    { 'zookeeper' }
    let(:group)   { 'zookeeper' }
    let(:cfg_dir) { '/etc/zookeeper/conf' }
    let(:log_dir) { '/var/lib/zookeeper' }
    let(:id_file) { '/etc/zookeeper/conf/myid' }
    let(:myid)    { %r{^1} }

    precond = 'class {"zookeeper": }'
    include_examples 'zookeeper parameters', os_facts, precond
  end

  context 'with custom parameters' do
    let(:user)    { 'zoo' }
    let(:group)   { 'zoo' }
    let(:cfg_dir) { '/var/lib/zookeeper/conf' }
    let(:log_dir) { '/var/lib/zookeeper/log' }
    let(:id_file) { '/var/lib/zookeeper/conf/myid' }
    let(:myid)    { %r{^2} }

    # set custom params
    precond = 'class {"zookeeper":
      id      => "2",
      user    => "zoo",
      group   => "zoo",
      cfg_dir => "/var/lib/zookeeper/conf",
      log_dir => "/var/lib/zookeeper/log",
    }'

    include_examples 'zookeeper parameters', os_facts, precond
  end

  include_examples 'zookeeper common', os_facts
end
