# === Class mediawiki::monitoring
class mediawiki::monitoring {
    monitoring::services { 'MediaWiki Rendering':
        check_command => 'check_mediawiki',
        vars          => {
            host    => lookup('mediawiki::monitoring::host'),
            address => $facts['ipaddress'],
        },
    }
}
