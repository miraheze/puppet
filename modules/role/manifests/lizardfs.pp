# role: lizardfs
class role::lizardfs {
    include ::lizardfs

    motd::role { 'role::lizardfs':
        description => 'LizardFS file storage',
    }
}
