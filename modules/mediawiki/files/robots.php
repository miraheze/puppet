<?php

define( 'MW_NO_SESSION', 1 );
require_once '/srv/mediawiki/w/includes/WebStart.php';

use MediaWiki\MediaWikiServices;

$wikiPageFactory = MediaWikiServices::getInstance()->getWikiPageFactory();
$titleFactory = MediaWikiServices::getInstance()->getTitleFactory();

$page = $wikiPageFactory->newFromTitle( $titleFactory->newFromText( 'Robots.txt', NS_MEDIAWIKI ) );

header( 'Content-Type: text/plain; charset=utf-8' );
header( 'X-Miraheze-Robots: Default' );

# Throttle access to certain pages
echo "User-Agent: *" . "\r\n";
echo "Allow: /w/api.php?action=mobileview&" . "\r\n";
echo "Allow: /w/load.php?" . "\r\n";
echo "Disallow: /w/" . "\r\n";
echo "Disallow: /geoip$" . "\r\n";
echo "Disallow: /rest_v1/" . "\r\n";
echo "Disallow: /wiki/Special:" . "\r\n";
echo "Disallow: /wiki/Spezial:" . "\r\n";
echo "Disallow: /wiki/Spesial:" . "\r\n";
echo "Disallow: /wiki/Special%3A" . "\r\n";
echo "Disallow: /wiki/Spezial%3A" . "\r\n";
echo "Disallow: /wiki/Spesial%3A" . "\r\n";
echo "Disallow: /wiki/Property:" . "\r\n";
echo "Disallow: /wiki/Property%3A" . "\r\n";
echo "Disallow: /wiki/property:" . "\r\n";
echo "Disallow: /wiki/Especial:" . "\r\n";
echo "Disallow: /wiki/Especial%3A" . "\r\n";
echo "Disallow: /wiki/especial:" . "\r\n";

# Throttle YandexBot TODO: Crawl-delay is not respected since 2018
echo "# Throttle YandexBot" . "\r\n";
echo "User-Agent: YandexBot" . "\r\n";
echo "Crawl-Delay: 2.5" . "\r\n\n";

# Throttle BingBot
echo "# Throttle BingBot" . "\r\n";
echo "User-agent: bingbot" . "\r\n";
echo "Crawl-delay: 5" . "\r\n\n";

# Block SemrushBot
echo "# Block SemrushBot" . "\r\n";
echo "User-Agent: SemrushBot" . "\r\n";
echo "Disallow: /" . "\r\n\n";

# Throttle MJ12Bot
echo "# Throttle MJ12Bot" . "\r\n";
echo "User-agent: MJ12bot" . "\r\n";
echo "Crawl-Delay: 10" . "\r\n\n";

# Block AhrefsBot
echo "# Block AhrefsBot" . "\r\n";
echo "User-agent: AhrefsBot" . "\r\n";
echo "Disallow: /" . "\r\n\n";

# Block Bytespider
echo "# Block Bytespider" . "\r\n";
echo "User-agent: Bytespider" . "\r\n";
echo "Disallow: /" . "\r\n\n";

# Block PetalBot
echo "# Block PetalBot" . "\r\n";
echo "User-agent: PetalBot" . "\r\n";
echo "Disallow: /" . "\r\n\n";

# Block DotBot
echo "# Block DotBot" . "\r\n";
echo "User-agent: DotBot" . "\r\n";
echo "Disallow: /" . "\r\n\n";

# Block MegaIndex
echo "# Block MegaIndex" . "\r\n";
echo "User-agent: MegaIndex" . "\r\n";
echo "Disallow: /" . "\r\n\n";

# Block serpstatbot
echo "# Block serpstatbot" . "\r\n";
echo "User-agent: serpstatbot" . "\r\n";
echo "Disallow: /" . "\r\n\n";

# Block Barkrowler
echo "# Block Barkrowler" . "\r\n";
echo "User-agent: Barkrowler" . "\r\n";
echo "Disallow: /" . "\r\n\n";

# Block SeekportBot
echo "# Block SeekportBot" . "\r\n";
echo "User-agent: SeekportBot" . "\r\n";
echo "Disallow: /" . "\r\n\n";

# Dynamic sitemap url
echo "# Dynamic sitemap url" . "\r\n";
echo "Sitemap: {$wgServer}/sitemap.xml" . "\r\n\n";

if ( $page->exists() ) {
	header( 'X-Miraheze-Robots: Custom' );

	echo "# -- BEGIN CUSTOM -- #\r\n\n";

	$content = $page->getContent();

	echo ( $content instanceof TextContent ) ? $content->getText() : '';
}
