require 'spec_helper'
describe 'mattermost' do
  # Read supported OSes from metadata.json
  metadata_path = File.dirname(__FILE__) + '/../../metadata.json'
  metadata = JSON.parse(File.read(metadata_path))
  supported_os = metadata['operatingsystem_support']

  test_on = {
    hardwaremodels: %w(x86_64),
    supported_os: supported_os
  }

  on_supported_os(test_on).each do |os, facts|
    context "on #{os}" do
      default_params = {
        gid: 5678,
        uid: 1234,
        user: 'foo',
        group: 'bar',
        version: '1.2.3'
      }
      context 'Install with version' do
        let(:facts) do
          facts
        end

        let(:params) do
          default_params
        end
        it { should contain_class('mattermost') }
        it { should contain_class('mattermost::config') }
        it { should contain_class('mattermost::install') }
        it { should contain_class('mattermost::params') }
        it { should contain_class('mattermost::service') }
        it { should contain_anchor('mattermost::begin') }
        it { should contain_anchor('mattermost::end') }
        it { should contain_mattermost_settings('/etc/mattermost.json') }
        it { should contain_file('/etc/mattermost.json') }
        it { should contain_file('/opt/mattermost-1.2.3') }
        it { should contain_file('/opt/mattermost') }
        it { should contain_file('mattermost.service') }
        it { should contain_group('bar').with_gid(5678) }
        it { should contain_service('mattermost') }
        it { should contain_archive('mattermost_team_v1.2.3.tar.gz') }
        it { should contain_user('foo').with_uid(1234) }
      end

      context 'Do not install or manage service' do
        let(:facts) do
          facts
        end

        let(:params) do
          default_params.merge(
            install_service: false,
            manage_service: false
          )
        end
        it { should_not contain_file('mattermost.service') }
        it { should_not contain_service('mattermost') }
      end

      context 'Do not create user or group' do
        let(:facts) do
          facts
        end

        let(:params) do
          default_params.merge(
            create_user: false,
            create_group: false
          )
        end
        it { should_not contain_user('foo') }
        it { should_not contain_group('bar') }
      end
    end
  end
  at_exit { RSpec::Puppet::Coverage.report! }
end
