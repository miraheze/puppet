# == Define: puppetserver::logging
#
# Read log file and sends to centralised logger.
#
# === Parameters
#
# [file_path*]
#   Path where to save logging config.
#
# [file_source*]
#   Puppet file source.
#
# [file_source_options*]
#   Options for the file source for example [ '/var/log/syslog' ].
#   This essentially reads from the log file and sends it to gluster.
#
# [program_name*]
#   This sets the program name. Sometimes the log is parsed wrong and the
#   program name is set wrong. This corrects the issue.
#
define puppetserver::logging (
  String $file_path,
  String $file_source,
  Array  $file_source_options,
  String $program_name,
) {

  file { $file_path:
    ensure => present,
    source => $file_source,
  }

  syslog_ng::rewrite { "r_program_${program_name}":
    params => {
      'type'    => 'set',
      'options' => [
        $program_name,
        { 'value' => 'PROGRAM' }
      ],
    },
  }
  -> syslog_ng::source { "s_file_${title}":
    params => {
      'type'    => 'file',
      'options' => $file_source_options,
    },
  }
  -> syslog_ng::log { "s_file_${title} to d_graylog_syslog_tls":
    params => [
      {
        'source' => "s_file_${title}",
      },
      {
        'rewrite' => "r_program_${program_name}",
      },
      {
        'destination' => 'd_graylog_syslog_tls',
      },
    ],
  }
}
