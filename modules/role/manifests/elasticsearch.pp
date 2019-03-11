# role: elasticsearch
class role::elasticsearch {
    include ::java

    class { 'elasticsearch': }
    elasticsearch::instance { 'es-01': }

    motd::role { 'role::elasticsearch':
        description => 'elasticsearch server',
    }
}
