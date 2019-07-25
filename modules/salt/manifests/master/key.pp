class salt::master::key(
    String $salt_master_pubkey_type = 'prod',
) {
    $salt_master_pubkey = {
        'prod' => '-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAt/7gCYjoI2YDL9IdmfBJ 
zytuaUdv9Izu2YY540DaxRSpcouYiTUucML+M6mKiphqGlFWf4ZCTaKeNOTQ0X9U
Pgu15Va57Z52omVhRjgrDZ5lUCQarIbijD1heMhPwRK1x+TaHWl+92+FC6nU9iJT
q36avf3OaJPmnaFRGuHd6WHwuTCKzNpAi4Ik8xbnz2tOsWqtfC9IqJXAaVfIggCJ
ka5wdoa2R/uEV5/8rzaT/TFaFazpu29jSmXhB1NT3IN7/ggft+uDqv3U3MLd6XTW
BROwXhD18r/QgwBbqD51nv9TcYwNwi9gPFTerHe9tx1y1OfxAzILm9xgNsvmfwnK
swIDAQAB
-----END PUBLIC KEY-----',
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
