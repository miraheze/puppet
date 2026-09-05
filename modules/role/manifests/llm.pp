# role: LLM
class role::llm (
    String $backend_api_base = 'http://127.0.0.1:11434/v1',
    String $backend_api_key = lookup('mediawiki::openai_apikey'),
    String $bind_host = '127.0.0.1',
    Integer $port = 3000,
) {
    ssl::wildcard { 'llm wildcard': }

    nginx::site { 'llm_proxy':
        ensure  => present,
        source  => 'puppet:///modules/role/llm/ai.wikitide.net.conf',
        monitor => false,
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

    firewall::service { 'http':
        proto   => 'tcp',
        port    => 80,
        # src_sets => ['MEDIAWIKI_HOSTS', 'MEDIAWIKI_TASK_HOSTS', 'MEDIAWIKI_BETA_HOSTS', 'BASTION_HOSTS', 'ICINGA2_HOSTS'],
        notrack => true,
    }

    firewall::service { 'https':
        proto   => 'tcp',
        port    => 443,
        # src_sets => ['MEDIAWIKI_HOSTS', 'MEDIAWIKI_TASK_HOSTS', 'MEDIAWIKI_BETA_HOSTS', 'BASTION_HOSTS', 'ICINGA2_HOSTS'],
        notrack => true,
    }

    system::role { 'llm':
        description => 'LLM host',
    }
}
