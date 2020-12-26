<?php

header( 'Content-Type: text/plain' );

$databaseJsonFileName = '/srv/mediawiki/w/cache/databases.json';
$databasesArray = file_exists( $databaseJsonFileName ) ?
	json_decode( file_get_contents( $$databaseJsonFileName ), true ) : [];

# Disallow API and special pages
echo "# Disallow API and special pages" . "\r\n";
echo "User-agent: *" . "\r\n";
echo "Disallow: /w/api.php" . "\r\n";
echo "Disallow: /w/index.php?title=Special:" . "\r\n";
echo "Disallow: /wiki/Special:" . "\r\n\n";

# Throttle YandexBot
echo "# Throttle YandexBot" . "\r\n";
echo "User-Agent: YandexBot" . "\r\n";
echo "Crawl-Delay: 2.5" . "\r\n\n";

# Throttle BingBot
echo "#Throttle BingBot" . "\r\n";
echo "User-agent: bingbot" . "\r\n";
echo "Crawl-delay: 1" . "\r\n";

# Block SemrushBot
echo "# Block SemrushBot" . "\r\n";
echo "User-Agent: SemrushBot" . "\r\n";
echo "Disallow: /" . "\r\n\n";

if ( isset( $databasesArray['combi'] ) && $databasesArray['combi'] ) {
	$wikis = array_keys( $databasesArray['combi'] );
	if ( preg_match( '/^(.+)\.miraheze\.org$/', $_SERVER['HTTP_HOST'], $matches ) ) {
		if ( !isset( $wikis["{$matches[0]}wiki"] ) ) {
			return;
		}

		# Dynamic sitemap url
		echo "# Dynamic sitemap url" . "\r\n";
		echo "Sitemap: https://static.miraheze.org/{$wikis["{$matches[0]}wiki"]}/sitemaps/sitemap.xml" . "\r\n\n";
	} else {
		$customDomainFound = false;
		$suffixes = [ 'wiki' ];
		$suffixMatch = array_flip( [ 'miraheze.org' => 'wiki' ] );
		foreach ( $databasesArray['combi'] as $db => $data ) {
			foreach ( $suffixes as $suffix ) {
				if ( substr( $db, -strlen( $suffix ) == $suffix ) ) {
					if ( 'https://' . substr( $db, 0, -strlen( $suffix ) ) === $_SERVER['HTTP_HOST'] ) {
						$customDomainFound = $db;
						return;
					}
				}
			}

			continue;
		}
		
		if ( $customDomainFound ) {
			# Dynamic sitemap url
			echo "# Dynamic sitemap url" . "\r\n";
			echo "Sitemap: https://static.miraheze.org/{$customDomainFound}/sitemaps/sitemap.xml" . "\r\n\n";
		}
	}
}
