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

// hCaptcha secret key
$wgHCaptchaSecretKey = "<%= @hcaptcha_secretkey %>";

// Shellbox secret key
$wgShellboxSecretKey = "<%= @shellbox_secretkey %>";

// Matomo token
$wgMatomoAnalyticsTokenAuth = "<%= @matomotoken %>";

// Extension:DiscordNotifications global webhook
$wmgGlobalDiscordWebhookUrl = "<%= @global_discord_webhook_url %>";
$wmgDiscordExperimentalWebhook = "<%= @discord_experimental_webhook %>";

// writer-user password (ldap)
$wmgLdapPassword = "<%= @ldap_password %>";

// Swift password for mw
$wmgSwiftPassword = "<%= @swift_password %>";

// Swift temp URL key for mw
$wmgSwiftTempUrlKey = "<%= @swift_temp_url_key %>";

// Reports write key
$wgMirahezeReportsWriteKey = "<%= @reports_write_key %>";
