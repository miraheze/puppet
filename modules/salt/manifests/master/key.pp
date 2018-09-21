class salt::master::key(
    String $salt_master_pubkey_type = 'prod',
) {
    $salt_master_pubkey = {
      'prod' => "-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA0JaAiTWywyAzyslNH7CS
HULqpOpEKJrHZiQW9yD0Otcpz0cGhe2dBQgeobxbczKsMEhS/sQzD9Z54UQ+QtXB
i8ELpEZDtsXtXTHcpmHp4FQh0PmmD0b4WGM9brKhas0ZTkBJjhYwDef8X+P0qRse
T7ipc7Ngw7MWXun9bCe+59p0krUL2Ygl7xpnIkvomaiyd2VQDIi8CKO1bHXbzvg6
bvyTlc43YvDAIB+BemFQ8rCiOcSGIDPFK9Glq9Tfn+ZSBTHdknOjoONr653AmpPI
vVvoVK/aSK6B+wcBisvUpT/vwgL/Ut5TQV1QaKKa+TFagk3z9mbNfyU0uAgo+Z94
TQIDAQAB
-----END PUBLIC KEY-----
",
    }

    file { '/etc/salt/pki/master/master.pub':
        content => $salt_master_pubkey[$salt_master_pubkey_type],
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        notify  => Service['salt-master'],
    }

    file { '/etc/salt/pki/master/master.pem':
        source    => 'puppet:///private/salt/master.pem',
        owner     => 'root',
        group     => 'root',
        mode      => '0400',
        notify    => Service['salt-master'],
        show_diff => false,
    }
}
