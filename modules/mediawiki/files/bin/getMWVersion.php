#!/usr/bin/env php
<?php

error_reporting( 0 );

require_once '/srv/mediawiki/config/initialise/MirahezeFunctions.php';

if ( count( $argv ) < 2 ) {
	print "Usage: getMWVersion <dbname> \n";
	exit( 1 );
}

define( 'MW_DB', $argv[1] );

echo MirahezeFunctions::getMediaWikiVersion( $argv[1] ) . "\n";
