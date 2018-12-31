# = Class: profile::electron
#
# Setups electron as a pdf service.
#
class profile::electron (
	$access_key = hiera('electron_access_key', 'secret'),
) {
    class { '::services::electron':
	    access_key => $access_key,
    }
}
