class my_fw::pre {
  Firewall {
    require => undef,
  }
  firewall { '000 accept all icmp':
    proto  => 'icmp',
    action => 'accept',
  }
  -> firewall { '001 accept all to lo interface':
    proto   => 'all',
    iniface => 'lo',
    action  => 'accept',
  }
  -> firewall { '003 accept related established rules':
    proto  => 'all',
    state  => ['RELATED', 'ESTABLISHED'],
    action => 'accept',
  }
  firewall { '004 Allow inbound SSH':
    dport  => 22,
    proto  => tcp,
    action => accept,
  }
}
