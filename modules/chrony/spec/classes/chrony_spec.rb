# frozen_string_literal: true

require 'spec_helper'

describe 'chrony' do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) do
        facts
      end
      let(:config_file) do
        case facts[:os]['family']
        when 'Archlinux', 'RedHat', 'Suse'
          '/etc/chrony.conf'
        else
          '/etc/chrony/chrony.conf'
        end
      end
      let(:keys_file) do
        case facts[:os]['family']
        when 'Archlinux', 'RedHat', 'Suse'
          '/etc/chrony.keys'
        else
          '/etc/chrony/chrony.keys'
        end
      end
      let(:config_file_contents) do
        catalogue.resource('file', config_file).send(:parameters)[:content]
      end

      context 'with defaults' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('chrony') }
        it { is_expected.to contain_class('chrony::install').that_comes_before('Class[chrony::config]') }
        it { is_expected.to contain_class('chrony::config').that_notifies('Class[chrony::service]') }
        it { is_expected.to contain_class('chrony::service') }
        it { is_expected.to contain_file(config_file).without_content(%r{^\s*acquisitionport}) }
        it { is_expected.to contain_file(config_file).without_content(%r{^\s*bindacqaddress}) }
      end

      context 'chrony::package' do
        context 'using defaults' do
          it { is_expected.to contain_package('chrony').with_ensure('present') }
        end
      end

      context 'chrony::config' do
        case facts[:os]['family']
        when 'Archlinux'
          context 'using defaults' do
            it { is_expected.to contain_file(config_file).with_content(%r{^\s*cmdallow 127\.0\.0\.1$}) }

            ['0.pool.ntp.org', '1.pool.ntp.org', '2.pool.ntp.org', '3.pool.ntp.org'].each do |s|
              it { is_expected.to contain_file(config_file).with_content(%r{^\s*server #{s} iburst$}) }
            end
            it { is_expected.to contain_file(config_file).with_content(%r{^\s*rtconutc$}) }
            it { is_expected.to contain_file(config_file).with_content(%r{^\s*driftfile /var/lib/chrony/drift$}) }
            it { is_expected.to contain_file(config_file).with_content(%r{^\s*rtcsync$}) }
            it { is_expected.to contain_file(config_file).with_content(%r{^\s*dumpdir /var/lib/chrony$}) }
            it { is_expected.to contain_file(config_file).without_content(%r{^\s*ntpsigndsocket}) }
            it { is_expected.to contain_file(config_file).without_content(%r{^\s*\n\s*$}) }
            it { is_expected.to contain_file(keys_file).with_mode('0644') }
            it { is_expected.to contain_file(keys_file).with_owner('0') }
            it { is_expected.to contain_file(keys_file).with_group('0') }
            it { is_expected.to contain_file(keys_file).with_replace(true) }
            it { is_expected.to contain_file(keys_file).with_content(sensitive("0 xyzzy\n")) }
          end
        when 'Gentoo'
          context 'using defaults' do
            it do
              is_expected.to contain_file(config_file)
                .without_content(%r{^\s*cmdallow})
                .with_content(%r{^\s*server 0.pool.ntp.org iburst$})
                .with_content(%r{^\s*server 1.pool.ntp.org iburst$})
                .with_content(%r{^\s*server 2.pool.ntp.org iburst$})
                .with_content(%r{^\s*server 3.pool.ntp.org iburst$})
                .with_content(%r{^\s*rtconutc$})
                .with_content(%r{^\s*driftfile /var/lib/chrony/drift$})
                .with_content(%r{^\s*rtcsync$})
                .without_content(%r{^\s*dumpdir})
                .without_content(%r{^\s*ntpsigndsocket})
                .without_content(%r{^\s*\n\s*$})
            end

            it do
              is_expected.to contain_file(keys_file)
                .with_mode('0644')
                .with_owner('0')
                .with_group('0')
                .with_replace(true)
                .with_content(sensitive("0 xyzzy\n"))
            end
          end
        when 'RedHat'
          context 'using defaults' do
            it { is_expected.to contain_file(config_file).with_content(%r{^\s*bindcmdaddress ::1$}) }
            it { is_expected.to contain_file(config_file).with_content(%r{^\s*bindcmdaddress 127\.0\.0\.1$}) }
            it { is_expected.not_to contain_file(config_file).with_content(%r{^\s*cmdallow.*$}) }

            ['0.pool.ntp.org', '1.pool.ntp.org', '2.pool.ntp.org', '3.pool.ntp.org'].each do |s|
              it { is_expected.to contain_file(config_file).with_content(%r{^\s*server #{s} iburst$}) }
            end
            it { is_expected.to contain_file(config_file).with_content(%r{^\s*driftfile /var/lib/chrony/drift$}) }
            it { is_expected.to contain_file(config_file).with_content(%r{^\s*rtcsync$}) }
            it { is_expected.to contain_file(config_file).without_content(%r{^\s*dumpdir}) }
            it { is_expected.to contain_file(config_file).without_content(%r{^\s*ntpsigndsocket}) }
            it { is_expected.to contain_file(config_file).without_content(%r{^\s*\n\s*$}) }
            it { is_expected.to contain_file(keys_file).with_mode('0640') }
            it { is_expected.to contain_file(keys_file).with_owner('0') }
            it { is_expected.to contain_file(keys_file).with_group('chrony') }
            it { is_expected.to contain_file(keys_file).with_replace(true) }
            it { is_expected.to contain_file(keys_file).with_content(sensitive("0 xyzzy\n")) }
          end
        when 'Debian'
          context 'using defaults' do
            it { is_expected.to contain_file(config_file).with_content(%r{^\s*bindcmdaddress ::1$}) }
            it { is_expected.to contain_file(config_file).with_content(%r{^\s*bindcmdaddress 127\.0\.0\.1$}) }
            it { is_expected.not_to contain_file(config_file).with_content(%r{^\s*cmdallow.*$}) }

            it { is_expected.not_to contain_file(config_file).with_content(%r{^\s*server }) }

            if facts[:os]['name'] == 'Ubuntu'
              it { is_expected.to contain_file(config_file).with_content(%r{^\s*pool ntp.ubuntu.com iburst maxsources 4$}) }
            else
              it { is_expected.to contain_file(config_file).with_content(%r{^\s*pool 2.debian.pool.ntp.org iburst$}) }
            end

            it { is_expected.to contain_file(config_file).with_content(%r{^\s*driftfile /var/lib/chrony/chrony.drift$}) }
            it { is_expected.to contain_file(config_file).with_content(%r{^\s*rtcsync$}) }

            if facts[:os]['release']['major'].to_i < 13 || (facts[:os]['name'] == 'Ubuntu' && facts[:os]['release']['major'].to_i < 26)
              context 'older than 13 and Ubuntu older than 26.04' do
                it { is_expected.to contain_file(config_file).with_content(%r{^\s*leapsectz right/UTC$}) }
              end
            else
              it { is_expected.to contain_file(config_file).with_content(%r{^\s*leapseclist /usr/share/zoneinfo/leap-seconds.list$}) }
            end

            it { is_expected.to contain_file(config_file).with_content(%r{^\s*makestep 1 3$}) }
            it { is_expected.to contain_file(config_file).with_content(%r{^\s*maxupdateskew 100.0$}) }

            it { is_expected.to contain_file(config_file).with_content(%r{^\s*ntsdumpdir /var/lib/chrony$}) }
            it { is_expected.to contain_file(config_file).without_content(%r{^\s*dumpdir}) }
            it { is_expected.to contain_file(config_file).without_content(%r{^\s*ntpsigndsocket}) }
            it { is_expected.to contain_file(config_file).without_content(%r{^\s*\n\s*$}) }
            it { is_expected.to contain_file(keys_file).with_mode('0640') }
            it { is_expected.to contain_file(keys_file).with_owner('0') }
            it { is_expected.to contain_file(keys_file).with_group('_chrony') }
            it { is_expected.to contain_file(keys_file).with_replace(true) }
            it { is_expected.to contain_file(keys_file).with_content(sensitive("0 xyzzy\n")) }
          end
        end
        it { is_expected.to contain_file(config_file).with_content(%r{keyfile .*chrony.keys}) }
      end

      context 'with empty config_keys' do
        let :params do
          {
            config_keys: '',
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_file(config_file).without_content(%r{keyfile .*chrony.keys}) }
        it { is_expected.not_to contain_file(keys_file) }
      end

      context 'with some params passed in' do
        let(:params) do
          {
            queryhosts: ['192.168/16'],
            denyqueryhosts: ['10.0/16'],
            port: 123,
            cmdport: 257,
            config_keys_mode: '0123',
            config_keys_owner: 'steve',
            config_keys_group: 'mrt',
            config_keys_manage: true,
            confdir: '/tmp/chroconf',
            sourcedir: '/tmp/chrosources',
            chrony_password: sensitive('sunny'),
            bindaddress: ['10.0.0.1', '::1'],
            bindacqaddress: ['10.0.0.2', '::2'],
            bindcmdaddress: ['10.0.0.1'],
            initstepslew: '600',
            cmdacl: ['cmdallow 1.2.3.4', 'cmddeny 1.2.3', 'cmdallow all 1.2'],
            leapsecmode: 'slew',
            leapsectz: 'right/UTC',
            log_options: 'statistics refclocks',
            logbanner: 40,
            logchange: 4.0,
            maxdistance: 16.0,
            maxslewrate: 1000.0,
            maxupdateskew: 1000.0,
            smoothtime: '400 0.001 leaponly',
            rtconutc: true,
            hwtimestamps: ['eth0'],
            driftfile: '/var/tmp/chrony.drift',
            rtcsync: false,
            sched_priority: 1,
            dumpdir: '/var/tmp',
            ntpsigndsocket: '/var/lib/samba/ntp_signd/socket',
            ntsserverkey: '/tmp/cert.key',
            ntsservercert: '/tmp/cert.pem',
            ntsport: 12,
            maxntsconnections: 32,
            minsources: 22,
            minsamples: 33,
            acquisitionport: 321,
            ntsprocesses: 5,
            ntsdumpdir: '/tmp/ntsdump',
            ntsntpserver: 'foo.bar',
            ntsrotate: 8,
            ntstrustedcerts: '/tmp/trusted_certs.pem',
            nocerttimecheck: 5,
            nosystemcert: true,
            authselectmode: 'prefer',
          }
        end

        it { is_expected.to contain_file(config_file).with_content(%r{^\s*leapsecmode slew$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^\s*leapsectz right/UTC$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^\s*maxdistance 16\.0$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^\s*maxslewrate 1000\.0$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^\s*maxupdateskew 1000\.0$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^\s*smoothtime 400 0\.001 leaponly$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^\s*port 123$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^\s*cmdport 257$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^\s*acquisitionport 321$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^s*allow 192\.168/16$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^s*deny 10\.0/16$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^\s*bindaddress 10\.0\.0\.1$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^\s*bindaddress ::1$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^\s*bindacqaddress 10\.0\.0\.2$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^\s*bindacqaddress ::2$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^\s*initstepslew 600$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^\s*bindcmdaddress 10\.0\.0\.1$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^\s*cmdallow 1\.2\.3\.4$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^\s*cmddeny 1\.2\.3$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^\s*cmdallow all 1\.2$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^\s*rtconutc$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^\s*hwtimestamp eth0$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^\s*driftfile /var/tmp/chrony.drift$}) }
        it { is_expected.to contain_file(config_file).without_content(%r{^\s*rtcsync$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^\s*dumpdir /var/tmp$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^\s*ntpsigndsocket /var/lib/samba/ntp_signd/socket$}) }
        it { is_expected.to contain_file(keys_file).with_mode('0123') }
        it { is_expected.to contain_file(keys_file).with_owner('steve') }
        it { is_expected.to contain_file(keys_file).with_group('mrt') }
        it { is_expected.to contain_file(keys_file).with_replace(true) }
        it { is_expected.to contain_file(keys_file).with_content(sensitive("0 sunny\n")) }
        it { is_expected.to contain_file(config_file).with_content(%r{^\s*ntsserverkey /tmp/cert.key$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^\s*ntsservercert /tmp/cert.pem$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^\s*ntsport 12$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^\s*maxntsconnections 32$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^\s*ntsprocesses 5$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^\s*ntsdumpdir /tmp/ntsdump$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^\s*ntsntpserver foo.bar$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^\s*ntsrotate 8$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^\s*ntstrustedcerts /tmp/trusted_certs.pem$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^\s*nocerttimecheck 5$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^\s*nosystemcert$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^\s*authselectmode prefer$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^\s*confdir /tmp/chroconf$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^\s*sourcedir /tmp/chrosources$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^\s*log statistics refclocks$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^\s*logbanner 40$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^\s*logchange 4\.0$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^\s*sched_priority 1$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^\s*minsources 22$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^\s*minsamples 33$}) }
      end

      describe 'confdir' do
        context 'by default' do
          case facts[:os]['family']
          when 'Debian'
            it { is_expected.to contain_file(config_file).with_content(%r{^confdir /etc/chrony/conf\.d$}) }
          else
            it { is_expected.not_to contain_file(config_file).with_content(%r{confdir}) }
          end
        end

        context 'when set to a single path' do
          let(:params) do
            {
              confdir: '/etc/chrony.d',
            }
          end

          it { is_expected.to contain_file(config_file).with_content(%r{^confdir /etc/chrony\.d$}) }
        end

        context 'when set to an array of paths' do
          let(:params) do
            {
              confdir: ['/etc/chrony.d', '/etc/chrony.d.local'],
            }
          end

          it { is_expected.to contain_file(config_file).with_content(%r{^confdir /etc/chrony\.d$}) }
          it { is_expected.to contain_file(config_file).with_content(%r{^confdir /etc/chrony\.d\.local$}) }
        end
      end

      describe 'sourcedir' do
        context 'by default' do
          case facts[:os]['family']
          when 'Debian'
            it { is_expected.to contain_file(config_file).with_content(%r{^sourcedir /etc/chrony/sources\.d$}) }
            it { is_expected.to contain_file(config_file).with_content(%r{^sourcedir /run/chrony-dhcp$}) }
          else
            it { is_expected.not_to contain_file(config_file).with_content(%r{sourcedir}) }
          end
        end

        context 'when set to a single path' do
          let(:params) do
            {
              sourcedir: '/var/run/chrony-dhcp',
            }
          end

          it { is_expected.to contain_file(config_file).with_content(%r{^sourcedir /var/run/chrony-dhcp$}) }
        end

        context 'when set to an array of paths' do
          let(:params) do
            {
              sourcedir: ['/var/run/chrony-dhcp', '/etc/chrony.d.sources'],
            }
          end

          it { is_expected.to contain_file(config_file).with_content(%r{^sourcedir /var/run/chrony-dhcp$}) }
          it { is_expected.to contain_file(config_file).with_content(%r{^sourcedir /etc/chrony\.d\.sources$}) }
        end
      end

      describe 'stratumweight' do
        context 'by default' do
          it { is_expected.not_to contain_file(config_file).with_content(%r{stratumweight}) }
        end

        context 'when set' do
          let(:params) do
            {
              stratumweight: 0,
            }
          end

          it { is_expected.to contain_file(config_file).with_content(%r{^stratumweight 0$}) }
        end
      end

      describe 'servers' do
        context 'by default' do
          case facts[:os]['family']
          when 'Debian'
            it { expect(config_file_contents).not_to match(%r{^server }) }
          else
            it do
              expected_lines = [
                'server 0.pool.ntp.org iburst',
                'server 1.pool.ntp.org iburst',
                'server 2.pool.ntp.org iburst',
                'server 3.pool.ntp.org iburst',
              ]
              expect(config_file_contents.split("\n") & expected_lines).to eq(expected_lines)
            end
          end
        end

        context 'when servers is an array' do
          let(:params) do
            {
              servers: ['ntp1.corp.com', 'ntp2.corp.com'],
            }
          end

          it do
            expected_lines = [
              'server ntp1.corp.com iburst',
              'server ntp2.corp.com iburst',
            ]
            expect(config_file_contents.split("\n") & expected_lines).to eq(expected_lines)
          end
        end

        context 'when servers is an (unsorted) hash' do
          let(:params) do
            {
              servers: {
                'ntp3.corp.com' => [],
                'ntp1.corp.com' => ['key 25', 'iburst'],
                'ntp4.corp.com' => :undef,
                'ntp2.corp.com' => ['key 25', 'iburst'],
              },
            }
          end

          it do
            expected_lines = [
              'server ntp1.corp.com key 25 iburst',
              'server ntp2.corp.com key 25 iburst',
              'server ntp3.corp.com',
              'server ntp4.corp.com',
            ]
            expect(config_file_contents.split("\n") & expected_lines).to eq(expected_lines)
          end
        end
      end

      describe 'pools' do
        context 'by default' do
          case facts[:os]['family']
          when 'Debian'
            if facts[:os]['name'] == 'Ubuntu'
              it { expect(config_file_contents).to match(%r{^pool ntp.ubuntu.com iburst maxsources 4$}) }
            else
              it { expect(config_file_contents).to match(%r{^pool 2.debian.pool.ntp.org iburst$}) }
            end
          else
            it { expect(config_file_contents).not_to match(%r{^pool}) }
          end
        end

        context 'when pools is an array' do
          let(:params) do
            {
              pools: ['0.pool.ntp.org', '1.pool.ntp.org'],
            }
          end

          it do
            expected_lines = [
              'pool 0.pool.ntp.org iburst',
              'pool 1.pool.ntp.org iburst',
            ]
            expect(config_file_contents.split("\n") & expected_lines).to eq(expected_lines)
          end
        end

        context 'when pools is a hash' do
          let(:params) do
            {
              pools: {
                '3.pool.ntp.org' => [],
                '0.pool.ntp.org' => ['maxsources 4'],
                '1.pool.ntp.org' => ['maxsources 4'],
                '2.pool.ntp.org' => ['maxsources 4'],
              },
            }
          end

          it do
            expected_lines = [
              'pool 0.pool.ntp.org maxsources 4',
              'pool 1.pool.ntp.org maxsources 4',
              'pool 2.pool.ntp.org maxsources 4',
              'pool 3.pool.ntp.org',
            ]
            expect(config_file_contents.split("\n") & expected_lines).to eq(expected_lines)
          end
        end
      end

      describe 'peers' do
        context 'by default' do
          it { expect(config_file_contents).not_to match(%r{^peer}) }
        end

        context 'when peers is an array' do
          let(:params) do
            {
              peers: ['peer1.example.com', 'peer2.example.com'],
            }
          end

          it do
            expected_lines = [
              'peer peer1.example.com',
              'peer peer2.example.com',
            ]
            expect(config_file_contents.split("\n") & expected_lines).to eq(expected_lines)
          end
        end

        context 'when peers is a hash' do
          let(:params) do
            {
              peers: {
                'peer1.example.com' => [],
                'peer2.example.com' => ['maxpoll 6'],
                'peer3.example.com' => :undef,
              },
            }
          end

          it do
            expected_lines = [
              'peer peer1.example.com',
              'peer peer2.example.com maxpoll 6',
              'peer peer3.example.com',
            ]
            expect(config_file_contents.split("\n") & expected_lines).to eq(expected_lines)
          end
        end
      end

      describe 'sysconfig chronyd file' do
        case facts[:os]['family']
        when 'RedHat'

          it 'creates /etc/sysconfig/chronyd with correct ownership and permissions' do
            is_expected.to contain_file('/etc/sysconfig/chronyd').with(
              ensure: 'file',
              owner: '0',
              group: '0',
              mode: '0644',
            )
          end

          it 'does not create /etc/default/chrony' do
            is_expected.not_to contain_file('/etc/default/chrony')
          end

          if (facts[:os]['release']['major'] = '8')
            context 'on RedHat 8 family with default parameters' do
              it 'contains an empty OPTIONS line' do
                is_expected.to contain_file('/etc/sysconfig/chronyd').with_content(%r{^OPTIONS=""$})
              end
            end
          else
            context 'on RedHat 9 and greater family with default parameters' do
              it 'contains an empty OPTIONS line' do
                is_expected.to contain_file('/etc/sysconfig/chronyd').with_content(%r{^OPTIONS="-F 2"$})
              end
            end
          end

          context 'with custom options parameter' do
            let(:params) { { options: '-4 -u chrony' } }

            it 'contains the custom OPTIONS line' do
              is_expected.to contain_file('/etc/sysconfig/chronyd').with_content(%r{^OPTIONS="-4 -u chrony"$})
            end
          end
        when 'Debian'
          it 'does not create /etc/sysconfig/chronyd' do
            is_expected.not_to contain_file('/etc/sysconfig/chronyd')
          end

          context 'with no options parameter' do
            it { is_expected.not_to contain_file('/etc/default/chrony') }
          end

          context 'with custom options parameter' do
            let(:params) { { options: '-4 -u chrony' } }

            it 'contains the custom OPTIONS line' do
              is_expected.to contain_file('/etc/default/chrony')
                .with_content(%r{^DAEMON_OPTS="-4 -u chrony"$})
                .with_ensure('file')
                .with_owner('0')
                .with_group('0')
                .with_mode('0644')
            end
          end
        else
          it 'on non-RedHat/Debian families' do
            is_expected.not_to contain_file('/etc/sysconfig/chronyd')
            is_expected.not_to contain_file('/etc/default/chrony')
          end
        end
      end

      context 'empty allow and deny' do
        let(:params) do
          {
            queryhosts: [''],
            denyqueryhosts: [''],
          }
        end

        it { is_expected.to contain_file(config_file).with_content(%r{^\s*allow\s*$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^\s*deny\s*$}) }
      end

      context 'unmanaged chrony.keys file' do
        let(:params) do
          {
            config_keys_manage: false,
            chrony_password: 'unset',
          }
        end

        it { is_expected.to contain_file(keys_file).with_replace(false) }
        it { is_expected.to contain_file(keys_file).with_content(sensitive('')) }
      end

      context 'hwtimestamps as hash' do
        let(:params) do
          {
            hwtimestamps: { 'eth0' => ['minpoll 1', 'maxpoll 7'] },
          }
        end

        it { is_expected.to contain_file(config_file).with_content(%r{^\s*hwtimestamp eth0 minpoll 1 maxpoll 7$}) }
      end

      context 'unmanaged chrony.keys file and password' do
        let(:params) do
          {
            config_keys_manage: false,
          }
        end

        it { is_expected.to raise_error(%r{Setting \$config_keys_manage false and \$chrony_password at same time in chrony is not possible}) }
      end

      context 'chrony::service' do
        let(:params) do
          {
            service_ensure: 'running',
            service_enable: true,
            service_manage: true,
          }
        end

        case facts[:os]['family']
        when 'RedHat', 'Suse', 'Archlinux'
          context 'using defaults' do
            it do
              is_expected.to contain_service('chrony-wait.service').with(
                ensure: 'stopped',
                enable: false,
              )
            end
          end
        else
          context 'using defaults' do
            it do
              is_expected.not_to contain_service('chrony-wait.service')
            end
          end
        end

        context 'using defaults' do
          it do
            is_expected.to contain_service('chronyd').with(
              ensure: 'running',
              enable: true,
            )
          end
        end
      end

      context 'with wait_manage false' do
        let(:params) do
          { wait_manage: false }
        end

        it do
          is_expected.not_to contain_service('chrony-wait.service')
        end
      end

      context 'with wait_enable true' do
        let(:params) do
          { wait_enable: true }
        end

        case facts[:os]['family']
        when 'RedHat', 'Suse', 'Archlinux'
          it do
            is_expected.to contain_service('chrony-wait.service').with(
              ensure: 'stopped',
              enable: true,
            )
          end
        else
          it do
            is_expected.not_to contain_service('chrony-wait.service')
          end
        end
      end

      context 'with wait_ensure running' do
        let(:params) do
          { wait_ensure: 'running' }
        end

        case facts[:os]['family']
        when 'RedHat', 'Suse', 'Archlinux'
          it do
            is_expected.to contain_service('chrony-wait.service').with(
              ensure: 'running',
              enable: false,
            )
          end
        else
          it do
            is_expected.not_to contain_service('chrony-wait.service')
          end
        end
      end

      context 'disable local_stratum' do
        let(:params) do
          {
            local_stratum: false,
          }
        end

        it { is_expected.not_to contain_file(config_file).with_content(%r{^\s*local stratum}) }
      end

      context 'local orphan default' do
        let(:params) do
          {
            local_stratum: 10,
          }
        end

        it { is_expected.to contain_file(config_file).with_content(%r{^\s*local stratum 10$\s*$}) }
      end

      context 'local orphan enabled' do
        let(:params) do
          {
            local_stratum: 10,
            local_orphan: true,
          }
        end

        it { is_expected.to contain_file(config_file).with_content(%r{^\s*local stratum 10 orphan$\s*$}) }
      end

      context 'with sub-millisecond value for logchange' do
        let(:params) do
          {
            logchange: 0.0001,
          }
        end

        it { expect(config_file_contents.split("\n")).to include('logchange 0.0001') }
      end
    end
  end
end
