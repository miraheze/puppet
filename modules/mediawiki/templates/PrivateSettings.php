<?php

// Database passwords
$wgDBadminpassword = "<%= @wikiadmin_password %>";
$wgDBpassword = "<%= @mediawiki_password %>";

// Google Maps API key

$wmgMapsGMaps3ApiKey = "<%= @googlemaps_key %>";

// Redis AUTH password
$wmgRedisPassword = "<%= @redis_password %>";

// Noreply authentication password
$wmgSMTPPassword = "<%= @noreply_password %>";

// MediaWiki secret keys
$wgUpgradeKey = "<%= @mediawiki_upgradekey %>";
$wgSecretKey = "<%= @mediawiki_secretkey %>";

// ReCaptchaNoCaptcha secret keys
$wgReCaptchaSiteKey = "<%= @recaptcha_sitekey %>";
$wgReCaptchaSecretKey = "<%= @recaptcha_secretkey %>";

// Matomo Token
$wgMatomoAnalyticsTokenAuth = "<%= @matomotoken %>";

// Translate Yandex API key
$wmgYandexTranslationKey = "<%= @yandextranslation_key %>";

// Extension:DiscordNotifications hooks
$wmgWikiMirahezeDiscordHooks = array(
<%- @wiki_discord_hooks_url.each_pair do |wiki, values| -%>
    '<%= wiki %>' => <%= values %>,
<%- end -%>
);

// Extension:SlackNotifications hooks
$wmgWikiMirahezeSlackHooks = array(
<%- @wiki_slack_hooks_url.each_pair do |wiki, values| -%>
    '<%= wiki %>' => '<%= values %>',
<%- end -%>
);
