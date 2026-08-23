# type: docker::compose
define docker::compose(
  Enum[present,absent] $ensure = present,
  String $compose_file,
) {
  if $ensure == present {
    $action = 'up -d'
  } else {
    $action = 'down'
  }

  exec { "docker-compose-${title}-${action}":
    command => "/usr/bin/docker compose -f ${compose_file} ${action}",
    cwd     => dirname($compose_file),
    require => [
      Package['docker-ce-cli'],
      Package['docker-compose-plugin'],
    ],
  }
}
