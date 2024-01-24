# === Class mediawiki::monitoring
class mediawiki::monitoring {
    if ( $facts['networking']['interfaces']['ens19'] and $facts['networking']['interfaces']['ens18'] ) {
        $address = $facts['networking']['interfaces']['ens19']['ip']
    } elsif ( $facts['networking']['interfaces']['ens18'] ) {
        $address = $facts['networking']['interfaces']['ens18']['ip6']
    } else {
        $address = $facts['networking']['ip6']
    }
    monitoring::services { 'MediaWiki Rendering':
        check_command => 'check_mediawiki',
        docs          => 'https://meta.miraheze.org/wiki/Tech:Icinga/MediaWiki_Monitoring#MediaWiki_Rendering',
        vars          => {
            host    => lookup('mediawiki::monitoring::host'),
            address => $address,
        },
    }
}
