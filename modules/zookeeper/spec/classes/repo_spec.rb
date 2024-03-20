require 'spec_helper'

shared_examples 'zookeeper repo release support' do |os_facts|
  context 'fail when release not supported' do
    let :pre_condition do
      'class {"zookeeper":
          repo =>  {
            name      => "myrepo",
            url       => "http://custom.url",
            descr     => "description",
          }
       }'
    end

    it do
      expect {
        is_expected.to compile
      }.to raise_error(%r{support repository for #{os_facts[:os]['family']}})
    end
  end
end

shared_examples 'zookeeper repo' do |os_facts|
  let(:user) { 'zookeeper' }
  let(:group) { 'zookeeper' }

  if %r{RedHat|Suse}.match?(os_facts[:os]['family'])
    context 'Cloudera repo' do
      let :pre_condition do
        'class {"zookeeper":
          repo       =>  {
            name      => "myrepo",
            url       => "http://custom.url",
            descr     => "description",
          }
        }'
      end

      it do
        is_expected.to contain_yumrepo('myrepo').with(baseurl: 'http://custom.url')
      end
    end
  end

  context 'fail when repository source not supported' do
    let :pre_condition do
      'class {"zookeeper":
        repo => "another-repo",
       }'
    end

    it 'requires repo to be a Hash (or not defined)' do
      expect {
        is_expected.to compile
      }.to raise_error(%r{type Undef or Hash})
    end
  end
end

describe 'zookeeper::install::repo' do
  on_supported_os.each do |os, os_facts|
    os_facts[:os]['hardware'] = 'x86_64'

    context "on #{os}" do
      let(:facts) do
        os_facts.merge(ipaddress: '192.168.1.1')
      end

      include_examples 'zookeeper repo', os_facts
    end
  end

  context 'test unsupported repo arch' do
    test_on = {
      hardwaremodels: ['arc'],
      supported_os: [
        {
          'operatingsystem'        => 'RedHat',
          'operatingsystemrelease' => ['7'],
        },
      ],
    }
    on_supported_os(test_on).each do |os, os_facts|
      context "on #{os}" do
        let(:facts) do
          os_facts.merge(ipaddress: '192.168.1.1')
        end

        include_examples 'zookeeper repo arch support', os_facts
      end
    end
  end

  context 'test unsupported repo release' do
    test_on = {
      supported_os: [
        {
          'operatingsystem'        => 'Debian',
          'operatingsystemrelease' => ['10'],
        },
      ],
    }
    on_supported_os(test_on).each do |os, os_facts|
      os_facts[:os]['hardware'] = 'x86_64'

      context "on #{os}" do
        let(:facts) do
          os_facts.merge(ipaddress: '192.168.1.1')
        end

        include_examples 'zookeeper repo release support', os_facts
      end
    end
  end
end
