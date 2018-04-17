require 'spec_helper_acceptance'

describe 'concat_file ensure_newline parameter' do
  basedir = default.tmpdir('concat')
  context 'when false' do
    before(:all) do
      pp = <<-MANIFEST
        file { '#{basedir}':
          ensure => directory
        }
      MANIFEST

      apply_manifest(pp)
    end
    pp = <<-MANIFEST
      concat_file { '#{basedir}/file':
        ensure_newline => false,
      }
      concat_fragment { '1':
        target  => '#{basedir}/file',
        content => '1',
      }
      concat_fragment { '2':
        target  => '#{basedir}/file',
        content => '2',
      }
    MANIFEST

    it 'applies the manifest twice with no stderr' do
      apply_manifest(pp, catch_failures: true)
      apply_manifest(pp, catch_changes: true)
    end

    describe file("#{basedir}/file") do
      it { is_expected.to be_file }
      its(:content) { is_expected.to match '12' }
    end
  end

  context 'when true' do
    pp = <<-MANIFEST
      concat_file { '#{basedir}/file':
        ensure_newline => true,
      }
      concat_fragment { '1':
        target  => '#{basedir}/file',
        content => '1',
      }
      concat_fragment { '2':
        target  => '#{basedir}/file',
        content => '2',
      }
    MANIFEST

    it 'applies the manifest twice with no stderr' do
      apply_manifest(pp, catch_failures: true)
      apply_manifest(pp, catch_changes: true)
    end

    describe file("#{basedir}/file") do
      it { is_expected.to be_file }
      its(:content) do
        is_expected.to match %r{1\n2\n}
      end
    end
  end
end
