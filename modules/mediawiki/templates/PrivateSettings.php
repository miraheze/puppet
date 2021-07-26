<?php

// Database passwords
$wgDBadminpassword = "<%= @wikiadmin_password %>";
$wgDBpassword = "<%= @mediawiki_password %>";

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

// Extension:DiscordNotifications global webhook
$wmgGlobalDiscordWebhookUrl = "<%= @global_discord_webhook_url %>";

// writer-user password (ldap)
$wmgLdapPassword = "<%= @ldap_password %>";

// OAuth2 private key
$wgOAuth2PrivateKey = "<%= @oauth2_privatekey %>";