# class: role::db
class role::db {
    include ::cloud
    
    motd::role { 'role::cloud':
        description => 'cloud virts to host own vps using proxmox',
    }
}
