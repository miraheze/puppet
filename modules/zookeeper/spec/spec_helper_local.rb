def get_os_info(facts)
  info = {
    service_name: nil,
    environment_file: nil,
    should_install_zookeeperd: nil,
    init_provider: nil,
    init_dir: nil,
    service_file: nil,
    should_install_cron: false,
    zookeeper_shell: nil,
  }

  case facts[:osfamily]
  when 'Debian'
    info[:service_name] = 'zookeeper'
    info[:environment_file] = '/etc/zookeeper/conf/environment'
    info[:should_install_zookeeperd] = true
    info[:zookeeper_shell] = '/bin/false'
    info[:init_provider] = 'systemd'
  when 'RedHat'
    info[:service_name] = 'zookeeper-server'
    info[:environment_file] = '/etc/zookeeper/conf/java.env'
    info[:should_install_zookeeperd] = false
    info[:zookeeper_shell] = '/sbin/nologin'
    info[:init_provider] = if Puppet::Util::Package.versioncmp(facts[:os]['release']['major'], '7') < 0
                             'redhat'
                           else
                             'systemd'
                           end
  when 'Suse'
    info[:service_name] = 'zookeeper-server'
    info[:environment_file] = '/etc/zookeeper/conf/java.env'
    info[:should_install_zookeeperd] = false
    info[:zookeeper_shell] = '/bin/false'
    info[:init_provider] = 'systemd'
  end

  case info[:init_provider]
  when 'init'
    info[:init_dir] = '/etc/init.d'
  when 'systemd'
    info[:init_dir] = '/etc/systemd/system'
  when 'redhat'
    info[:init_dir] = '/etc/init.d'
  end

  info[:service_file] = if info[:init_provider] == 'systemd'
                          "#{info[:init_dir]}/#{info[:service_name]}.service"
                        else
                          "#{info[:init_dir]}/#{info[:service_name]}"
                        end

  info
end
