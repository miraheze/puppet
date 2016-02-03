"use strict";

exports.setup = function( parsoidConfig ) {
	// Wiki end points
	parsoidConfig.setInterwiki( '8stationwiki', 'https://8station.miraheze.org/w/api.php' );
	parsoidConfig.setInterwiki( 'adnovumwiki', 'https://adnovum.miraheze.org/w/api.php' );
	parsoidConfig.setInterwiki( 'airwiki', 'https://air.miraheze.org/w/api.php' );
	parsoidConfig.setInterwiki( 'allthetropeswiki', 'https://allthetropes.miraheze.org/w/api.php' );
	parsoidConfig.setInterwiki( 'aktposwiki', 'https://aktpos.miraheze.org/w/api.php' );
	parsoidConfig.setInterwiki( 'applebranchwiki', 'https://applebranch.miraheze.org/w/api.php' );
	parsoidConfig.setInterwiki( 'arguwikiwiki', 'https://arguwiki.miraheze.org/w/api.php' );
	parsoidConfig.setInterwiki( 'aryamanwiki', 'https://aryaman.miraheze.org/w/api.php' );
	parsoidConfig.setInterwiki( 'biblicalwikiwiki', 'https://biblicalwiki.miraheze.org/w/api.php' );
	parsoidConfig.setInterwiki( 'boulderwikiwiki', 'https://boulderwiki.org/w/api.php' );
	parsoidConfig.setInterwiki( 'braindumpwiki', 'https://braindump.miraheze.org/w/api.php' );
	parsoidConfig.setInterwiki( 'cbmediawiki', 'https://cbmedia.miraheze.org/w/api.php' ); 
	parsoidConfig.setInterwiki( 'chandruswethswiki', 'https://chandrusweths.miraheze.org/w/api.php' );
	parsoidConfig.setInterwiki( 'clicordiwiki', 'https://clicordi.miraheze.org/w/api.php' );
	parsoidConfig.setInterwiki( 'cssandjsschoolboardwiki', 'https://cssandjsschoolboard.miraheze.org/w/api.php' );
	parsoidConfig.setInterwiki( 'developmentwiki', 'https://development.miraheze.org/w/api.php' );
	parsoidConfig.setInterwiki( 'extloadwiki', 'https://extload.miraheze.org/w/api.php' );
	parsoidConfig.setInterwiki( 'esswaywiki', 'https://essway.miraheze.org/w/api.php' );
	parsoidConfig.setInterwiki( 'etpowiki', 'https://etpo.miraheze.org/w/api.php' );
	parsoidConfig.setInterwiki( 'gameswiki', 'https://games.miraheze.org/w/api.php' );
	parsoidConfig.setInterwiki( 'genwiki', 'https://gen.miraheze.org/w/api.php' );
	parsoidConfig.setInterwiki( 'islamwissenschaft', 'https://islamwissenschaft.miraheze.org/w/api.php' );
	parsoidConfig.setInterwiki( 'izanagiwiki', 'https://izanagi.miraheze.org/w/api.php' );
	parsoidConfig.setInterwiki( 'luckandlogicwiki', 'https://luckandlogic.miraheze.org/w/api.php' );
	parsoidConfig.setInterwiki( 'mecanonwiki', 'https://mecanon.miraheze.org/w/api.php' );
	parsoidConfig.setInterwiki( 'hshsinfoportalwiki', 'https://hshsinfoportal.miraheze.org/w/api.php' );
	parsoidConfig.setInterwiki( 'metawiki', 'https://meta.miraheze.org/w/api.php' );
	parsoidConfig.setInterwiki( 'nwpwiki', 'https://nwp.miraheze.org/w/api.php' );
	parsoidConfig.setInterwiki( 'partupwiki', 'https://partup.miraheze.org/w/api.php' );
	parsoidConfig.setInterwiki( 'pflanzenwiki', 'https://pflanzen.miraheze.org/w/api.php' );
	parsoidConfig.setInterwiki( 'pqwiki', 'https://pq.miraheze.org/w/api.php' );
	parsoidConfig.setInterwiki( 'permanentfuturelabwiki', 'https://permanentfuturelab.wiki/w/api.php');
	parsoidConfig.setInterwiki( 'rawdatawiki', 'https://rawdata.miraheze.org/w/api.php' );
	parsoidConfig.setInterwiki( 'recherchesdocumentaireswiki', 'https://recherchesdocumentaires.miraheze.org/w/api.php' );
	parsoidConfig.setInterwiki( 'safiriawiki', 'https://safiria.miraheze.org/w/api.php' );
	parsoidConfig.setInterwiki( 'shoppingwiki', 'https://shopping.miraheze.org/w/api.php' );
	parsoidConfig.setInterwiki( 'spiralwiki', 'https://spiral.wiki/w/api.php' );
	parsoidConfig.setInterwiki( 'testwiki', 'https://test.miraheze.org/w/api.php' ); 
	parsoidConfig.setInterwiki( 'tochkiwiki', 'https://tochki.miraheze.org/w/api.php' );
	parsoidConfig.setInterwiki( 'torejorgwiki', 'https://torejorg.miraheze.org/w/api.php' );
	parsoidConfig.setInterwiki( 'unikumwiki', 'https://unikum.miraheze.org/w/api.php' );
	parsoidConfig.setInterwiki( 'urho3dwiki', 'https://urho3d.miraheze.org/w/api.php' );
	parsoidConfig.setInterwiki( 'vrgowiki', 'https://vrgo.miraheze.org/w/api.php' );
	parsoidConfig.setInterwiki( 'walthamstowlabourwiki', 'https://walthamstowlabour.miraheze.org/w/api.php' );
	parsoidConfig.setInterwiki( 'webflowwiki', 'https://webflow.miraheze.org/w/api.php' );

	// Don't load WMF wikis
	parsoidConfig.loadWMF = false;
	parsoidConfig.defaultWiki = 'metawiki';

	// Enable debug mode (prints extra debugging messages)
	parsoidConfig.debug = false;

	parsoidConfig.usePHPPreProcessor = true;

	// Use selective serialization (default false)
	parsoidConfig.useSelser = true;
};
