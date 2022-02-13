# === Class mediawiki::monitoring
class mediawiki::monitoring {
    monitoring::services { 'MediaWiki Rendering':
        check_command => 'check_mediawiki',
        vars          => {
            host    => 'login.miraheze.org',
            address => $facts['ipaddress'],
        },
    }
}
