# role: mail
class role::mail {
    include postfix
    include postfix::dkim
    include postfix::dmarc
    include postfix::spamassassin
    include dovecot
    include prometheus::exporter::postfix

    ferm::service { 'smtp':
        proto => 'tcp',
        port  => '25',
    }

    ferm::service { 'smtp-ssl':
        proto => 'tcp',
        port  => '587',
    }

    ferm::service { 'imap':
        proto => 'tcp',
        port  => '143',
    }

    ferm::service { 'imap-ssl':
        proto => 'tcp',
        port  => '993',
    }

    motd::role { 'role::mail':
        description => 'mail server',
    }
}
