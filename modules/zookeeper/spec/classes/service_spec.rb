require 'spec_helper'

describe 'zookeeper::service', type: :class do
  _, os_facts = on_supported_os.first

  os_facts[:os]['hardware'] = 'x86_64'
  os_facts[:ipaddress] = '192.168.1.1'
  let(:facts) { os_facts }

  let(:user) { 'zookeeper' }
  let(:group) { 'zookeeper' }

  os_info = get_os_info(os_facts)

  should_install_zookeeperd = os_info[:should_install_zookeeperd]
  service_name = os_info[:service_name]
  init_dir = os_info[:init_dir]
  init_provider = os_info[:init_provider]
  service_file = os_info[:service_file]

  case init_provider
  when 'systemd'
    context 'systemd' do
      let :pre_condition do
        'class {"zookeeper":
           manage_service_file => true,
           service_provider    => "systemd",
           systemd_path        => "/usr/lib/systemd/system",
           zoo_dir             => "/usr/lib/zookeeper",
           log_dir             => "/var/log/zookeeper",
         }'
      end

      it { is_expected.to contain_package('zookeeper') }

      if should_install_zookeeperd
        it { is_expected.to contain_package('zookeeperd') }
      else
        it { is_expected.not_to contain_package('zookeeperd') }
      end

      it do
        is_expected.to contain_file(
          "/usr/lib/systemd/system/#{service_name}.service",
        ).with('ensure' => 'file')
      end

      it do
        is_expected.to contain_file(
          "/usr/lib/systemd/system/#{service_name}.service",
        ).with_content(%r{CLASSPATH="/usr/lib/zookeeper/zookeeper.jar})
      end

      it do
        is_expected.to contain_service(service_name).with(
          ensure: 'running',
          enable: true,
        )
      end

      context 'install from archive' do
        let :pre_condition do
          'class {"zookeeper":
             manage_service_file => true,
             install_method      => "archive",
             archive_version     => "3.4.9"
           }'
        end

        it do
          is_expected.to contain_file(service_file).with_content(
            %r{zookeeper-3\.4\.9\.jar},
          )
        end
      end

      context 'do not manage systemd' do
        let :pre_condition do
          'class {"zookeeper":
             manage_service_file => false,
             zoo_dir             => "/usr/lib/zookeeper",
             log_dir             => "/var/log/zookeeper",
           }'
        end

        it do
          is_expected.not_to contain_file(
            '/usr/lib/systemd/system/zookeeper.service',
          ).with('ensure' => 'present')
        end

        it do
          is_expected.not_to contain_file(service_file).with('ensure' => 'file')
        end
      end

      context 'systemd dependencies' do
        let :pre_condition do
          'class {"zookeeper":
             service_provider    => "systemd",
             manage_service_file => true,
             manage_service      => true,
             systemd_unit_after  => "network-online.target openvpn-client@.service",
             systemd_unit_want   => "network-online.target openvpn-client@.service",
           }'
        end

        it do
          is_expected.to contain_file(service_file).with('ensure' => 'file')
        end

        it do
          is_expected.to contain_file(service_file).with_content(
            %r{Wants=network-online.target openvpn-client@.service},
          )
        end

        it do
          is_expected.to contain_service(service_name).with(
            ensure: 'running',
            enable: true,
          )
        end
      end
    end

  when 'init'
    context 'init' do
      let :pre_condition do
        'class {"zookeeper":
           zoo_dir             => "/usr/lib/zookeeper",
           log_dir             => "/var/log/zookeeper",
           manage_service_file => true,
           service_provider    => "init",
         }'
      end

      it do
        is_expected.to contain_file(
          '/etc/init.d/zookeeper',
        ).with('ensure' => 'present')
      end

      it do
        is_expected.to contain_service('zookeeper').with(
          ensure: 'running',
          enable: true,
          provider: 'init',
        )
      end
    end

    context 'custom service name' do
      let :pre_condition do
        'class {"zookeeper":
           manage_service_file => true,
           service_name        => "my-zookeeper",
         }'
      end

      custom_service_file = if init_provider == 'systemd'
                              "#{init_dir}/my-zookeeper.service"
                            else
                              "#{init_dir}/my-zookeeper"
                            end

      it do
        is_expected.to contain_file(custom_service_file).with('ensure' => 'file')
      end

      it do
        is_expected.to contain_service('my-zookeeper').with(
          ensure: 'running',
          enable: true,
        )
      end
    end
  end
end
