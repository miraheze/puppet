# class: base
class base {
    include base::packages
    include base::puppet
    include base::timezone
    include base::upgrades
    include base::monitoring
    include base::ufw
    include base::ssl
    include ssh

    if $user_defined == "false" {
        include users
    }

    if $::hostname != "misc1" {
        mailalias { 'root':
            recipient => 'root@miraheze.org',
        }
    }
}
