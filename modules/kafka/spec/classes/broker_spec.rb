# frozen_string_literal: true

require 'spec_helper'
require 'shared_examples_param_validation'

describe 'kafka::broker', type: :class do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) do
        os_facts
      end

      let :params do
        {
          config: {
            'zookeeper.connect' => 'localhost:2181'
          }
        }
      end

      it { is_expected.to contain_class('kafka::broker::install').that_comes_before('Class[kafka::broker::config]') }
      it { is_expected.to contain_class('kafka::broker::config').that_comes_before('Class[kafka::broker::service]') }
      it { is_expected.to contain_class('kafka::broker::service').that_comes_before('Class[kafka::broker]') }
      it { is_expected.to contain_class('kafka::broker') }

      context 'with manage_log4j => true' do
        let(:params) { { 'manage_log4j' => true } }

        it { is_expected.to contain_class('kafka::broker::config').with('log_file_size' => '50MB', 'log_file_count' => 7) }
      end

      describe 'kafka::broker::install' do
        context 'defaults' do
          it { is_expected.to contain_class('kafka') }
        end
      end

      describe 'kafka::broker::config' do
        context 'defaults' do
          it { is_expected.to contain_file('/opt/kafka/config/server.properties') }
        end

        context 'with manage_log4j => true' do
          let(:params) { { 'manage_log4j' => true } }

          it { is_expected.to contain_file('/opt/kafka/config/log4j.properties').with_content(%r{^log4j.appender.kafkaAppender.MaxFileSize=50MB$}) }
          it { is_expected.to contain_file('/opt/kafka/config/log4j.properties').with_content(%r{^log4j.appender.kafkaAppender.MaxBackupIndex=7$}) }
        end
      end

      describe 'kafka::broker::service' do
        context 'manage_service false' do
          let(:params) { super().merge(manage_service: false) }

          it { is_expected.not_to contain_file('/etc/init.d/kafka') }
          it { is_expected.not_to contain_file('/etc/systemd/system/kafka.service') }
          it { is_expected.not_to contain_service('kafka') }
        end

        context 'defaults' do
          if os_facts['service_provider'] == 'systemd'
            it { is_expected.to contain_file('/etc/init.d/kafka').with_ensure('absent') }
            it { is_expected.not_to contain_file('/etc/systemd/system/kafka.service').with_content %r{^LimitNOFILE=} }
            it { is_expected.not_to contain_file('/etc/systemd/system/kafka.service').with_content %r{^LimitCORE=} }
          else
            it { is_expected.to contain_file('/etc/init.d/kafka') }
          end

          it { is_expected.to contain_service('kafka') }
        end

        context 'limit_nofile set' do
          let(:params) { super().merge(limit_nofile: '65536') }

          if os_facts['service_provider'] == 'systemd'
            it { is_expected.to contain_file('/etc/systemd/system/kafka.service').with_content %r{^LimitNOFILE=65536$} }
          else
            it { is_expected.to contain_file('/etc/init.d/kafka').with_content %r{ulimit -n 65536$} }
          end
        end

        context 'limit_core set' do
          let(:params) { super().merge(limit_core: 'infinity') }

          if os_facts['service_provider'] == 'systemd'
            it { is_expected.to contain_file('/etc/systemd/system/kafka.service').with_content %r{^LimitCORE=infinity$} }
          else
            it { is_expected.to contain_file('/etc/init.d/kafka').with_content %r{ulimit -c infinity$} }
          end
        end

        context 'service_requires set', if: os_facts['service_provider'] == 'systemd' do
          let(:params) { super().merge(service_requires: ['dummy.target']) }

          it { is_expected.to contain_file('/etc/systemd/system/kafka.service').with_content %r{^After=dummy\.target$} }
          it { is_expected.to contain_file('/etc/systemd/system/kafka.service').with_content %r{^Wants=dummy\.target$} }
        end
      end

      it_validates_parameter 'mirror_url'
    end
  end
end
