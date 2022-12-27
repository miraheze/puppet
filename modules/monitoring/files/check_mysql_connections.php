<?php

// Parse the command-line options
$options = getopt('', [
    'host:',
    'user:',
    'password:',
    'current-connections:',
    'max-connections:',
    'critical-threshold:',
    'warning-threshold:',
    'ssl-key:',
    'ssl-cert:',
    'ssl-ca:',
    'ssl-verify-server-cert:'
]);

// Check that the required options have been provided
if (!isset($options['host']) || !isset($options['user']) || !isset($options['password']) || !isset($options['max-connections']) || !isset($options['critical-threshold']) || !isset($options['warning-threshold'])) {
    die('Usage: php connection_usage.php --host=HOST --user=USER --password=PASSWORD --max-connections=MAX_CONNECTIONS --critical-threshold=CRITICAL_THRESHOLD --warning-threshold=WARNING_THRESHOLD [--ssl-key=SSL_KEY] [--ssl-cert=SSL_CERT] [--ssl-ca=SSL_CA] [--ssl-verify-server-cert=SSL_VERIFY_SERVER_CERT]' . "\n");
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

if (isset($options['ssl-key'])) {
    $ssl_options['ssl_key'] = $options['ssl-key'];
}

if (isset($options['ssl-cert'])) {
    $ssl_options['ssl_cert'] = $options['ssl-cert'];
}

if (isset($options['ssl-ca'])) {
    $ssl_options['ssl_ca'] = $options['ssl-ca'];
}

if (isset($options['ssl-verify-server-cert'])) {
    $ssl_options['ssl_verify_server_cert'] = (bool) $options['ssl-verify-server-cert'];
}

// Build the connection string
$connection_string = "host=$host;user=$user;password=$pass;";

// Connect with SAL
if (!empty($ssl_options)) {
    $connection_string .= "ssl-key={$ssl_options['ssl_key']};ssl-cert={$ssl_options['ssl_cert']};ssl-ca={$ssl_options['ssl_ca']};";
}

// Connect to the MySQL server using the connection string
$conn = mysqli_init();
$success = mysqli_real_connect($conn, null, null, null, null, null, null, $connection_string);

if (!$success) {
    die('Connection failed: ' . mysqli_connect_error());
    exit(2);
}

if ($conn->connect_error) {
    die('Connection failed: ' . $conn->connect_error);
    exit(2);
}

// Retrieve the current number of connections from the SHOW STATUS output
$result = $conn->query('SHOW STATUS WHERE Variable_name = "Threads_connected"');

if (!$result) {
    die('Query failed: ' . $conn->error);
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
    exit(2);
} elseif ($connection_usage >= $warning_threshold) {
    echo 'Warning connection usage: ' . round($connection_usage, 2) . "%\n";
    exit(1);
} else {
    echo 'OK connection usage: ' . round($connection_usage, 2) . "%\n";
    exit(0);
}
