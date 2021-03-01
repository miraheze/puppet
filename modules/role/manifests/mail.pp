# role: mail
class role::mail {
    include postfix
    include postfix::dkim
    include postfix::dmarc
    include postfix::spamassassin
    include dovecot
    include prometheus::postfix_exporter

    ufw::allow { 'smtp':
        proto => 'tcp',
        port  => 25,
    }

    ufw::allow { 'smtp-ssl':
        proto => 'tcp',
        port  => 587,
    }

    ufw::allow { 'imap':
        proto => 'tcp',
        port  => 143,
    }

    ufw::allow { 'imap-ssl':
        proto => 'tcp',
        port  => 993,
    }

    motd::role { 'role::mail':
        description => 'mail server',
    }
}
