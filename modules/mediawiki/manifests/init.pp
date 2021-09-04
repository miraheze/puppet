# class: mediawiki
class mediawiki(
    Optional[String] $branch = undef,
    Optional[String] $branch_mw_config = undef,
    Optional[Boolean] $use_memcached = undef,
) {
    include mediawiki::favicons
    include mediawiki::cron
    if lookup('mwservices', {'default_value' => false}) {
        include mediawiki::services_cron
    }
    include mediawiki::nginx
    include mediawiki::packages
    include mediawiki::logging
    include mediawiki::php
    include mediawiki::extensionsetup
    include mediawiki::servicessetup


    include mediawiki::monitoring

    if lookup(jobrunner) {
        include mediawiki::jobqueue::runner
    }

    if lookup(jobchron) {
        include mediawiki::jobqueue::chron
    }
    
    if lookup(mediawiki::remote_sync) {
        ssh_authorized_key { 'MediaWikiDeploy':
            ensure => present,
            user   => 'www-data',
            type   => 'ssh-ed25519',
            key    => 'AAAAC3NzaC1lZDI1NTE5AAAAIDktIRXHBi4hDZvb6tBrPZ0Ag6TxLbXoQ7CkisQqOY6V',
        }
    }
    
    if lookup(mediawiki::is_canary) {
        file { '/srv/mediawiki-staging/deploykey.pub':
            ensure => present,
            content => 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDktIRXHBi4hDZvb6tBrPZ0Ag6TxLbXoQ7CkisQqOY6V MediaWikiDeploy',
            owner  => 'www-data',
            group  => 'www-data',
            mode   => '0440',
        }
        
        file { '/srv/mediawiki-staging/deploykey':
            ensure => present,
            source => 'puppet:///private/mediawiki/mediawiki-deploy-key-private',
            owner  => 'www-data',
            group  => 'www-data',
            mode   => '0440',
        }
    }
    
    if lookup(mediawiki::use_staging) {
        file { [
        '/srv/mediawiki-staging',
        '/srv/mediawiki/w',
        '/srv/mediawiki/config',
    ]:
        ensure => 'directory',
        owner  => 'www-data',
        group  => 'www-data',
        mode   => '0755',
    }
    $mwclone = '/srv/mediawiki-staging/w'
    $configclone = '/srv/mediawiki-staging/config'
    file { '/usr/local/bin/deploy-mediawiki':
        ensure => 'present',
        mode   => '0755',
        source => 'puppet:///modules/mediawiki/bin/deploy-mediawiki',
    }
    exec { 'MediaWiki Config Sync':
        command     => "/usr/local/bin/deploy-mediawiki --config --servers=${lookup(mediawiki::default_sync)}",
        cwd         => '/srv/mediawiki-staging',
        refreshonly => true,
        user        => www-data,
        subscribe   => Git::Clone['MediaWiki config'],
    }
    } else {
    $mwclone = '/srv/mediawiki/w'
    $configclone = '/srv/mediawiki/config'
    }

    file { [
        '/srv/mediawiki',
        '/srv/mediawiki/cache',
        '/srv/mediawiki/dblist',
    ]:
        ensure => 'directory',
        owner  => 'www-data',
        group  => 'www-data',
        mode   => '0755',
    }

    include ::imagemagick::install

    git::clone { 'MediaWiki config':
        ensure    => 'latest',
        directory => $configclone,
        origin    => 'https://github.com/miraheze/mw-config.git',
        branch    => $branch_mw_config,
        owner     => 'www-data',
        group     => 'www-data',
        mode      => '0755',
        require   => File['/srv/mediawiki'],
    }

    git::clone { 'MediaWiki core':
        ensure             => 'latest',
        directory          => $mwclone,
        origin             => 'https://github.com/miraheze/mediawiki.git',
        branch             => $branch,
        owner              => 'www-data',
        group              => 'www-data',
        mode               => '0755',
        timeout            => '1500',
        depth              => '5',
        recurse_submodules => true,
        require            => File['/srv/mediawiki'],
    }

    git::clone { 'landing':
        ensure             => 'latest',
        directory          => '/srv/mediawiki/landing',
        origin             => 'https://github.com/miraheze/landing.git',
        branch             => 'master',
        owner              => 'www-data',
        group              => 'www-data',
        mode               => '0755',
        timeout            => '550',
        require            => File['/srv/mediawiki'],
    }

    file { '/srv/mediawiki/robots.php':
        ensure  => 'present',
        source  => 'puppet:///modules/mediawiki/robots.php',
        require => File['/srv/mediawiki'],
    }

    file { '/srv/mediawiki/sitemap.php':
        ensure  => 'present',
        source  => 'puppet:///modules/mediawiki/sitemap.php',
        require => File['/srv/mediawiki'],
    }

    file { '/srv/mediawiki/w/LocalSettings.php':
        ensure  => 'link',
        target  => '/srv/mediawiki/config/LocalSettings.php',
        owner   => 'www-data',
        group   => 'www-data',
        require => [ Git::Clone['MediaWiki config'], Git::Clone['MediaWiki core'] ],
    }

    file { '/srv/mediawiki/w/404.php':
        ensure  => 'link',
        target  => '/srv/mediawiki/config/404.php',
        owner   => 'www-data',
        group   => 'www-data',
        require => [ Git::Clone['MediaWiki config'], Git::Clone['MediaWiki core'] ],
    }

    $wikiadmin_password    = lookup('passwords::db::wikiadmin')
    $mediawiki_password    = lookup('passwords::db::mediawiki')
    $redis_password        = lookup('passwords::redis::master')
    $noreply_password      = lookup('passwords::mail::noreply')
    $mediawiki_upgradekey  = lookup('passwords::mediawiki::upgradekey')
    $mediawiki_secretkey   = lookup('passwords::mediawiki::secretkey')
    $recaptcha_secretkey   = lookup('passwords::recaptcha::secretkey')
    $matomotoken           = lookup('passwords::mediawiki::matomotoken')
    $ldap_password         = lookup('passwords::mediawiki::ldap_password')

    $global_discord_webhook_url = lookup('mediawiki::global_discord_webhook_url')

    file { '/srv/mediawiki/config/PrivateSettings.php':
        ensure  => 'present',
        content => template('mediawiki/PrivateSettings.php'),
        require => Git::Clone['MediaWiki config'],
    }

    file { '/usr/local/bin/fileLockScript.sh':
        ensure => 'present',
        mode   => '0755',
        source => 'puppet:///modules/mediawiki/bin/fileLockScript.sh',
    }

    file { '/usr/local/bin/foreachwikiindblist':
        ensure => 'present',
        mode   => '0755',
        source => 'puppet:///modules/mediawiki/bin/foreachwikiindblist',
    }
    
    file { '/usr/local/bin/mwscript':
        ensure => 'present',
        mode   => '0755',
        source => 'puppet:///modules/mediawiki/bin/mwscript.py',
    }
    $cookbooks = ['disable-puppet', 'enable-puppet', 'cycle-puppet', 'check-read-only']
    $cookbooks.each |$cookbook| {
      file {"/usr/local/bin/${cookbook}":
          ensure => 'present',
          mode   => '0755',
          source => "puppet:///modules/mediawiki/cookbooks/${cookbook}",
      }
    }

    file { '/usr/local/bin/pushServices.sh':
        ensure => 'present',
        mode   => '0755',
        source => 'puppet:///modules/mediawiki/bin/pushServices.sh',
    }
    
    file { '/srv/mediawiki/config/OAuth2.key':
        ensure  => present,
        mode    => '0755',
        source  => 'puppet:///private/mediawiki/OAuth2.key',
        require => Git::Clone['MediaWiki config'],
    }

    exec { 'ExtensionMessageFiles':
        command     => 'nice -n 15 php /srv/mediawiki/w/maintenance/mergeMessageFileList.php --wiki loginwiki --output /srv/mediawiki/config/ExtensionMessageFiles.php',
        creates     => '/srv/mediawiki/config/ExtensionMessageFiles.php',
        cwd         => '/srv/mediawiki/config',
        path        => '/usr/bin',
        environment => 'HOME=/srv/mediawiki/config',
        user        => 'www-data',
        require     => Git::Clone['MediaWiki core'],
    }

    require_package('vmtouch')

    file { '/usr/local/bin/generateVmtouch.py':
        ensure => 'present',
        mode   => '0755',
        source => 'puppet:///modules/mediawiki/bin/generateVmtouch.py',
    }

    systemd::service { 'vmtouch':
        ensure  => present,
        content => systemd_template('vmtouch'),
        restart => true,
    }

    cron { 'vmtouch':
        ensure  => present,
        command => '/usr/bin/python3 /usr/local/bin/generateVmtouch.py',
        user    => 'root',
        minute  => '0',
        hour    => '*/1',
    }

    sudo::user { 'www-data_sudo_itself':
        user       => 'www-data',
        privileges => [
            'ALL = (www-data) NOPASSWD: ALL',
        ],
    }
}
