# frozen_string_literal: true

require 'spec_helper'

describe 'icinga' do
  before(:each) do
    # Fake assert_private function from stdlib to not fail within this test
    Puppet::Parser::Functions.newfunction(:assert_private, :type => :rvalue) { |args| }
  end

  on_supported_os.each do |os, os_facts|

    context "on #{os}" do
      let(:facts) { os_facts }

      case os_facts[:osfamily]
      when 'RedHat', 'Debian', 'Suse'

        context 'ca => true, this_zone => foo, zones => {}' do
          let(:params) { { ca: true, this_zone: 'foo', zones: {} } }
          it { is_expected.to compile.and_raise_error(%r{expects a String value if a CA is configured}) }
        end

        context 'ca => true, this_zone => foo, zones => {}, ticket_salt => supersecret' do
          let(:params) { { ca: true, this_zone: 'foo', zones: {}, ticket_salt: 'supersecret' } }

          it { is_expected.to compile }
          it { is_expected.to contain_class('icinga2').with({
            'confd'           => false,
            'manage_packages' => false,
            'features'        => [],
          }) }
          it { is_expected.to contain_class('icinga2::feature::mainlog').with({'ensure' => 'present'}) }
          it { is_expected.to contain_class('icinga2::feature::syslog').with({'ensure' => 'absent'}) }
          it { is_expected.to contain_class('icinga2::pki::ca') }
          it { is_expected.to contain_class('icinga2::feature::api').with({
            'pki'             => 'none',
            'accept_config'   => true,
            'accept_commands' => true,
            'ticket_salt'     => 'TicketSalt',
            'zones'           => {},
            'endpoints'       => {}
          }) }
        end

        context 'ca => false, ca_server => foo, this_zone => foo, zones => { bar => { endpoints => { foobar => { host => 127.0.0.1 }}, parent => foo}}, ticket_salt => supersecret' do
          let(:params) { { ca: false, ca_server: 'foo', this_zone: 'foo', zones: {'bar' => { 'endpoints' => { 'foobar' => {'host' => '127.0.0.1'}}, 'parent' => 'foo'}}, ticket_salt: 'supersecret' } }

          it { is_expected.to compile }
          it { is_expected.not_to contain_class('icinga2::pki::ca') }
          it { is_expected.to contain_class('icinga2::feature::api').with({
            'pki'             => 'icinga2',
            'accept_config'   => true,
            'accept_commands' => true,
            'ticket_salt'     => 'supersecret',
            'ca_host'         => 'foo',
            'zones'           => {},
            'endpoints'       => {}
          }) }
          it { is_expected.to contain_icinga2__object__zone('bar').with({
            'endpoints' => [ 'foobar' ],
            'parent' => 'foo'
          }) }
          it { is_expected.to contain_icinga2__object__endpoint('foobar').with({
            'host' => '127.0.0.1'
          }) }
        end

      when 'Windows'

        context 'ca => false, this_zone => foo, zones => {}, ticket_salt => supersecret' do
          let(:params) { { ca: false, this_zone: 'foo', zones: {}, ticket_salt: 'supersecret' } }

          it { is_expected.to compile }
          it { is_expected.to contain_class('icinga2').with({
            'confd'           => false,
            'manage_packages' => true,
            'features'        => [],
          }) }
          it { is_expected.to contain_class('icinga2::feature::mainlog').with({'ensure' => 'present'}) }
          it { is_expected.to contain_class('icinga2::feature::syslog').with({'ensure' => 'absent'}) }
          it { is_expected.not_to contain_class('icinga2::pki::ca') }
          it { is_expected.to contain_class('icinga2::feature::api').with({
            'pki'             => 'icinga2',
            'accept_config'   => true,
            'accept_commands' => true,
            'ticket_salt'     => 'supersecret',
            'zones'           => {},
            'endpoints'       => {}
          }) }
        end

        context 'ca => false, this_zone => foo, zones => {}, logging_type => syslog' do
          let(:params) { { ca: false, this_zone: 'foo', zones: {}, logging_type: syslog  } }

          it { is_expected.to compile.and_raise_warning(%r{file is support as logging_type}) }
          it { is_expected.to contain_class('icinga2::feature::mainlog').with('ensure' => 'present') }
          it { is_expected.to contain_class('icinga2::feature::syslog').with('ensure' => 'absent') }
        end

      else
        context 'with ticket_salt => supersecret' do
          let(:params) { { ca: true, this_zone: 'foo', zones: {}, ticket_salt: 'supersecret' } }
          it { is_expected.to compile.and_raise_error(%r{not supported}) }
        end
      end
    end

  end
end
