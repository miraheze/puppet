<?php

define( 'MW_NO_SESSION', 1 );

require_once( '/srv/mediawiki/w/includes/WebStart.php' );

use MediaWiki\MediaWikiServices;

$wikiPageFactory = MediaWikiServices::getInstance()->getWikiPageFactory();
$titleFactory = MediaWikiServices::getInstance()->getTitleFactory();

$page = $wikiPageFactory->newFromTitle( $titleFactory->newFromText( 'Robots.txt', NS_MEDIAWIKI ) );

$databaseJsonFileName = '/srv/mediawiki/cache/databases.json';
$databasesArray = file_exists( $databaseJsonFileName ) ?
	json_decode( file_get_contents( $databaseJsonFileName ), true ) : [ 'combi' => [] ];

header( 'Content-Type: text/plain; charset=utf-8' );

# Throttle YandexBot
echo "# Throttle YandexBot" . "\r\n";
echo "User-Agent: YandexBot" . "\r\n";
echo "Crawl-Delay: 2.5" . "\r\n\n";

# Throttle BingBot
echo "# Throttle BingBot" . "\r\n";
echo "User-agent: bingbot" . "\r\n";
echo "Crawl-delay: 1" . "\r\n\n";

# Block SemrushBot
echo "# Block SemrushBot" . "\r\n";
echo "User-Agent: SemrushBot" . "\r\n";
echo "Disallow: /" . "\r\n\n";

if ( $databasesArray['combi'] ) {
	if ( preg_match( '/^(.+)\.miraheze\.org$/', $_SERVER['HTTP_HOST'], $matches ) ) {
		$wiki = "{$matches[1]}wiki";

		if ( !isset( $databasesArray['combi']["{$wiki}"] ) ) {
			return;
		}

		# Dynamic sitemap url
		echo "# Dynamic sitemap url" . "\r\n";
		echo "Sitemap: https://static.miraheze.org/{$wiki}/sitemaps/sitemap.xml" . "\r\n\n";
	} else {
		$customDomainFound = false;
		$suffixes = [ 'wiki' ];
		$suffixMatch = array_flip( [ 'miraheze.org' => 'wiki' ] );

		foreach ( $databasesArray['combi'] as $db => $data ) {
			foreach ( $suffixes as $suffix ) {
				if ( substr( $db, -strlen( $suffix ) == $suffix ) ) {
					$url = $data['u'] ?? 'https://' . substr( $db, 0, -strlen( $suffix ) ) . '.' . $suffixMatch[$suffix];

					if ( !isset( $url ) || !$url ) {
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
			# Dynamic sitemap url
			echo "# Dynamic sitemap url" . "\r\n";
			echo "Sitemap: https://static.miraheze.org/{$customDomainFound}/sitemaps/sitemap.xml" . "\r\n\n";
		}
	}
}

if ( $page->exists() ) {
	echo "# -- BEGIN CUSTOM -- #\r\n\n";

	echo ContentHandler::getContentText( $page->getContent() ) ?: '';
}
