#!/usr/bin/env php
<?php

error_reporting( 0 );

require_once '/srv/mediawiki-staging/config/initialise/MirahezeFunctions.php';

if ( ( $argv[1] ?? false ) === 'all' ) {
	echo json_encode( MirahezeFunctions::MEDIAWIKI_VERSIONS );
	exit( 0 );
}

$versions = array_unique( MirahezeFunctions::MEDIAWIKI_VERSIONS );
asort( $versions );

echo json_encode( array_combine( $versions, $versions ) );
