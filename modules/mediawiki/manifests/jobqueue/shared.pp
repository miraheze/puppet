# === Class mediawiki::jobqueue::shared
#
# JobQueue resources for both runner & chron
class mediawiki::jobqueue::shared (
    VMlib::Ensure $ensure = present,
    String        $version,
) {
    if !defined(Package['composer']) {
        stdlib::ensure_packages(
            'composer',
            {
                ensure => absent,
            },
        )
    }

    if versioncmp($version, '1.40') >= 0 {
        $runner = "/srv/mediawiki/${version}/maintenance/run.php "
    } else {
        $runner = ''
    }

    git::clone { 'JobRunner':
        ensure    => $ensure,
        directory => '/srv/jobrunner',
        origin    => 'https://github.com/miraheze/jobrunner-service',
        branch    => 'miraheze',
        owner     => 'www-data',
        group     => 'www-data',
    }

    $redis_password = lookup('passwords::redis::master')
    $redis_server_ip = lookup('mediawiki::jobqueue::runner::redis_ip', {'default_value' => false})

    if lookup('jobrunner::intensive', {'default_value' => false}) {
        $config = 'jobrunner-hi.json.erb'
    } else {
        $config = 'jobrunner.json.erb'
    }

    file { '/srv/jobrunner/jobrunner.json':
        ensure  => $ensure,
        content => template("mediawiki/${config}"),
        require => Git::Clone['JobRunner'],
    }

    file { '/srv/jobrunner/jobchron.json':
        ensure  => $ensure,
        content => template('mediawiki/jobchron.json.erb'),
        require => Git::Clone['JobRunner'],
    }
}
