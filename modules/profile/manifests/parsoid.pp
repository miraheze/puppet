# = Class: profile::parsoid
#
# Setups parsoid to use with VisualEditor
#
class profile::parsoid {
    class { '::services::parsoid': }
}
