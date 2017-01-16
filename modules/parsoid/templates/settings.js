"use strict";

exports.setup = function( parsoidConfig ) {
	// Wikis
<%- @wikis.each_pair do |wiki, value| -%>
<%- if value == true -%>
	parsoidConfig.setInterwiki( '<%= wiki %>wiki', 'https://<%= wiki %>.miraheze.org/w/api.php' );
<%- else -%>
	parsoidConfig.setInterwiki( '<%= wiki %>wiki', 'https://<%= value %>/w/api.php' );
<%- end -%>
<%- end -%>

	// Don't load WMF wikis
	parsoidConfig.loadWMF = false;
	parsoidConfig.defaultWiki = 'metawiki';

	// Enable debug mode (prints extra debugging messages)
	parsoidConfig.debug = false;

	parsoidConfig.usePHPPreProcessor = true;

	// Use selective serialization (default false)
	parsoidConfig.useSelser = true;
};
