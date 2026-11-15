node default {
  notify { 'enduser-before': }
  notify { 'enduser-after': }

  class { 'chrony':
    require => Notify['enduser-before'],
    before  => Notify['enduser-after'],
  }
}
