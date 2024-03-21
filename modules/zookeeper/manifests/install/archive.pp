# Class: zookeeper::install::archive
#
# This module manages archive installation
#
# PRIVATE CLASS - do not use directly (use main `zookeeper` class).
class zookeeper::install::archive inherits zookeeper::install {
  # Apache updated the filename base for archive files in release 3.5.5
  if versioncmp($zookeeper::archive_version, '3.5.5') >= 0 {
    $filename = "apache-${module_name}-${zookeeper::archive_version}-bin"
    $archive_dl_site = $zookeeper::archive_dl_site ? {
      undef   => 'https://downloads.apache.org/zookeeper',
      default => $zookeeper::archive_dl_site,
    }
  } else {
    $filename = "${module_name}-${zookeeper::archive_version}"
    $archive_dl_site = $zookeeper::archive_dl_site ? {
      undef   => 'http://archive.apache.org/dist/zookeeper',
      default => $zookeeper::archive_dl_site,
    }
  }

  $download_url = $zookeeper::archive_dl_url ? {
    undef   => "${archive_dl_site}/${module_name}-${zookeeper::archive_version}/${filename}.tar.gz",
    default => $zookeeper::archive_dl_url,
  }

  $archive_file = "${zookeeper::archive_install_dir}/${filename}.tar.gz"

  archive { $archive_file:
    ensure        => present,
    user          => 'root',
    group         => 'root',
    source        => $download_url,
    checksum      => $zookeeper::archive_checksum['hash'],
    checksum_type => $zookeeper::archive_checksum['type'],
    extract_path  => $zookeeper::archive_install_dir,
    username      => $zookeeper::repo_user,
    password      => $zookeeper::repo_password,
    # Extract files as the user doing the extracting, which is the user
    # that runs Puppet, usually root
    extract_flags => '-x --no-same-owner -f',
    creates       => "${zookeeper::archive_install_dir}/${filename}",
    extract       => true,
    cleanup       => true,
    notify        => Exec['chown_zookeeper_directory'],
  }

  if $zookeeper::proxy_server {
    Archive<| title == $archive_file |> {
      proxy_server => $zookeeper::proxy_server,
      proxy_type   => $zookeeper::proxy_type,
    }
  }

  $symlink_require = Archive["${zookeeper::archive_install_dir}/${filename}.tar.gz"]

  exec { 'chown_zookeeper_directory':
    command     => "chown -R ${zookeeper::user}:${zookeeper::group} ${zookeeper::archive_install_dir}/${filename}",
    path        => ['/bin','/sbin'],
    refreshonly => true,
    require     => $symlink_require,
  }

  if $zookeeper::archive_symlink {
    file { $zookeeper::archive_symlink_name:
      ensure  => link,
      require => $symlink_require,
      target  => "${zookeeper::archive_install_dir}/${filename}",
      owner   => $zookeeper::user,
      group   => $zookeeper::group,
    }
  }

  # directory is required for creating conf subdirectory
  if $zookeeper::zk_dir {
    file { $zookeeper::zk_dir:
      ensure => directory,
      owner  => $zookeeper::user,
      group  => $zookeeper::group,
    }
  }
}
