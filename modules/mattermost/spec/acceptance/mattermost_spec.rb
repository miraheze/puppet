require 'spec_helper_acceptance'

context 'File' do
  describe file('/opt/mattermost'), if: os[:family] == 'redhat' do
    it { should be_symlink }
  end
end

context 'Service' do
  describe service('mattermost') do
    # it { should be_running.under('systemd') }
    it { should be_running }
  end
end

context 'Port' do
  describe port('8065') do
    it { should be_listening }
  end
end

context 'User' do
  describe user('mattermost') do
    it { should exist }
  end
end

context 'Group' do
  describe group('mattermost') do
    it { should exist }
  end
end
