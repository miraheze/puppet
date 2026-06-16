# @summary
#   Logging options data type for the IcingaDB process.
#
type IcingaDB::LoggingOptions = Hash[
  Enum[
    'config-sync','database','dump-signals',
    'heartbeat','high-availability',
    'history-sync','overdue-sync','redis',
    'retention','runtime-updates','telemetry'
  ],
  Enum['fatal','error','warn','info','debug']
]
