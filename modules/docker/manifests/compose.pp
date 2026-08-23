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

  $dir = dirname($compose_file)

  exec { "docker-compose-${action}-${dir}":
    command => "docker compose -f ${compose_file} ${action}",
    cwd => $dir,
    path => ['/usr/bin', '/bin'],
  }
}
