"use strict";

exports.setup = function( parsoidConfig ) {
	// Wiki end points - Miraheze domains only
<% @wikis.each do |wiki| -%>
	parsoidConfig.setInterwiki( '<%= wiki %>wiki', 'https://<%= wiki %>.miraheze.org/w/api.php' );
<% end -%>

	// Wiki end points - Custom domains only
	parsoidConfig.setInterwiki( 'allthetropeswiki', 'https://allthetropes.org/w/api.php' );
	parsoidConfig.setInterwiki( 'boulderwikiwiki', 'https://boulderwiki.org/w/api.php' );
	parsoidConfig.setInterwiki( 'carvingwiki', 'https://carving.wiki/w/api.php' );
	parsoidConfig.setInterwiki( 'dottorcontewiki', 'https://wiki.dottorconte.eu/w/api.php' );
	parsoidConfig.setInterwiki( 'dwplivewiki', 'https://wiki.dwplive.com/w/api.php' );
	parsoidConfig.setInterwiki( 'espiralwiki', 'https://espiral.org/w/api.php' );
	parsoidConfig.setInterwiki( 'make717wiki', 'https://wiki.make717.org/w/api.php' );
	parsoidConfig.setInterwiki( 'nextlevelwikiwiki', 'https://wiki.lbcomms.co.za/w/api.php' );
	parsoidConfig.setInterwiki( 'oyeavdelingenwiki', 'https://oyeavdelingen.org/w/api.php' );
	parsoidConfig.setInterwiki( 'permanentfuturelabwiki', 'https://permanentfuturelab.wiki/w/api.php');
	parsoidConfig.setInterwiki( 'spiralwiki', 'https://spiral.wiki/w/api.php' );
	parsoidConfig.setInterwiki( 'testwiki', 'https://publictestwiki.com/w/api.php' );
	parsoidConfig.setInterwiki( 'universebuildwiki', 'https://universebuild.com/w/api.php' );
	parsoidConfig.setInterwiki( 'valentinaprojectwiki', 'https://wiki.valentinaproject.org/w/api.php' );
	parsoidConfig.setInterwiki( 'wikikaisagawiki', 'https://wiki.kaisaga.com/w/api.php' );
	parsoidConfig.setInterwiki( 'wisdomwiki', 'https://wisdomwiki.org/w/api.php' );
	parsoidConfig.setInterwiki( 'wisdomsandboxwiki', 'https://sandbox.wisdomwiki.org/w/api.php' );

	// Don't load WMF wikis
	parsoidConfig.loadWMF = false;
	parsoidConfig.defaultWiki = 'metawiki';

	// Enable debug mode (prints extra debugging messages)
	parsoidConfig.debug = false;

	parsoidConfig.usePHPPreProcessor = true;

	// Use selective serialization (default false)
	parsoidConfig.useSelser = true;
};
