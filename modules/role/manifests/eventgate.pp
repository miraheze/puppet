# === Role eventgate
class role::eventgate {
    include eventgate

    system::role { 'role::eventgate':
        description => 'EventGate server',
    }
}