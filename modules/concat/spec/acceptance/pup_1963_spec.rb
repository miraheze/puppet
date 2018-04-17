require 'spec_helper_acceptance'

command = case fact('osfamily')
          when 'Windows'
            'cmd.exe /c echo triggered'
          else
            'echo triggered'
          end

describe 'with metaparameters' do
  describe 'with subscribed resources' do
    basedir = default.tmpdir('concat')

    context 'when run should trigger refresh' do
      pp = <<-MANIFEST
        concat { "foobar":
          ensure => 'present',
          path   => '#{basedir}/foobar',
        }

        concat::fragment { 'foo':
          target => 'foobar',
          content => 'foo',
        }

        exec { 'trigger':
          path        => $::path,
          command     => "#{command}",
          subscribe   => Concat['foobar'],
          refreshonly => true,
        }
      MANIFEST

      it 'applies the manifest twice with stdout regex first' do
        expect(apply_manifest(pp, catch_failures: true).stdout).to match(%r{Triggered 'refresh'})
      end
      it 'applies the manifest twice with stdout regex second' do
        expect(apply_manifest(pp, catch_changes: true).stdout).not_to match(%r{Triggered 'refresh'})
      end
    end
  end

  describe 'with resources to notify' do
    basedir = default.tmpdir('concat')
    context 'when run should notify' do
      pp = <<-MANIFEST
        exec { 'trigger':
          path        => $::path,
          command     => "#{command}",
          refreshonly => true,
        }

        concat { "foobar":
          ensure => 'present',
          path   => '#{basedir}/foobar',
          notify => Exec['trigger'],
        }

        concat::fragment { 'foo':
          target => 'foobar',
          content => 'foo',
        }
      MANIFEST

      it 'applies the manifest twice with stdout regex first' do
        expect(apply_manifest(pp, catch_failures: true).stdout).to match(%r{Triggered 'refresh'})
      end
      it 'applies the manifest twice with stdout regex second' do
        expect(apply_manifest(pp, catch_changes: true).stdout).not_to match(%r{Triggered 'refresh'})
      end
    end
  end
end
