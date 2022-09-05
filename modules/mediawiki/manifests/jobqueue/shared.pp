# === Class mediawiki::jobqueue::shared
#
# JobQueue resources for both runner & chron
class mediawiki::jobqueue::shared {

  git::clone { 'JobRunner':
      ensure    => latest,
      directory => '/srv/jobrunner',
      origin    => 'https://github.com/miraheze/jobrunner-service',
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
}
