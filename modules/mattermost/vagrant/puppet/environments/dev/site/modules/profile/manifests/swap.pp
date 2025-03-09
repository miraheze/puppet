class profile::swap {
  # Swap file
  Service {
    require => Class['swap::config']
  }
  class { 'swap::config': }
}
