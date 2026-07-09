# @summary
#   Data type for options to connect the IcingaDB database.
#
type IcingaDB::DBOptions = Hash[
  Enum[
    'max_connections',
    'max_connections_per_table',
    'max_placeholders_per_statement',
    'max_rows_per_transaction',
    'wsrep_sync_wait'
  ], Integer[0]
]
