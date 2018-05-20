# role: mailman3
class role::mailman3 {
    include ::mailman3

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

    motd::role { 'role::mailman3':
        description => 'Mail List',
    }
}
