<?php

define( 'MW_NO_SESSION', 1 );
require_once '/srv/mediawiki/w/includes/WebStart.php';

use MediaWiki\MediaWikiServices;

$wikiPageFactory = MediaWikiServices::getInstance()->getWikiPageFactory();
$titleFactory = MediaWikiServices::getInstance()->getTitleFactory();

$page = $wikiPageFactory->newFromTitle( $titleFactory->newFromText( 'Robots.txt', NS_MEDIAWIKI ) );

header( 'Content-Type: text/plain; charset=utf-8' );
header( 'X-Miraheze-Robots: Default' );

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

echo "# Throttle MJ12Bot" . "\r\n";
echo "User-agent: MJ12bot" . "\r\n";
echo "Crawl-Delay: 10" . "\r\n\n";

# Dynamic sitemap url
echo "# Dynamic sitemap url" . "\r\n";
echo "Sitemap: https://{$wmgUploadHostname}/{$wgDBname}/sitemaps/sitemap.xml" . "\r\n\n";

if ( $page->exists() ) {
	header( 'X-Miraheze-Robots: Custom' );

	echo "# -- BEGIN CUSTOM -- #\r\n\n";

	$content = $page->getContent();

	echo ( $content instanceof TextContent ) ? $content->getText() : '';
}
