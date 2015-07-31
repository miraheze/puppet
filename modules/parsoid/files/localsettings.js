"use strict";

exports.setup = function( parsoidConfig ) {
	// wiki end points
	// interwikis with m at the beginning have conflicts with Wikimeda wikis
	parsoidConfig.setInterwiki( 'mmetawiki', 'https://meta.miraheze.org/w/api.php' );
	parsoidConfig.setInterwiki( 'googlewiki', 'https://google.miraheze.org/w/api.php' );

	// Enable debug mode (prints extra debugging messages)
	parsoidConfig.debug = false;

	parsoidConfig.usePHPPreProcessor = true;

	// Use selective serialization (default false)
	parsoidConfig.useSelser = true;
};
