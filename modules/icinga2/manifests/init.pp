# == Class: icinga2
#
# This module installs and configures Icinga 2.
class icinga2 {
    include icinga2::repo

    if hiera('icinga2_server', false) {
        include ::icinga2::server
    }

    if hiera('icinga2_web', false) {
        include ::icinga2::web
    }
}
