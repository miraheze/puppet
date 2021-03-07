# == Define: gluster::logging
#
# Read log file and sends to centralised logger (e.g reads /var/log/glusterfs/glusterd.log and sends to gluster).
#
# === Parameters
#
# [file_source_options*]
#   Options for the file source for example [ '/var/log/glusterfs/glusterd.log' ].
#   This essentially reads from the log file and sends it to gluster.
#
define gluster::logging (
	Array[String] $file_source_options
) {
	syslog_ng::rewrite { 'r_application_name':
		params => {
			'type'      => 'set',
			'options'   => [
				'glusterd',
				{ 'value' => 'APPLICATION_NAME' }
			],
		},
	} ->
	syslog_ng::source { "s_file_${title}":
		params => {
			'type'    => 'file',
			'options' => $file_source_options,
		},
	} ->
	syslog_ng::log { "s_file_${title} to d_graylog_syslog_tls":
		params => [
			{
				'source' => "s_file_${title}",
			},
                        {
                            'rewrite' => 'r_application_name',
                        },
			{
				'destination' => 'd_graylog_syslog_tls',
			},
		],
	}
}
