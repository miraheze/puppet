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
echo "Disallow: /api.php" . "\r\n";
echo "Disallow: /cors/" . "\r\n";
echo "Disallow: /geoip$" . "\r\n";
echo "Disallow: /rest_v1/" . "\r\n";
echo "Disallow: /w/Property:" . "\r\n";
echo "Disallow: /w/Property%3A" . "\r\n";
echo "Disallow: /w/property:" . "\r\n";
echo "Disallow: /*?title=Property:" . "\r\n";
echo "Disallow: /*?title=Property%3A" . "\r\n";
echo "Disallow: /*?*&title=Property:" . "\r\n";
echo "Disallow: /*?*&title=Property%3A" . "\r\n";
echo "Disallow: /w/Special:" . "\r\n";
echo "Disallow: /w/Special%3A" . "\r\n";
echo "Disallow: /w/special:" . "\r\n";
echo "Disallow: /*?title=Special:" . "\r\n";
echo "Disallow: /*?title=Special%3A" . "\r\n";
echo "Disallow: /*?*&title=Special:" . "\r\n";
echo "Disallow: /*?*&title=Special%3A" . "\r\n";
echo "Disallow: /w/Especial:" . "\r\n";
echo "Disallow: /w/Especial%3A" . "\r\n";
echo "Disallow: /w/especial:" . "\r\n";
echo "Disallow: /*?title=Especial:" . "\r\n";
echo "Disallow: /*?title=Especial%3A" . "\r\n";
echo "Disallow: /*?*&title=Especial:" . "\r\n";
echo "Disallow: /*?*&title=Especial%3A" . "\r\n";
echo "Disallow: /*?action=" . "\r\n";
echo "Disallow: /*?*&action=" . "\r\n";
echo "Disallow: /*?feed=" . "\r\n";
echo "Disallow: /*?*&feed=" . "\r\n";
echo "Disallow: /*?from=" . "\r\n";
echo "Disallow: /*?*&from=" . "\r\n";
echo "Disallow: /*?mobileaction=" . "\r\n";
echo "Disallow: /*?*&mobileaction=" . "\r\n";
echo "Disallow: /*?oldid=" . "\r\n";
echo "Disallow: /*?*&oldid=" . "\r\n";
echo "Disallow: /*?printable=" . "\r\n";
echo "Disallow: /*?*&printable=" . "\r\n";
echo "Disallow: /*?redirect=" . "\r\n";
echo "Disallow: /*?*&redirect=" . "\r\n";
echo "Disallow: /*?uselang=" . "\r\n";
echo "Disallow: /*?*&uselang=" . "\r\n";
echo "Disallow: /*?useskin=" . "\r\n";
echo "Disallow: /*?*&useskin=" . "\r\n";
echo "Disallow: /*?veaction=" . "\r\n";
echo "Disallow: /*?*&veaction=" . "\r\n";
echo "Disallow: /*?filefrom=" . "\r\n";
echo "Disallow: /*?*&filefrom=" . "\r\n";
echo "Disallow: /*?fileuntil=" . "\r\n";
echo "Disallow: /*?*&fileuntil=" . "\r\n";
echo "Disallow: /*?navbox=" . "\r\n";
echo "Disallow: /*?*&navbox=" . "\r\n";
echo "Disallow: /*?pageuntil=" . "\r\n";
echo "Disallow: /*?*&pageuntil=" . "\r\n";
echo "Disallow: /*?pagefrom=" . "\r\n";
echo "Disallow: /*?*&pagefrom=" . "\r\n";
echo "Disallow: /*?diff=" . "\r\n";
echo "Disallow: /*?*&diff=" . "\r\n";
echo "Disallow: /*?curid=" . "\r\n";
echo "Disallow: /*?*&curid=" . "\r\n";
echo "Disallow: /*?search=" . "\r\n";
echo "Disallow: /*?*&search=" . "\r\n";
echo "Disallow: /*?section=" . "\r\n";
echo "Disallow: /*?*&section=" . "\r\n\n";

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

# Dynamic sitemap url
echo "# Dynamic sitemap url" . "\r\n";
echo "Sitemap: {$wgServer}/sitemap.xml" . "\r\n\n";

if ( $page->exists() ) {
	header( 'X-Miraheze-Robots: Custom' );

	echo "# -- BEGIN CUSTOM -- #\r\n\n";

	$content = $page->getContent();

	echo ( $content instanceof TextContent ) ? $content->getText() : '';
}
