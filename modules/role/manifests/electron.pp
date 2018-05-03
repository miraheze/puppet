# role: electron
class role::electron {
    include ::electron

    motd::role { 'role::electron':
        description => 'Simple PDF/PNG/JPEG render service, accepts webpage URL and returns the resource.',
    }
}
