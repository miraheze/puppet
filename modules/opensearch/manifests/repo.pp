# opensearch::repo
#
# @summary Set up the package repository for OpenSearch components
#
# @example
#   include opensearch::repo
#
# @param priority A numeric priority for the repo, passed to the package management system
# @param version The (major) version of the OpenSearch for which to configure the repo
class opensearch::repo (
  Optional[Integer] $priority      = undef,
  String            $version       = '2.x',
) {
  include apt

  file { '/usr/share/keyrings/opensearch.key':
    ensure => present,
    source => 'puppet:///modules/opensearch/apt/opensearch.key',
  }

  apt::source { 'opensearch':
    ensure   => 'present',
    comment  => 'OpenSearch package repository.',
    location => "https://artifacts.opensearch.org/releases/bundle/opensearch/${version}/apt",
    release  => 'stable',
    repos    => 'main',
    keyring  => '/usr/share/keyrings/opensearch.key',
    include  => {
      'deb' => true,
      'src' => false,
    },
    pin      => $priority,
    require  => File['/usr/share/keyrings/opensearch.key'],
  }
}
