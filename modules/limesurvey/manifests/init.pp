# class: limesurvey
class limesurvey {
        include ::apache
        include ::apache::mod::rewrite
        include ::apache::mod::php5
        include ::apache::mod::ssl
        include ::apache::mod::expires

        git::clone { 'limesurvey git':
                directory => '/srv/surveys',
		origin	  => 'https://github.com/limesurvey/limesurvey.git',
		branch	  => '2.5',
		owner	  => 'www-data',
		group	  => 'www-data',
	}

	apache::site { 'surveys.miraheze.org':
		ensure => present,
		source => 'puppet:///modules/limesurvey/apache.conf',
	}
}
