class role::mediawiki::php::restarts (
  VMlib::Ensure $ensure = lookup('role::mediawiki::php::restarts::ensure'),
  Integer $opcache_limit = lookup('role::mediawiki::php::restarts::opcache_limit'),
) {

  stdlib::ensure_packages(['python3-pyotp'])

  # Check, then restart php-fpm if needed.
  # This implicitly depends on the other MediaWiki/PHP profiles
  # Setting $opcache_limit to 0 will replace the script with a noop and thus disable restarts
  if $opcache_limit == 0 {
    file { '/usr/local/sbin/check-and-restart-php':
      ensure  => present,
      owner   => 'root',
      group   => 'root',
      mode    => '0555',
      content => "#!/bin/sh\nexit 0"
    }
  } else {
    file { '/usr/local/sbin/check-and-restart-php':
      ensure => $ensure,
      owner  => 'root',
      group  => 'root',
      mode   => '0555',
      source => 'puppet:///modules/role/mediawiki/php/php-check-and-restart.sh',
    }
  }

  $mediawiki_hosts = query_facts("Class['Role::Mediawiki']", ['networking'])
  $mediawiki_nodes = $mediawiki_hosts.keys().flatten().unique().sort()

  $varnish_totp_secret = lookup('passwords::varnish::varnish_totp_secret')
  file { '/usr/local/bin/safe-service-restart':
    ensure => present,
    owner  => 'root',
    group  => 'root',
    mode   => '0555',
    source => 'puppet:///modules/role/mediawiki/safe-service-restart.py'
  }

  base::safe_service_restart{ 'php8.2-fpm':
    nodes => $mediawiki_nodes,
  }

  if member($mediawiki_nodes, $facts['networking']['fqdn']) {
    $times = cron_splay($mediawiki_nodes, 'daily', 'php8.2-fpm-opcache-restarts')
  } else {
    $times =  { 'OnCalendar' => sprintf('*-*-* %02d:00:00', fqdn_rand(24)) }
  }

  # Using a systemd timer should ensure we can track if the job fails
  systemd::timer::job { 'php8.2-fpm_check_restart':
    ensure            => $ensure,
    description       => 'Cronjob to check the status of the opcache space on PHP8, and restart the service if needed',
    command           => "/usr/local/sbin/check-and-restart-php php8.2-fpm ${opcache_limit}",
    interval          => {'start' => 'OnCalendar', 'interval' => $times['OnCalendar']},
    user              => 'root',
    logfile_basedir   => '/var/log/mediawiki',
    syslog_identifier => 'php8.2-fpm_check_restart'
  }
}
