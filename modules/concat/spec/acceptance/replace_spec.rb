require 'spec_helper_acceptance'

describe 'replacement of' do
  basedir = default.tmpdir('concat')
  context 'when file should not succeed' do
    before(:all) do
      pp = <<-MANIFEST
          file { '#{basedir}':
            ensure => directory,
          }
          file { '#{basedir}/file':
            content => "file exists\n"
          }
        MANIFEST
      apply_manifest(pp)
    end
    pp = <<-MANIFEST
        concat { '#{basedir}/file':
          replace => false,
        }

        concat::fragment { '1':
          target  => '#{basedir}/file',
          content => '1',
        }

        concat::fragment { '2':
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
        is_expected.to match 'file exists'
      end
      its(:content) do
        is_expected.not_to match '1'
      end
      its(:content) do
        is_expected.not_to match '2'
      end
    end
  end

  context 'when file should succeed' do
    before(:all) do
      pp = <<-MANIFEST
          file { '#{basedir}':
            ensure => directory,
          }
          file { '#{basedir}/file':
            content => "file exists\n"
          }
        MANIFEST
      apply_manifest(pp)
    end
    pp = <<-MANIFEST
        concat { '#{basedir}/file':
          replace => true,
        }

        concat::fragment { '1':
          target  => '#{basedir}/file',
          content => '1',
        }

        concat::fragment { '2':
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
        is_expected.not_to match 'file exists'
      end
      its(:content) do
        is_expected.to match '1'
      end
      its(:content) do
        is_expected.to match '2'
      end
    end
  end

  context 'when symlink should not succeed', unless: (fact('osfamily') == 'windows') do
    # XXX the core puppet file type will replace a symlink with a plain file
    # when using ensure => present and source => ... but it will not when using
    # ensure => present and content => ...; this is somewhat confusing behavior
    before(:all) do
      pp = <<-MANIFEST
          file { '#{basedir}':
            ensure => directory,
          }
          file { '#{basedir}/file':
            ensure => link,
            target => '#{basedir}/dangling',
          }
        MANIFEST
      apply_manifest(pp)
    end

    pp = <<-MANIFEST
        concat { '#{basedir}/file':
          replace => false,
        }

        concat::fragment { '1':
          target  => '#{basedir}/file',
          content => '1',
        }

        concat::fragment { '2':
          target  => '#{basedir}/file',
          content => '2',
        }
      MANIFEST

    it 'applies the manifest twice with no stderr' do
      apply_manifest(pp, catch_failures: true)
      apply_manifest(pp, catch_changes: true)
    end

    # XXX specinfra doesn't support be_linked_to on AIX
    describe file("#{basedir}/file"), unless: (fact('osfamily') == 'AIX' || fact('osfamily') == 'windows') do
      it { is_expected.to be_linked_to "#{basedir}/dangling" }
    end

    describe file("#{basedir}/dangling") do
      # XXX serverspec does not have a matcher for 'exists'
      it { is_expected.not_to be_file }
      it { is_expected.not_to be_directory }
    end
  end

  context 'when symlink should succeed', unless: (fact('osfamily') == 'windows') do
    # XXX the core puppet file type will replace a symlink with a plain file
    # when using ensure => present and source => ... but it will not when using
    # ensure => present and content => ...; this is somewhat confusing behavior
    before(:all) do
      pp = <<-MANIFEST
          file { '#{basedir}':
            ensure => directory,
          }
          file { '#{basedir}/file':
            ensure => link,
            target => '#{basedir}/dangling',
          }
        MANIFEST
      apply_manifest(pp)
    end

    pp = <<-MANIFEST
        concat { '#{basedir}/file':
          replace => true,
        }

        concat::fragment { '1':
          target  => '#{basedir}/file',
          content => '1',
        }

        concat::fragment { '2':
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
        is_expected.to match '1'
      end
      its(:content) do
        is_expected.to match '2'
      end
    end
  end

  context 'when directory should not succeed' do
    before(:all) do
      pp = <<-MANIFEST
          file { '#{basedir}':
            ensure => directory,
          }
          file { '#{basedir}/file':
            ensure => directory,
          }
        MANIFEST
      apply_manifest(pp)
    end
    pp = <<-MANIFEST
        concat { '#{basedir}/file': }

        concat::fragment { '1':
          target  => '#{basedir}/file',
          content => '1',
        }

        concat::fragment { '2':
          target  => '#{basedir}/file',
          content => '2',
        }
      MANIFEST

    i = 0
    num = 2
    while i < num
      it 'applies the manifest twice with stderr for changing to file' do
        expect(apply_manifest(pp, expect_failures: true).stderr).to match(%r{change from '?directory'? to '?file'? failed})
      end
      i += 1
    end

    describe file("#{basedir}/file") do
      it { is_expected.to be_directory }
    end
  end

  # XXX
  # when there are no fragments, and the replace param will only replace
  # files and symlinks, not directories.  The semantics either need to be
  # changed, extended, or a new param introduced to control directory
  # replacement.
  context 'when directory should succeed', pending: 'not yet implemented' do
    pp = <<-MANIFEST
        concat { '#{basedir}/file':
        }

        concat::fragment { '1':
          target  => '#{basedir}/file',
          content => '1',
        }

        concat::fragment { '2':
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
      its(:content) { is_expected.to match '1' }
    end
  end
end
