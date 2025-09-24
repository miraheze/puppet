# role: LLM
class role::llm (
    String $backend_api_base = 'http://127.0.0.1:11434/v1',
    String $backend_api_key = undef,
    String $bind_host = '127.0.0.1',
    Integer $port = 3000,
) {
    ssl::wildcard { 'llm wildcard': }

    nginx::site { 'llm_proxy':
        ensure  => present,
        source  => 'puppet:///modules/role/llm/ai.wikitide.net.conf',
        monitor => true,
    }

    class { '::ollama':
        bind_host       => $bind_host,
        allowed_origins => '*',
    }

    class { 'ollama::nvidia':
        use_cuda_repo     => false,
        pin_driver_pkg    => undef,
        blacklist_nouveau => true,
    }

    class { '::openwebui':
        backend_api_base => $backend_api_base,
        backend_api_key  => $backend_api_key,
        bind_host        => $bind_host,
        port             => $port,
    }

    $firewall_rules_str = join(
        query_facts('Class[Role::MediaWiki] or Class[Role::Bastion] or Class[Role::Icinga2]', ['networking'])
        .map |$key, $value| {
            if ( $value['networking']['interfaces']['ens19'] and $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens19']['ip']} ${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } elsif ( $value['networking']['interfaces']['ens18'] ) {
                "${value['networking']['interfaces']['ens18']['ip']} ${value['networking']['interfaces']['ens18']['ip6']}"
            } else {
                "${value['networking']['ip']} ${value['networking']['ip6']}"
            }
        }
        .flatten()
        .unique()
        .sort(),
        ' '
    )

    ferm::service { 'http':
        proto   => 'tcp',
        port    => '80',
        # srange  => "(${$firewall_rules_str})",
        notrack => true,
    }

    ferm::service { 'https':
        proto   => 'tcp',
        port    => '443',
        # srange  => "(${$firewall_rules_str})",
        notrack => true,
    }

    system::role { 'llm':
        description => 'LLM host',
    }
}