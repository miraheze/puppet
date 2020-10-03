require 'spec_helper'

describe 'syslog_ng' do

  let(:facts)  {{ concat_basedir: '/dne',
                  osfamily: 'Debian',
                  os: { family: 'Debian', name: 'Ubuntu', release: { full: '14.04', major: '14.04' } },
                  operatingsystem: 'Ubuntu'
  }}

  context 'With not default params' do
    let(:params) {{
      :config_file => '/tmp/puppet-test/syslog-ng.conf',
      :sbin_path => '/home/tibi/install/syslog-ng',
      :manage_init_defaults => true
    }}
    it {
      should contain_package('syslog-ng-core')
      should contain_service('syslog-ng')
    }
    it {
      should contain_file('/etc/default/syslog-ng')
    }
  end

  context 'with unofficial repo' do
    let(:params) do
      {
        manage_repo: true,
      }
    end

    it { should compile }
    it { should contain_apt__source('syslog-ng-obs') }
  end

  context 'On RedHat' do
    let(:facts)  {{ concat_basedir: '/dne',
                    osfamily: 'RedHat',
                    os: { family: 'RedHat', name: 'RedHat', release: { major: '7' } },
                    operatingsystem: 'RedHat'
    }}

    context 'with init_defaults set to true' do
      let(:params) {{
        :manage_init_defaults => true
      }}
      it {
        should contain_package('syslog-ng')
        should contain_service('syslog-ng')
      }
      it {
        should contain_file('/etc/sysconfig/syslog-ng')
      }
    end

    context 'with unofficial repo' do
      let(:params) do
        {
          manage_repo: true,
        }
      end

      it { should compile }
      it { should contain_yumrepo('czanik-syslog-ng-githead') }
    end
  end
  context 'On SLES with init_defaults set to true' do
    let(:params) {{
      :manage_init_defaults => true
    }}
    let(:facts)  {{ concat_basedir: '/dne',
                    osfamily: 'Suse',
                    os: { family: 'Suse' },
                    operatingsystem: 'SLES'
    }}
    it {
      should contain_package('syslog-ng')
      should contain_service('syslog-ng')
    }
    it {
      should contain_file('/etc/sysconfig/syslog-ng')
    }
  end
  context 'When asked not to manage package' do
    let(:params) {{
      :manage_package => false
    }}
    it { should_not contain_package('syslog-ng-core') }
  end
  context 'When asked to use additional module' do
    let(:params) {{
      :modules => [ 'foo', 'bar', 'baz' ]
    }}
    it {
      should contain_syslog_ng__module('foo')
      should contain_syslog_ng__module('bar')
      should contain_syslog_ng__module('baz')
    }
  end
  context 'When config changes' do
    it {
      should contain_concat('/etc/syslog-ng/syslog-ng.conf').that_notifies('Exec[syslog_ng_reload]')
    }
    context 'and asked to check syntax before reload' do
      let(:params) {{
        :syntax_check_before_reloads => true
      }}
      it {
        should contain_concat('/etc/syslog-ng/syslog-ng.conf').with_validate_cmd(/syntax-only/)
      }
    end
    context 'and asked not to check syntax before reload' do
      let(:params) {{
        :syntax_check_before_reloads => false
      }}
      it {
        should contain_concat('/etc/syslog-ng/syslog-ng.conf').without_validate_cmd
      }
    end
  end
end
