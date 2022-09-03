# @summary
#   Configures the Icinga 2 CA and the api feature.
#
# @api private
#
class icinga::ca(
) {

  include ::icinga2::pki::ca

  class { '::icinga2::feature::api':
    pki             => 'none',
    accept_commands => true,
  }

}
