# = Class: profile::citoid
#
# Setups Citoid and zoetero services
#
class profile::citoid {
    class { '::services::citoid': }
}
