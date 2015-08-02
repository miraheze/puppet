"use strict";

exports.setup = function( parsoidConfig ) {
	// wiki end points
	parsoidConfig.setInterwiki( 'metawiki', 'https://meta.miraheze.org/w/api.php' );
	parsoidConfig.setInterwiki( 'spiralwiki', 'https://spiral.wiki/w/api.php' );
	parsoidConfig.setInterwiki( 'parsoidwiki', 'https://parsoid.miraheze.org/w/api.php' );

	// Enable debug mode (prints extra debugging messages)
	parsoidConfig.debug = false;

	parsoidConfig.usePHPPreProcessor = true;

	// Use selective serialization (default false)
	parsoidConfig.useSelser = true;
};
