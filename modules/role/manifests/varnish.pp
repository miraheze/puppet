class role::varnish {
  include ::varnish

  ufw::allow { 'http port tcp':
      proto => 'tcp',
      port  => 80,
  }

  ufw::allow { 'https port tcp':
      proto => 'tcp',
      port  => 443,
  }
  motd::role { 'role::varnish':
    description => 'Varnish caching server',
  }
}
