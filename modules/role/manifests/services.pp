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

    $firewallMon = query_facts('Class[Role::Icinga2]', ['ipaddress', 'ipaddress6'])

    if $citoid {
        class { '::services::citoid': }

        $firewallMon.each |$key, $value| {
            ufw::allow { "citoid monitoring ${value['ipaddress']}":
                proto => 'tcp',
                port  => 6927,
                from  => $value['ipaddress'],
            }

            ufw::allow { "citoid monitoring ${value['ipaddress6']}":
                proto => 'tcp',
                port  => 6927,
                from  => $value['ipaddress6'],
            }

            ufw::allow { "zotero monitoring ${value['ipaddress']}":
                proto => 'tcp',
                port  => 1969,
                from  => $value['ipaddress'],
            }

            ufw::allow { "zotero monitoring ${value['ipaddress6']}":
                proto => 'tcp',
                port  => 1969,
                from  => $value['ipaddress6'],
            }
        }
    }

    if $proton {
        class { '::services::proton': }

        $firewallMon.each |$key, $value| {
            ufw::allow { "proton monitoring ${value['ipaddress']}":
                proto => 'tcp',
                port  => 3030,
                from  => $value['ipaddress'],
            }

            ufw::allow { "proton monitoring ${value['ipaddress6']}":
                proto => 'tcp',
                port  => 3030,
                from  => $value['ipaddress6'],
            }
        }
    }

    if $restbase {
        class { '::services::restbase': }

        $firewallMon.each |$key, $value| {
            ufw::allow { "restbase monitoring ${value['ipaddress']}":
                proto => 'tcp',
                port  => 7231,
                from  => $value['ipaddress'],
            }

            ufw::allow { "restbase monitoring ${value['ipaddress6']}":
                proto => 'tcp',
                port  => 7231,
                from  => $value['ipaddress6'],
            }
        }
    }

    $firewallMediaWiki = query_facts('Class[Role::Mediawiki] or Class[Role::Services]', ['ipaddress', 'ipaddress6'])
    $firewallMediaWiki.each |$key, $value| {
        ufw::allow { "${value['ipaddress']} 443":
            proto => 'tcp',
            port  => 443,
            from  => $value['ipaddress'],
        }

        ufw::allow { "${value['ipaddress6']} 443":
            proto => 'tcp',
            port  => 443,
            from  => $value['ipaddress6'],
        }
    }

    motd::role { 'role::services':
        description => 'Hosting MediaWiki services (citoid, proton, restbase)',
    }
}
