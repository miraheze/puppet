<?php

// Based on the version created by Wikimedia

define( 'MW_NO_SESSION', 1 );

require_once '/srv/mediawiki/config/initialise/MirahezeFunctions.php';
require MirahezeFunctions::getMediaWiki( 'includes/WebStart.php' );

use MediaWiki\Context\RequestContext;
use MediaWiki\MediaWikiServices;

function streamAppleTouch() {
	global $wgAppleTouchIcon;
	wfResetOutputBuffers();

	$touch = $wgAppleTouchIcon;
	if ( $touch === '/apple-touch-icon.png' || $touch === false ) {
		$touch = '/favicons/apple-touch-icon-default.png';
	}

	$req = RequestContext::getMain()->getRequest();
	if ( $req->getHeader( 'X-Favicon-Loop' ) !== false ) {
		header( 'HTTP/1.1 500 Internal Server Error' );
		return;
	}

	$url = wfExpandUrl( $touch, PROTO_CANONICAL );

	$mediaWikiServices = MediaWikiServices::getInstance();
	$urlUtils = $mediaWikiServices->getUrlUtils();
	$parsedBaseUrl = $urlUtils->parse( $url );

	if ( $parsedBaseUrl['host'] === 'static.miraheze.org'  ) {
		$url = str_replace( 'static.miraheze.org', 'static.wikitide.net', $url );
	}

	$client = $mediaWikiServices
		->getHttpRequestFactory()
		->create( $url );
	$client->setHeader( 'X-Favicon-Loop', '1' );

	$status = $client->execute();
	if ( !$status->isOK() ) {
		$touch = '/favicons/apple-touch-icon-default.png';
		$url = wfExpandUrl( $touch, PROTO_CANONICAL );
		$client = MediaWikiServices::getInstance()
			->getHttpRequestFactory()
			->create( $url );

		$status = $client->execute();
		if ( !$status->isOK() ) {
			header( 'HTTP/1.1 500 Internal Server Error' );
			return;
		}
	}

	$content = $client->getContent();
	header( 'Content-Length: ' . strlen( $content ) );
	header( 'Content-Type: ' . $client->getResponseHeader( 'Content-Type' ) );
	header( 'Cache-Control: public' );
	header( 'Expires: ' . gmdate( 'r', time() + 86400 ) );
	echo $content;
}

streamAppleTouch();
