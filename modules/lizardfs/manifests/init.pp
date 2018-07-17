# == Class: lizardfs

class lizardfs {

    if hiera('lizardfs_master', false) {
        include lizardfs::master
    }

    if hiera('lizardfs_storage', false) {
        include lizardfs::storage
    }

    if hiera('lizardfs_web', false) {
        include lizardfs::web
    }
}
