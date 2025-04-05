# SPDX-License-Identifier: Apache-2.0
type Haproxy::Ring = Struct[{
    'name'               => String,
    'format'             => Enum['raw', 'rfc5424'],
    'timeout_connect_ms' => Integer,
    'timeout_server_ms'  => Integer,
    'backend_name'       => String,
    'backend_prefix'     => Optional[Enum['ipv4', 'ipv6', 'unix']],
    'backend_address'    => String,
    'backend_log_proto'  => Enum['legacy', 'octet-count'],
}]
