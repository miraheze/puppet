# = Class: profile::mathoid
#
# Setups mathoid which is used by restbase.
#
class profile::mathoid {
    class { '::services::mathoid': }
}
