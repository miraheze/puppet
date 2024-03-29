# SPDX-License-Identifier: Apache-2.0
require_relative '../../../../rake_modules/spec_helper'

describe 'httpd' do
  on_supported_os(WMFConfig.test_on).each do |os, facts|
    context "On #{os}" do
      let(:facts) { facts }
      context 'without parameters' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_service('apache2') }
        it { is_expected.to contain_exec('apache2_test_config_and_restart')
                              .with_refreshonly(true)
                              .that_comes_before('Service[apache2]')
        }
        it { is_expected.to contain_file('/etc/apache2/sites-available')
                              .with({'owner' => 'root', 'ensure' => 'directory'})
        }
        it { is_expected.to contain_httpd__mod_conf('filter').with_ensure('present') }
        it { is_expected.to contain_httpd__mod_conf('status').with_ensure('present')}
        it { is_expected.to contain_systemd__override('apache2-after-network-online-target')
            .with_ensure('absent')
        }
      end
      context 'with_no_legacy_compat' do
        let(:params) { {'legacy_compat' => 'absent' }}
        it { is_expected.to contain_httpd__mod_conf('access_compat').with_ensure('absent') }
        it { is_expected.to contain_httpd__mod_conf('filter').with_ensure('absent') }
      end
      context 'with_declared_modules' do
        let(:params) { {'modules' => ['foo', 'bar']} }
        it { is_expected.to contain_httpd__mod_conf('bar').with_ensure('present')}
      end
      context 'with_wait_network_online' do
        let(:params) { {'wait_network_online' => true} }
        it { is_expected.to contain_systemd__override('apache2-after-network-online-target')
          .with_ensure('present')
        }
      end
    end
  end
end
