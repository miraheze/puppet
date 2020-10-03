class syslog_ng::repo {
  if $syslog_ng::manage_repo {
    $major_release = $facts['os']['release']['major']

    case $facts['os']['family'] {
      'Redhat', 'Amazon': {
        yumrepo { 'czanik-syslog-ng-githead':
          ensure   => present,
          name     => 'czanik-syslog-ng-githead',
          descr    => 'Copr repo for syslog-ng-githead owned by czanik',
          baseurl  => "https://copr-be.cloud.fedoraproject.org/results/czanik/syslog-ng-githead/epel-${major_release}-\$basearch/",
          gpgkey   => 'https://copr-be.cloud.fedoraproject.org/results/czanik/syslog-ng-githead/pubkey.gpg',
          enabled  => '1',
          gpgcheck => '1',
          target   => '',
          before   => Package[$syslog_ng::package_name],
        }
      }
      'Debian': {
        $release_url_suffix = $facts['os']['name'] ? {
          'Debian' => $major_release ? {
            '10' => "Debian_${major_release}",
            default => "Debian_${major_release}.0",
          },
          'Ubuntu' => "xUbuntu_${major_release}",
        }
        $release_url = "http://download.opensuse.org/repositories/home:/laszlo_budai:/syslog-ng/${release_url_suffix}"

        apt::source { 'syslog-ng-obs':
          comment  => 'syslog-ng unofficial repository, https://www.syslog-ng.com/community/b/blog/posts/installing-the-latest-syslog-ng-on-ubuntu-and-other-deb-distributions',
          location => $release_url,
          release  => '',
          repos    => './',
          key      => {
            ensure => 'refreshed',
            id     => 'F20F51628D04901AD01175013B92A8D27CFDAEDD',
            source => "${release_url}/Release.key",
          },
          include  => {
            deb => true,
            src => false,
          },
        }

        Class['apt::update'] -> Package <| tag == 'syslog_ng' |>
      }
      default: {}
    }
  }
}
