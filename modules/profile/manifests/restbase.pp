# = Class: profile::restbase
#
# Setups restbase for all the different services.
#
class profile::restbase {
    class { '::services::restbase': }
}
