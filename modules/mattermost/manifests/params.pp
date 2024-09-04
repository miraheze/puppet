# See README.md.
class mattermost::params {
  $fail_msg =
    "OS ${facts['os']['name']} ${facts['os']['release']['full']} is not supported"
  $install_from_pkg = false
  $pkg = 'mattermost-server'
  $base_url = 'https://releases.mattermost.com'
  $edition = 'team'
  $version = '5.21.0'
  $filename = 'mattermost-__EDITION__-__VERSION__-linux-amd64.tar.gz'
  $full_url = '__PLACEHOLDER__'
  $dir = '/opt/mattermost-__VERSION__'
  $symlink = '/opt/mattermost'
  $conf = '/etc/mattermost.json'
  $create_user = true
  $create_group = true
  $user = 'mattermost'
  $group = 'mattermost'
  $uid = '1500'
  $gid = '1500'
  $override_options = {}
  $override_env_options = {}
  $manage_data_dir = true
  $manage_log_dir = true
  $depend_service = ''
  $install_service = true
  $manage_service = true
  $service_name = 'mattermost'
  $purge_conf = false
  $purge_env_conf = false
  case $facts['os']['family'] {
    'Archlinux': {
      $env_conf = '/etc/default/mattermost'
      $service_template = 'mattermost/systemd.erb'
      $service_path     = '/etc/systemd/system/__SERVICENAME__.service'
      $service_provider = 'systemd'
      $service_mode     = ''
    }
    'Debian': {
      $env_conf = '/etc/default/mattermost'
      case $facts['os']['name'] {
        'Debian': {
          case $facts['os']['release']['major'] {
            '8','9','10': {
              $service_template = 'mattermost/systemd.erb'
              $service_path     = '/etc/systemd/system/__SERVICENAME__.service'
              $service_provider = ''
              $service_mode     = ''
            }
            default: { fail($fail_msg) }
          }
        }
        'Ubuntu': {
          case $facts['os']['release']['major'] {
            '14.04': {
              $service_template = 'mattermost/upstart.erb'
              $service_path     = '/etc/init/__SERVICENAME__.conf'
              $service_provider = 'upstart'
              $service_mode     = ''
            }
            '16.04', '18.04', '19.10': {
              $service_template = 'mattermost/systemd.erb'
              $service_path     = '/etc/systemd/system/__SERVICENAME__.service'
              $service_provider = 'systemd'
              $service_mode     = ''
            }
            default: { fail($fail_msg) }
          }
        }
        default: { fail($fail_msg) }
      }
    }
    'RedHat': {
      $env_conf = '/etc/sysconfig/mattermost'
      case $facts['os']['release']['major'] {
        '6': {
          $service_template = 'mattermost/sysvinit_el.erb'
          $service_path     = '/etc/init.d/__SERVICENAME__'
          $service_provider = ''
          $service_mode     = '0755'
        }
        '7','8': {
          $service_template = 'mattermost/systemd.erb'
          $service_path     = '/etc/systemd/system/__SERVICENAME__.service'
          $service_provider = ''
          $service_mode     = ''
        }
        default: { fail($fail_msg) }
      }
    }
    'Suse': {
      $env_conf = '/etc/sysconfig/mattermost'
      case $facts['os']['name'] {
        'SLES': {
          case $facts['os']['release']['major'] {
            '12', '15': {
              $service_template = 'mattermost/systemd.erb'
              $service_path     = '/etc/systemd/system/__SERVICENAME__.service'
              $service_provider = 'systemd'
              $service_mode     = ''
            }
            default: { fail($fail_msg) }
          }
        }
        default: { fail($fail_msg) }
      }
    }
    default: { fail($fail_msg) }
  }
}
