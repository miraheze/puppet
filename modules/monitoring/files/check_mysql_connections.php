<?php

/**
 * Monitor the connection usage of a MySQL server.
 *
 * Usage:
 *   php check_mysql_connections.php --host=HOST --user=USER --password=PASSWORD --max-connections=MAX_CONNECTIONS --critical-threshold=CRITICAL_THRESHOLD --warning-threshold=WARNING_THRESHOLD
 *
 * @author Universal Omega
 */

ini_set( 'display_errors', 'stderr' );

// Parse the command-line options
$options = getopt( '', [
	'host:',
	'user:',
	'password:',
	'current-connections:',
	'max-connections:',
	'critical-threshold:',
	'warning-threshold:',
] );

// Check that the required options have been provided
if (
	!isset( $options['host'] ) ||
	!isset( $options['user'] ) ||
	!isset( $options['password'] ) ||
	!isset( $options['max-connections'] ) ||
	!isset( $options['critical-threshold'] ) ||
	!isset( $options['warning-threshold'] )
) {
	die( 'Usage: php check_mysql_connections.php --host=HOST --user=USER --password=PASSWORD --max-connections=MAX_CONNECTIONS --critical-threshold=CRITICAL_THRESHOLD --warning-threshold=WARNING_THRESHOLD' . "\n" );
}

// Parse the options
$host = $options['host'];
$user = $options['user'];
$pass = $options['password'];
$max_connections = (int)$options['max-connections'];
$critical_threshold = (int)$options['critical-threshold'];
$warning_threshold = (int)$options['warning-threshold'];

// Connect to the MySQL server
$conn = mysqli_init();
$success = mysqli_real_connect( $conn, $host, $user, $pass, null, null, null, false );

if ( !$success ) {
	echo 'Connection failed: ' . mysqli_connect_error();
	exit( 2 );
}

// Retrieve the current number of connections from the SHOW STATUS output
$result = $conn->query('SHOW STATUS WHERE Variable_name = "Threads_connected"');

if ( !$result ) {
	echo 'Query failed: ' . $conn->error;
	exit( 2 );
}

$row = $result->fetch_assoc();
$current_connections = (int)$row['Value'];

$result->free();

// Calculate the connection usage percentage
$connection_usage = $current_connections / $max_connections * 100;

// Display a message and exit status based on the connection usage percentage
if ( $connection_usage >= $critical_threshold ) {
	echo 'Critical connection usage: ' . round($connection_usage, 2) . "%\n";
	echo 'Current connections: ' . $current_connections;
	exit( 2 );
} elseif ( $connection_usage >= $warning_threshold ) {
	echo 'Warning connection usage: ' . round($connection_usage, 2) . "%\n";
	echo 'Current connections: ' . $current_connections;
	exit( 1 );
} else {
	echo 'OK connection usage: ' . round($connection_usage, 2) . "%\n";
	echo 'Current connections: ' . $current_connections;
	exit( 0 );
}
