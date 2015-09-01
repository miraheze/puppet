"use strict";

exports.setup = function( parsoidConfig ) {
	// wiki end points
	parsoidConfig.setInterwiki( 'metawiki', 'https://meta.miraheze.org/w/api.php' );
	parsoidConfig.setInterwiki( 'spiralwiki', 'https://spiral.wiki/w/api.php' );
	parsoidConfig.setInterwiki( 'torejorgwiki', 'https://torejorg.miraheze.org/w/api.php' );
	parsoidConfig.setInterwiki( 'extloadwiki', 'https://extload.miraheze.org/w/api.php' );

	// Don't load WMF wikis
	parsoidConfig.loadWMF = false;
	parsoidConfig.defaultWiki = 'metawiki';

	// Enable debug mode (prints extra debugging messages)
	parsoidConfig.debug = false;

	parsoidConfig.usePHPPreProcessor = true;

	// Use selective serialization (default false)
	parsoidConfig.useSelser = true;
};
