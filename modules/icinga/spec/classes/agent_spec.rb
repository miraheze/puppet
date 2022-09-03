# frozen_string_literal: true

require 'spec_helper'

describe 'icinga::agent' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      case os_facts[:osfamily]
      when 'RedHat', 'Debian', 'Suse'

        context 'with ca_server => foo, parent_endpoints => { foobar => { host => 127.0.0.1}}, global_zones => [foobaz]' do
          let(:params) { { ca_server: 'foo', parent_endpoints: { 'foobar' => { 'host' => '127.0.0.1' }}, global_zones: ['foobaz'] } }

          it { is_expected.to compile }
          it { is_expected.to contain_class('icinga').with({
            'ca'           => false,
            'ca_server'    => 'foo',
            'this_zone'    => 'NodeName',
            'zones'        => { 'ZoneName' => { 'endpoints' => { 'NodeName' => {} }, 'parent' => 'main' }, 'main' => { 'endpoints' => { 'foobar' => { 'host' => '127.0.0.1' }}} },
            'logging_type' => 'file'
          }) }
          it { is_expected.to contain_icinga2__object__zone('foobaz').with({
            'global' => true
          }) }
        end

      else
        context 'with ca_server => foo, parent_endpoints => { foobar => { host => 127.0.0.1}}' do
          let(:params) { { ca_server: 'foo', parent_endpoints: { 'foobar' => { 'host' => '127.0.0.1' }} } }
          it { is_expected.to compile.and_raise_error(%r{not supported}) }
        end
      end

    end
  end
end
