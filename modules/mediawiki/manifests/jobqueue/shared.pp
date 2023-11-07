# === Class mediawiki::jobqueue::shared
#
# JobQueue resources for both runner & chron
class mediawiki::jobqueue::shared {
    if !defined(Package['composer']) {
        stdlib::ensure_packages('composer')
    }

    git::clone { 'JobRunner':
        ensure    => latest,
        directory => '/srv/jobrunner',
        origin    => 'https://github.com/miraheze/jobrunner-service',
        branch    => 'miraheze',
        owner     => 'www-data',
        group     => 'www-data',
    }

    exec { 'jobrunner_composer':
        command     => 'composer install --no-dev',
        creates     => '/srv/jobrunner/vendor',
        cwd         => '/srv/jobrunner',
        path        => '/usr/bin',
        environment => [
            'HOME=/srv/jobrunner',
            'HTTP_PROXY=http://bast.miraheze.org:8080'
        ],
        user        => 'www-data',
        require     => Git::Clone['JobRunner'],
    }

    $redis_password = lookup('passwords::redis::master')
    $redis_server_ip = lookup('mediawiki::jobqueue::runner::redis_ip', {'default_value' => '[2a10:6740::6:306]:6379'})

    if lookup('jobrunner::intensive', {'default_value' => false}) {
        $config = 'jobrunner-hi.json.erb'
    } else {
        $config = 'jobrunner.json.erb'
    }

    file { '/srv/jobrunner/jobrunner.json':
        ensure  => present,
        content => template("mediawiki/${config}"),
        require => Git::Clone['JobRunner'],
    }

    file { '/srv/jobrunner/jobchron.json':
        ensure  => present,
        content => template('mediawiki/jobchron.json.erb'),
        require => Git::Clone['JobRunner'],
    }
}
