# frozen_string_literal: true

require 'spec_helper_acceptance'

case fact('osfamily')
when 'RedHat', 'Suse'
  user_shell = '/sbin/nologin'
when 'Debian'
  user_shell = '/usr/sbin/nologin'
end

# rubocop:disable RSpec/RepeatedExampleGroupBody
describe 'kafka::broker' do
  it 'works with no errors' do
    pp = <<-EOS
      class { 'kafka::broker':
        config => {
          'zookeeper.connect' => 'localhost:2181',
        },
      } ->
      kafka::topic { 'demo':
        ensure    => present,
        zookeeper => 'localhost:2181',
      }
    EOS

    apply_manifest(pp, catch_failures: true)
    apply_manifest(pp, catch_changes: true)
  end

  describe 'kafka::broker::install' do
    context 'with default parameters' do
      it 'works with no errors' do
        pp = <<-EOS
          class { 'kafka::broker':
            config => {
              'zookeeper.connect' => 'localhost:2181',
            },
          }
        EOS

        apply_manifest(pp, catch_failures: true)
      end

      describe group('kafka') do
        it { is_expected.to exist }
      end

      describe user('kafka') do
        it { is_expected.to exist }
        it { is_expected.to belong_to_group 'kafka' }
        it { is_expected.to have_login_shell user_shell }
      end

      describe file('/var/tmp/kafka') do
        it { is_expected.to be_directory }
        it { is_expected.to be_owned_by 'kafka' }
        it { is_expected.to be_grouped_into 'kafka' }
      end

      describe file('/opt/kafka-2.12-2.4.1') do
        it { is_expected.to be_directory }
        it { is_expected.to be_owned_by 'kafka' }
        it { is_expected.to be_grouped_into 'kafka' }
      end

      describe file('/opt/kafka') do
        it { is_expected.to be_linked_to('/opt/kafka-2.12-2.4.1') }
      end

      describe file('/opt/kafka/config') do
        it { is_expected.to be_directory }
        it { is_expected.to be_owned_by 'kafka' }
        it { is_expected.to be_grouped_into 'kafka' }
      end

      describe file('/var/log/kafka') do
        it { is_expected.to be_directory }
        it { is_expected.to be_owned_by 'kafka' }
        it { is_expected.to be_grouped_into 'kafka' }
      end
    end
  end

  describe 'kafka::broker::config' do
    context 'with default parameters' do
      it 'works with no errors' do
        pp = <<-EOS
          class { 'kafka::broker':
            config => {
              'zookeeper.connect' => 'localhost:2181',
            },
          }
        EOS

        apply_manifest(pp, catch_failures: true)
      end

      describe file('/opt/kafka/config/server.properties') do
        it { is_expected.to be_file }
        it { is_expected.to be_owned_by 'kafka' }
        it { is_expected.to be_grouped_into 'kafka' }
        it { is_expected.to contain 'zookeeper.connect=localhost:2181' }
      end
    end

    context 'with custom config dir' do
      it 'works with no errors' do
        pp = <<-EOS
          class { 'kafka::broker':
            config => {
              'zookeeper.connect' => 'localhost:2181',
            },
            config_dir => '/opt/kafka/custom_config'
          }
        EOS

        apply_manifest(pp, catch_failures: true)
      end

      describe file('/opt/kafka/custom_config/server.properties') do
        it { is_expected.to be_file }
        it { is_expected.to be_owned_by 'kafka' }
        it { is_expected.to be_grouped_into 'kafka' }
        it { is_expected.to contain 'zookeeper.connect=localhost:2181' }
      end
    end

    context 'with specific version' do
      it 'works with no errors' do
        pp = <<-EOS
          class { 'kafka::broker':
            kafka_version => '2.4.0',
            config        => {
              'zookeeper.connect' => 'localhost:2181',
            },
          }
        EOS

        apply_manifest(pp, catch_failures: true)
      end

      describe file('/opt/kafka/config/server.properties') do
        it { is_expected.to be_file }
        it { is_expected.to be_owned_by 'kafka' }
        it { is_expected.to be_grouped_into 'kafka' }
      end
    end
  end

  describe 'kafka::broker::service' do
    context 'with default parameters' do
      it 'works with no errors' do
        pp = <<-EOS
          class { 'kafka::broker':
            config => {
              'zookeeper.connect' => 'localhost:2181',
            },
          }
        EOS

        apply_manifest(pp, catch_failures: true)
      end

      describe file('/etc/systemd/system/kafka.service'), if: (fact('operatingsystemmajrelease') == '7' && fact('osfamily') == 'RedHat') do
        it { is_expected.to be_file }
        it { is_expected.to be_owned_by 'root' }
        it { is_expected.to be_grouped_into 'root' }
      end

      describe service('kafka') do
        it { is_expected.to be_running }
        it { is_expected.to be_enabled }
      end
    end

    context 'with log4j/jmx parameters' do
      it 'works with no errors' do
        pp = <<-EOS
          exec { 'create log dir':
            command => '/bin/mkdir -p /some/path/to/logs',
            creates => '/some/path/to/logs',
          } ->
          class { 'kafka::broker':
            config => {
              'zookeeper.connect' => 'localhost:2181',
            },
            heap_opts  => '-Xmx512M -Xmx512M',
            log4j_opts => '-Dlog4j.configuration=file:/tmp/log4j.properties',
            jmx_opts   => '-Dcom.sun.management.jmxremote',
            opts       => '-Djava.security.policy=/some/path/my.policy',
            log_dir    => '/some/path/to/logs'
          }
        EOS

        apply_manifest(pp, catch_failures: true)
        apply_manifest(pp, catch_changes: true)
      end

      describe file('/etc/init.d/kafka'), if: (fact('service_provider') == 'upstart' && fact('osfamily') == 'Debian') do
        it { is_expected.to be_file }
        it { is_expected.to be_owned_by 'root' }
        it { is_expected.to be_grouped_into 'root' }
        it { is_expected.to contain %r{^# Provides:\s+kafka$} }
        it { is_expected.to contain 'export KAFKA_JMX_OPTS="-Dcom.sun.management.jmxremote"' }
        it { is_expected.to contain 'export KAFKA_HEAP_OPTS="-Xmx512M -Xmx512M"' }
        it { is_expected.to contain 'export KAFKA_LOG4J_OPTS="-Dlog4j.configuration=file:/tmp/log4j.properties"' }
      end

      describe file('/etc/systemd/system/kafka.service'), if: (fact('operatingsystemmajrelease') == '7' && fact('osfamily') == 'RedHat') do
        it { is_expected.to be_file }
        it { is_expected.to be_owned_by 'root' }
        it { is_expected.to be_grouped_into 'root' }
        it { is_expected.to contain "Environment='KAFKA_JMX_OPTS=-Dcom.sun.management.jmxremote'" }
        it { is_expected.to contain "Environment='KAFKA_HEAP_OPTS=-Xmx512M -Xmx512M'" }
        it { is_expected.to contain "Environment='KAFKA_LOG4J_OPTS=-Dlog4j.configuration=file:/tmp/log4j.properties'" }
        it { is_expected.to contain "Environment='KAFKA_OPTS=-Djava.security.policy=/some/path/my.policy'" }
        it { is_expected.to contain "Environment='LOG_DIR=/some/path/to/logs'" }
      end

      describe service('kafka') do
        it { is_expected.to be_running }
        it { is_expected.to be_enabled }
      end
    end
  end
end
# rubocop:enable RSpec/RepeatedExampleGroupBody
