# == Define mediawiki::periodic_job
#
# Helper for defining MediaWiki jobs as systemd timers.
#
# == Parameters
#
# [*command*] The command to execute
#
# [*interval*] The frequency with which the job must be executed, expressed as
#              one of the Calendar expressions accepted by systemd. See systemd.time(7)
#
# [*splay*] Sets a maximum delay to wait before starting the timer
#
# [*ensure*] Either 'present' or 'absent'. Default: present
#
define mediawiki::periodic_job (
    String $command,
    Variant[
        Systemd::Timer::Interval,
        Systemd::Timer::Datetime
    ] $interval,
    VMlib::Ensure $ensure = present,
    Optional[Integer] $splay = undef,
) {
    systemd::timer::job { "mediawiki_job_${title}":
        ensure                  => $ensure,
        description             => "MediaWiki periodic job ${title}",
        command                 => $command,
        interval                => {'start' => 'OnCalendar', 'interval' => $interval},
        user                    => 'www-data',
        logfile_basedir         => '/var/log/mediawiki',
        logfile_group           => 'www-data',
        syslog_identifier       => "mediawiki_job_${title}",
        splay                   => $splay,
        send_mail               => true,
        send_mail_only_on_error => false,
        send_mail_to            => 'root@wikitide.net',
    }
}
