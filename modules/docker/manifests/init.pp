# class: docker
class docker {
  file { '/etc/apt/keyrings/docker.gpg':
    ensure => present,
    source => 'puppet:///modules/docker/key/docker.gpg',
  }

  apt::source { 'docker_apt':
    location => 'https://download.docker.com/linux/debian',
    comment  => 'Docker stable',
    release  => $facts['os']['distro']['codename'],
    repos    => 'stable',
    keyring  => '/etc/apt/keyrings/docker.gpg',
    require  => File['/etc/apt/keyrings/docker.gpg'],
    notify   => Exec['apt_update_docker'],
  }

  exec { 'apt_update_docker':
    command     => '/usr/bin/apt-get update',
    refreshonly => true,
    logoutput   => true,
  }

  package { ['docker-ce', 'docker-ce-cli', 'containerd.io', 'docker-compose-plugin']:
    ensure  => present,
    require => [
      Apt::Source['docker_apt'],
      Exec['apt_update_docker'],
    ],
  }

  $http_proxy = lookup('http_proxy', {'default_value' => undef})
  if $http_proxy {
    file { '/root/.docker':
      ensure => directory,
    }

    file { '/root/.docker/config.json':
      ensure  => present,
      content => epp('docker/config.json.epp', {
        'http_proxy' => $http_proxy,
      })
    }

    file { '/etc/docker/daemon.json':
      ensure => present,
      content => epp('docker/daemon-config.json.epp', {
        'http_proxy' => $http_proxy,
      })
    }
  }

  service { 'docker':
    ensure  => running,
    enable  => true,
    require => Package['docker-ce'],
  }
}
