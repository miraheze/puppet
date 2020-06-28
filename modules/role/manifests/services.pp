# role: services
class role::services {

    $firewallMon = query_facts('Class[Role::Icinga2]', ['ipaddress', 'ipaddress6'])
    if lookup('enable_citoid', {'default_value' => true}) {
        include ::profile::citoid

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

    if lookup('enable_parsoid', {'default_value' => true}) {
        include ::profile::parsoid

        $firewallMon.each |$key, $value| {
            ufw::allow { "parsoid monitoring ${value['ipaddress']}":
                proto => 'tcp',
                port  => 8142,
                from  => $value['ipaddress'],
            }

            ufw::allow { "parsoid monitoring ${value['ipaddress6']}":
                proto => 'tcp',
                port  => 8142,
                from  => $value['ipaddress6'],
            }
        }
    }

    if lookup('enable_proton', {'default_value' => true}) {
        include ::profile::proton

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

    if lookup('enable_restbase', {'default_value' => true}) {
        include ::profile::restbase

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

    $firewallMediaWiki = query_facts('Class[Role::Mediawiki]', ['ipaddress', 'ipaddress6'])
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
        description => 'Hosting MediaWiki services (citoid, parsoid, proton, restbase etc)',
    }
}
