<?php

header('Content-Type:text/plain');

# Disallow API and special pages
echo "User-agent: *" . "\r\n";
echo "Disallow: /w/api.php" . "\r\n";
echo "Disallow: /w/index.php?title=Special:" . "\r\n";
echo "Disallow: /wiki/Special:" . "\r\n";

# Throttle YandexBot
echo "User-Agent: YandexBot" . "\r\n";
echo "Crawl-Delay: 2.5" . "\r\n";

# Dynamic sitemap url
echo "Sitemap: https://static.miraheze.org/sitemaps/$_SERVER[HTTP_HOST]/sitemap.xml" . "\r\n";
