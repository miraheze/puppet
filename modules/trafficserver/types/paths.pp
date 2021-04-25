type Trafficserver::Paths = Struct[{
    'sysconfdir'    => Stdlib::Absolutepath,
    'datadir'       => Stdlib::Absolutepath,
    'includedir'    => Stdlib::Absolutepath,
    'libdir'        => Stdlib::Absolutepath,
    'libexecdir'    => Stdlib::Absolutepath,
    'runtimedir'    => Stdlib::Absolutepath,
    'logdir'        => Stdlib::Absolutepath,
    'cachedir'      => Stdlib::Absolutepath,
    'records'       => Stdlib::Absolutepath,
    'ssl_multicert' => Stdlib::Absolutepath,
}]
