# = Class: profile::proton
#
# Setups proton as a pdf service.
#
class profile::proton {
    class { '::services::proton': }
}
