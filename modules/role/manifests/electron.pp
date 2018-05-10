# role: electron
class role::electron {
    include ::electron

    ufw::allow { 'electron monitoring':
        proto => 'tcp',
        port  => 3000,
        from  => '185.52.1.76',
    }

    motd::role { 'role::electron':
        description => 'Simple PDF/PNG/JPEG render service, accepts webpage URL and returns the resource.',
    }
}
