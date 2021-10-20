# = Class: role::services
#
# Sets up Citeoid, Proton and Restbase.
#
# = Parameters
#
# [*citoid*]
#   A boolean on whether to enable citoid.
#
# [*proton*]
#   A boolean on whether to enable proton.
#
# [*restbase*]
#   A boolean on whether to enable restbase.
#
class role::services (
    Boolean $citoid   = lookup('enable_citoid', {'default_value' => true}),
    Boolean $proton   = lookup('enable_proton', {'default_value' => true}),
    Boolean $restbase = lookup('enable_restbase', {'default_value' => true})
) {

    $firewall_rules = query_facts('Class[Role::Icinga2]', ['ipaddress', 'ipaddress6'])
    $firewall_rules_mapped = $firewall_rules.map |$key, $value| { "${value['ipaddress']} ${value['ipaddress6']}" }
    $firewall_rules_str = join($firewall_rules_mapped, ' ')

    if $citoid {
        class { '::services::citoid': }

        ferm::service { 'citoid':
            proto  => 'tcp',
            port   => '6927',
            srange => "(${firewall_rules_str})",
        }

        ferm::service { 'zotero':
            proto  => 'tcp',
            port   => '1969',
            srange => "(${firewall_rules_str})",
        }
    }

    if $proton {
        class { '::services::proton': }

        ferm::service { 'proton':
            proto  => 'tcp',
            port   => '3030',
            srange => "(${firewall_rules_str})",
        }
    }

    if $restbase {
        class { '::services::restbase': }

        ferm::service { 'restbase':
            proto  => 'tcp',
            port   => '7231',
            srange => "(${firewall_rules_str})",
        }
    }

    $firewall_mediawiki_rules = query_facts('Class[Role::Mediawiki] or Class[Role::Services]', ['ipaddress', 'ipaddress6'])
    $firewall_mediawiki_rules_mapped = $firewall_mediawiki_rules.map |$key, $value| { "${value['ipaddress']} ${value['ipaddress6']}" }
    $firewall_mediawiki_rules_str = join($firewall_mediawiki_rules_mapped, ' ')
    ferm::service { 'mediawiki access 443':
        proto  => 'tcp',
        port   => '443',
        srange => "(${firewall_mediawiki_rules_str})",
    }

    motd::role { 'role::services':
        description => 'Hosting MediaWiki services (citoid, proton, restbase)',
    }
}
