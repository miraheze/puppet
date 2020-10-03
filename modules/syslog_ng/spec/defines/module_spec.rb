require 'spec_helper'

describe 'syslog_ng::module', :type => 'define' do
  let :title do 
    'foo'
  end
  let :default_facts do {
    :concat_basedir => '/tmp/concat-basedir'
  } end
  let :facts do
     default_facts.merge(
       { osfamily: 'Debian', os: { family: 'Debian', name: 'Ubuntu', release: { full: '14.4', major: '14.4' } } }
     )
  end
  context "When overriding module_prefix" do
    let :pre_condition do
      'class { syslog_ng: module_prefix => "MODPREFIX_" }'
    end
    it { should compile }
    it { should contain_package('MODPREFIX_foo').with_ensure('present') }
  end
  context "When osfamily is RedHat" do
    let :facts do
      default_facts.merge(
        { osfamily: 'RedHat', os: { family: 'RedHat', release: { major: '7' } } }
      )
    end
    let :pre_condition do
      'include syslog_ng'
    end
    it { should compile }
    it { should contain_package('syslog-ng-foo').with_ensure('present') }
  end
  context "When osfamily is Debian" do
    context "with defaults" do
      let :pre_condition do
        'include syslog_ng'
      end
      it { should compile }
      it { should contain_package('syslog-ng-mod-foo').with_ensure('present') }
    end
  end
  context "When osfamily is Suse" do
    let :facts do
      default_facts.merge(
        { osfamily: 'Suse', os: { family: 'Suse' } }
      )
    end
    let :pre_condition do
      'include syslog_ng'
    end
    it { should compile }
    it { should contain_package('syslog-ng-foo').with_ensure('present') }
  end
end

