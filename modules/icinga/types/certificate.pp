# A strict type for a certificate
type Icinga::Certificate =   Struct[{
    cert        => Optional[String[1]],
    key         => Optional[Icinga::Secret],
    cacert      => Optional[String[1]],
    insecure    => Optional[Boolean],
    cert_file   => Optional[Stdlib::Absolutepath],
    key_file    => Optional[Stdlib::Absolutepath],
    cacert_file => Optional[Stdlib::Absolutepath],
}]
