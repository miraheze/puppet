<?php

$databaseJsonFileName = '/srv/mediawiki/cache/databases.json';
$databasesArray = file_exists( $databaseJsonFileName ) ?
	json_decode( file_get_contents( $databaseJsonFileName ), true ) : [ 'combi' => [] ];

if ( $databasesArray['combi'] ) {
	if ( preg_match( '/^(.+)\.miraheze\.org$/', $_SERVER['HTTP_HOST'], $matches ) ) {
		$wiki = "{$matches[1]}wiki";
		if ( !isset( $databasesArray['combi']["{$wiki}"] ) ) {
			return;
		}

		header( "Location: https://static.miraheze.org/{$wiki}/sitemaps/sitemap.xml", true, 302 );
	} else {
		$customDomainFound = false;
		$suffixes = [ 'wiki' ];
		$suffixMatch = array_flip( [ 'miraheze.org' => 'wiki' ] );
		foreach ( $databasesArray['combi'] as $db => $data ) {
			foreach ( $suffixes as $suffix ) {
				if ( substr( $db, -strlen( $suffix ) == $suffix ) ) {
					$url = $data['u'] ?? 'https://' . substr( $db, 0, -strlen( $suffix ) ) . '.' . $suffixMatch[$suffix];

					if ( !$url ) {
						continue;
					}

					if ( $url === "https://{$_SERVER['HTTP_HOST']}" ) {
						$customDomainFound = $db;
					}
				}
			}

			continue;
		}

		if ( $customDomainFound ) {
			header( "Location: https://static.miraheze.org/{$customDomainFound}/sitemaps/sitemap.xml", true, 302 );
		}
	}
}

exit();
