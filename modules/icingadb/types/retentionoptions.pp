# @summary
#   Data type for retention options of the connection to
#   the IcingaDB database.
type IcingaDB::RetentionOptions = Hash[
  Enum[
    'acknowledgement','comment','downtime',
    'flapping','notification','state'
  ],
  Integer[1]
]
