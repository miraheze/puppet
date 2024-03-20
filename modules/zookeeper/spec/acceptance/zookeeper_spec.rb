require 'spec_helper_acceptance'

# case fact('osfamily')
# when 'Debian'
#   service_name = 'zookeeper'
# when 'RedHat', 'Suse'
#   service_name = 'zookeeper-server'
# end

describe 'zookeeper defintion' do
  context 'basic setup' do
    it 'install zookeeper' do
      case fact('osfamily')
      when 'Debian'
        pp = <<-EOS
          class { 'zookeeper': }
        EOS
      when 'RedHat'
        pp = <<-EOS
          class { 'zookeeper':
            install_java         => true,
            java_package         => 'java-1.8.0-openjdk-headless',
            initialize_datastore => true,
            service_provider     => 'redhat',
            install_method       => 'archive',
            archive_version      => '3.4.8',
          }
        EOS
      when 'Suse'
        pp = <<-EOS
          class { 'zookeeper':
            install_java         => true,
            java_package         => 'java-1_8_0-openjdk-headless',
            initialize_datastore => true,
            service_provider     => 'systemd',
          }
        EOS
      end

      expect(apply_manifest(pp,
                            catch_failures: false,
                            debug: false).exit_code).to be_zero
    end

    describe file('/etc/zookeeper') do
      it { is_expected.to be_directory }
    end

    describe file('/etc/zookeeper/conf') do
      it { is_expected.to be_directory }
    end

    describe user('zookeeper') do
      it { is_expected.to exist }
    end

    describe group('zookeeper') do
      it { is_expected.to exist }
    end

    describe command('cat /etc/zookeeper/conf/zoo.cfg') do
      its(:exit_status) { is_expected.to eq 0 }
      its(:stdout) { is_expected.to match %r{^clientPort=2181$} }
    end

    describe command('cat /etc/zookeeper/conf/myid') do
      its(:exit_status) { is_expected.to eq 0 }
      its(:stdout) { is_expected.to match %r{^1$} }
    end

    describe file('/etc/zookeeper/conf/zoo.cfg') do
      it { is_expected.to be_file }
      it { is_expected.to be_writable.by('owner') }
      it { is_expected.to be_readable.by('group') }
      it { is_expected.to be_readable.by('others') }
    end

    # testing systemd in a container is tricky

    # give zookeeper some time to boot
    # describe command('sleep 2 && netstat -tulpn') do
    #  its(:exit_status) { is_expected.to eq 0 }
    #  its(:stdout) { is_expected.to match %r{2181} }
    # end

    # describe command("/etc/init.d/#{service_name} status") do
    #   its(:exit_status) { is_expected.to eq 0 }
    #   its(:stdout) { is_expected.to match %r{running} }
    # end

    # describe command('echo stat | nc 0.0.0.0 2181') do
    #   its(:exit_status) { is_expected.to eq 0 }
    #   its(:stdout) { is_expected.to match %r{^Mode: standalone$} }
    # end
  end
end
