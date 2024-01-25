# PRIVATE CLASS: do not use directly
class mongodb::repo::apt inherits mongodb::repo {
  # we try to follow/reproduce the instruction
  # from http://docs.mongodb.org/manual/tutorial/install-mongodb-on-ubuntu/

  include apt

  if($mongodb::repo::ensure == 'present' or $mongodb::repo::ensure == true) {
    $mongover = split($mongodb::repo::version, '[.]')
    if ("${mongover[0]}.${mongover[1]}" == '7.0') {
      apt::source { 'mongodb':
        location => $mongodb::repo::location,
        release  => $mongodb::repo::release,
        repos    => $mongodb::repo::repos,
        key      => {
          'name'   => "mongodb-server-${mongover[0]}.${mongover[1]}.gpg",
          'source' => "puppet:///modules/mongodb/apt/mongodb-server-${mongover[0]}.${mongover[1]}.gpg",
        },
      }
    } else {
      apt::source { 'mongodb':
        location => $mongodb::repo::location,
        release  => $mongodb::repo::release,
        repos    => $mongodb::repo::repos,
        key      => {
          'id'      => $mongodb::repo::key,
          'server'  => $mongodb::repo::key_server,
          'options' => $mongodb::repo::aptkey_options,
        },
      }
    }

    Apt::Source['mongodb'] -> Class['apt::update'] -> Package<| tag == 'mongodb_package' |>
  }
  else {
    apt::source { 'mongodb':
      ensure => absent,
    }
  }
}
