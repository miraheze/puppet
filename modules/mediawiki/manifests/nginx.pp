# MediaWiki nginx config using hiera
class mediawiki::nginx {
    $sslcerts = hiera_hash('ssl')

    nginx::site { 'mediawiki':
        ensure    => present,
        content   => template('mediawiki/mediawiki.conf'),
    }
}
