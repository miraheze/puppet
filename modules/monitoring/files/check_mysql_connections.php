<?php

/**
 * Monitor the connection usage of a MySQL server.
 *
 * Usage:
 *   php check_mysql_connections.php --host=HOST --user=USER --password=PASSWORD --max-connections=MAX_CONNECTIONS --critical-threshold=CRITICAL_THRESHOLD --warning-threshold=WARNING_THRESHOLD [--ssl-ca=SSL_CA] [--ssl-verify-server-cert=SSL_VERIFY_SERVER_CERT]
 *
 * @author Universal Omega
 */

// Parse the command-line options
$options = getopt('', [
	'host:',
	'user:',
	'password:',
	'current-connections:',
	'max-connections:',
	'critical-threshold:',
	'warning-threshold:',
	'ssl-ca:',
	'ssl-verify-server-cert:'
]);

// Check that the required options have been provided
if (!isset($options['host']) || !isset($options['user']) || !isset($options['password']) || !isset($options['max-connections']) || !isset($options['critical-threshold']) || !isset($options['warning-threshold'])) {
	die('Usage: php check_mysql_connections.php --host=HOST --user=USER --password=PASSWORD --max-connections=MAX_CONNECTIONS --critical-threshold=CRITICAL_THRESHOLD --warning-threshold=WARNING_THRESHOLD [--ssl-ca=SSL_CA] [--ssl-verify-server-cert=SSL_VERIFY_SERVER_CERT]' . "\n");
}

// Parse the options
$host = $options['host'];
$user = $options['user'];
$pass = $options['password'];
$max_connections = (int) $options['max-connections'];
$critical_threshold = (int) $options['critical-threshold'];
$warning_threshold = (int) $options['warning-threshold'];

// Build the SSL options array
$ssl_options = [];

if (isset($options['ssl-ca'])) {
	$ssl_options['ca'] = $options['ssl-ca'];
}

if (isset($options['ssl-verify-server-cert'])) {
	$ssl_options['verify_server_cert'] = (bool) $options['ssl-verify-server-cert'];
}

// Connect to the MySQL server using SSL
$conn = mysqli_init();

if (!empty($ssl_options)) {
	mysqli_ssl_set($conn, null, null, $ssl_options['ca'], null, null);
}

// Connect to the MySQL server
$success = mysqli_real_connect($conn, $host, $user, $pass, null, null, null, $ssl_options['verify_server_cert']);

if (!$success) {
	echo 'Connection failed: ' . mysqli_connect_error();
	exit(2);
}

// Retrieve the current number of connections from the SHOW STATUS output
$result = $conn->query('SHOW STATUS WHERE Variable_name = "Threads_connected"');

if (!$result) {
	echo 'Query failed: ' . $conn->error;
	exit(2);
}

$row = $result->fetch_assoc();
$current_connections = (int) $row['Value'];

$result->free();

// Calculate the connection usage percentage
$connection_usage = $current_connections / $max_connections * 100;

// Display a message and exit status based on the connection usage percentage
if ($connection_usage >= $critical_threshold) {
	echo 'Critical connection usage: ' . round($connection_usage, 2) . "%\n";
	echo 'Current connections: ' . $current_connections;
	exit(2);
} elseif ($connection_usage >= $warning_threshold) {
	echo 'Warning connection usage: ' . round($connection_usage, 2) . "%\n";
	echo 'Current connections: ' . $current_connections;
	exit(1);
} else {
	echo 'OK connection usage: ' . round($connection_usage, 2) . "%\n";
	echo 'Current connections: ' . $current_connections;
	exit(0);
}
