class profile::default {
  # Firewall
  Firewall {
    before  => Class['my_fw::post'],
    require => Class['my_fw::pre'],
  }
  class { ['my_fw::pre', 'my_fw::post']: }
  class { 'firewall': }
  firewall { '100 allow http and https access':
      dport  => [80, 443],
      proto  => tcp,
      action => accept,
  }
}
