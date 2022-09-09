class { 'icinga::repos':
  manage_epel              => true,
  manage_powertools        => true,
  manage_server_monitoring => true,
}
