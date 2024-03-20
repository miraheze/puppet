# role: irc
class role::kafka {
    # We need zookeeper also
    class { 'zookeeper': }

    class { 'kafka':
        version       => '1.1.0',
        scala_version => '2.12',
	config => {
            'broker.id'         => '0',
            'zookeeper.connect' => 'localhost:2181',
        }
    }

    system::role { 'kafka':
        description => 'Kafka server',
    }
}
