require 'spec_helper'

describe 'zookeeper::sasl', type: :class do
  _, os_facts = on_supported_os.first

  os_facts[:os]['hardware'] = 'x86_64'
  os_facts[:ipaddress] = '192.168.1.1'
  let(:facts) { os_facts }

  os_info = get_os_info(os_facts)
  environment_file = os_info[:environment_file]

  context 'sasl config' do
    let :pre_condition do
      'class {"zookeeper":
         use_sasl_auth => true,
       }'
    end

    it { is_expected.to compile.with_all_deps }
    it { is_expected.to contain_class('zookeeper::sasl') }

    it do
      is_expected.to contain_file(
        '/etc/zookeeper/conf/jaas.conf',
      ).with_content(%r{storeKey=true})
    end

    it do
      is_expected.to contain_file(
        environment_file,
      ).with_content(%r{JAVA_OPTS=".* -Djava.security.auth.login.config=/etc/zookeeper/conf/jaas.conf"})
    end
  end

  context 'remove host and realm from principal' do
    let :pre_condition do
      'class {"zookeeper":
         use_sasl_auth => true,
         remove_host_principal => true,
         remove_realm_principal => true,
       }'
    end

    it { is_expected.to compile.with_all_deps }
    it { is_expected.to contain_class('zookeeper::sasl') }

    it do
      is_expected.to contain_file(
        '/etc/zookeeper/conf/zoo.cfg',
      ).with_content(%r{kerberos.removeHostFromPrincipal=true})
    end

    it do
      is_expected.to contain_file(
        '/etc/zookeeper/conf/zoo.cfg',
      ).with_content(%r{kerberos.removeRealmFromPrincipal=true})
    end
  end
end
