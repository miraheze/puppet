# frozen_string_literal: true

require 'spec_helper'

describe 'icinga::server' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      case os_facts[:osfamily]
      when 'Debian'
        before(:all) do
          @icinga2_config_dir = '/etc/icinga2'
          @icinga2_user = 'nagios'
          @icinga2_group = 'nagios'
        end
      when 'RedHat', 'Suse'
        before(:all) do
          @icinga2_config_dir = '/etc/icinga2'
          @icinga2_user = 'icinga'
          @icinga2_group = 'icinga'
        end
      end

      case os_facts[:osfamily]
      when 'RedHat', 'Debian', 'Suse'

        context 'with defaults' do
          it { is_expected.to compile.and_raise_error(%r{expects a String value if a CA is configured}) }
        end

        context 'with ticket_salt => supersecret, global_zones => [foo], web_api_user => bar, web_api_pass => topsecret' do
          let(:params) { { ticket_salt: 'supersecret', global_zones: ['foo'], web_api_user: 'bar', web_api_pass: 'topsecret' } }

          it { is_expected.to compile }
          it { is_expected.to contain_class('icinga').with({
            'ca'           => true,
            'this_zone'    => 'main',
            'zones'        => { 'ZoneName' => {'endpoints' => {'NodeName' => {}}} },
            'logging_type' => 'file',
            'ticket_salt'  => 'supersecret'}) }
          it { is_expected.to contain_class('icinga2::feature::checker') }
          it { is_expected.to contain_class('icinga2::feature::notification') }
          it { is_expected.to contain_class('icinga2::feature::mainlog') }
          it { is_expected.to contain_file(@icinga2_config_dir+'/zones.d/main').with({
            'ensure' => 'directory',
            'owner'  => @icinga2_user,
            'group'  => @icinga2_group,
            'mode'   => '0750'}) }
          it { is_expected.to contain_icinga2__object__zone('foo').with(
            'global' => true
          )}
          it { is_expected.to contain_file(@icinga2_config_dir+'/zones.d/foo').with({
            'ensure' => 'directory',
            'owner'  => @icinga2_user,
            'group'  => @icinga2_group,
            'mode'   => '0750'}) }
          it { is_expected.to contain_icinga2__object__apiuser('bar').with({
            'password' => 'topsecret'
          }) }
        end

        context 'with ca_server => foo, ticket_salt => supersecret, colocation_endpoints => {bar => {host => 127.0.0.1}}' do
          let(:params) { { ca_server: 'foo', ticket_salt: 'supersecret', colocation_endpoints: {'bar' => {'host' => '127.0.0.1'}} } }

          it { is_expected.to compile }
          it { is_expected.to contain_class('icinga').with({
           'ca'           => false,
           'ca_server'    => 'foo',
           'this_zone'    => 'main',
           'zones'        => { 'ZoneName' => {'endpoints' => {'NodeName' => {}, 'bar' => {'host' => '127.0.0.1'}}} },
           'logging_type' => 'file',
           'ticket_salt'  => 'supersecret'
          }) }
        end

        context 'with ticket_salt => supersecret, zone => foo, workers => {bar => {endpoints => {foobar => {host => 127.0.0.1}}}}, logging_type => syslog, logging_level => warning' do
          let(:params) { { ticket_salt: 'supersecret', zone: 'foo', workers: {'bar' => {'endpoints' => {'foobar' => {'host' => '127.0.0.1'}}}}, logging_type: 'syslog', logging_level: 'warning'} }

          it { is_expected.to compile }
          it { is_expected.to contain_class('icinga').with({
            'ca'            => true,
            'this_zone'     => 'foo',
            'zones'         => { 'ZoneName' => {'endpoints' => {'NodeName' => {}}}, 'bar' => {'endpoints' => {'foobar' => {'host' => '127.0.0.1'}}, 'parent' => 'foo'} },
            'logging_type'  => 'syslog',
            'logging_level' => 'warning',
            'ticket_salt'   => 'supersecret'
          }) }
        end

      else
        context 'with ticket_salt => supersecret' do
          let(:params) { { ticket_salt: 'supersecret' } }
          it { is_expected.to compile.and_raise_error(%r{not supported}) }
        end
      end

    end
  end
end
