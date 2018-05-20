# role: mailman3
class role::mailman {
    include ::mailman

    # crossed out as would conflict with other classes on misc1
    #ufw::allow { 'mailman3 http':
    #    proto => 'tcp',
    #    port  => '80',
    #}

    # crossed out as would conflict with other classes on misc1
    #ufw::allow { 'mailman3 https':
    #    proto => 'tcp',
    #    port  => '443',
    #}

    motd::role { 'role::mailman':
        description => 'Mail List',
    }
}
