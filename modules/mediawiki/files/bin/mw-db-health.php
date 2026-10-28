#!/usr/bin/php
<?php

// Probes each database section and writes the state that MirahezeFunctions (in mw-config) reads.
// Usage: mw-db-health /etc/mw-db-health.json

mysqli_report( MYSQLI_REPORT_OFF );

function readPassword( string $file ): ?string {
	$private = (string)@file_get_contents( $file );
	if ( !preg_match( '/\$wgDBpassword\s*=\s*\'((?:[^\'\\\\]|\\\\.)*)\'/', $private, $m ) ) {
		return null;
	}

	return strtr( $m[1], [ '\\\\' => '\\', "\\'" => "'" ] );
}

/**
 * @return array{healthy: bool, reason: string, drained: bool, drainReason: string}
 */
function probe( string $endpoint, string $user, string $pass, array $cfg, bool $checkDrain, bool $kill ): array {
	[ $host, $port ] = array_pad( explode( ':', $endpoint ), 2, 3306 );
	$result = static fn ( bool $healthy, string $reason = '', bool $drained = true, string $drainReason = '' ): array =>
		compact( 'healthy', 'reason', 'drained', 'drainReason' );

	$start = hrtime( true );
	$db = mysqli_init();
	$db->options( MYSQLI_OPT_CONNECT_TIMEOUT, $cfg['connect_timeout'] );
	$db->options( MYSQLI_OPT_READ_TIMEOUT, $cfg['read_timeout'] );
	if ( !@$db->real_connect( $host, $user, $pass, null, (int)$port ) ) {
		return $result( false, 'connect failed (' . $db->connect_errno . ')' );
	}

	$res = $db->query( 'SELECT @@max_connections' );
	$maxConnections = $res ? (int)$res->fetch_row()[0] : 0;
	$ms = ( hrtime( true ) - $start ) / 1e6;
	if ( !$res ) {
		$db->close();
		return $result( false, 'query failed' );
	}

	if ( $ms > $cfg['slow_ms'] ) {
		$db->close();
		return $result( false, sprintf( 'slow (%d ms)', $ms ) );
	}

	$status = [];
	$res = $db->query(
		"SHOW GLOBAL STATUS WHERE Variable_name IN ('Threads_connected', 'Threads_running')"
	);
	while ( $res && ( $row = $res->fetch_row() ) ) {
		$status[$row[0]] = (int)$row[1];
	}

	if ( !$status ) {
		$db->close();
		return $result( false, 'status query failed' );
	}

	$connected = $status['Threads_connected'] ?? 0;
	if ( $maxConnections && $connected / $maxConnections >= $cfg['max_conn_ratio'] ) {
		$db->close();
		return $result( false, sprintf( 'connections %d/%d', $connected, $maxConnections ) );
	}

	if ( $cfg['max_threads_running'] > 0 && ( $status['Threads_running'] ?? 0 ) >= $cfg['max_threads_running'] ) {
		$db->close();
		return $result( false, 'threads running ' . ( $status['Threads_running'] ?? 0 ) );
	}

	if ( !$checkDrain ) {
		$db->close();
		return $result( true );
	}

	[ $drained, $drainReason ] = checkDrained( $db, $status, $cfg, $kill );
	$db->close();

	return $result( true, '', $drained, $drainReason );
}

/**
 * Whether the server has finished the work it was handed before it went down.
 * Without the PROCESS privilege the list only holds our own user's threads.
 *
 * @return array{0: bool, 1: string}
 */
function checkDrained( mysqli $db, array $status, array $cfg, bool $kill ): array {
	$reasons = [];

	// The status query itself counts as one running thread.
	$running = max( 0, ( $status['Threads_running'] ?? 0 ) - 1 );
	if ( $cfg['drain_max_threads_running'] > 0 && $running > $cfg['drain_max_threads_running'] ) {
		$reasons[] = "$running threads running";
	}

	$res = $db->query( sprintf(
		"SELECT ID, TIME FROM information_schema.PROCESSLIST
			WHERE COMMAND = 'Query' AND ID <> %d AND TIME >= %d AND INFO NOT LIKE 'KILL%%'",
		$db->thread_id,
		$cfg['drain_query_seconds']
	) );

	if ( !$res ) {
		return [ false, 'processlist unavailable' ];
	}

	$old = 0;
	$killed = 0;
	while ( $row = $res->fetch_row() ) {
		$old++;
		if ( $kill && $cfg['kill_after'] > 0 && (int)$row[1] >= $cfg['kill_after'] ) {
			if ( $db->query( 'KILL QUERY ' . (int)$row[0] ) ) {
				$killed++;
			}
		}
	}

	if ( $old > 0 ) {
		$reasons[] = "$old queries over {$cfg['drain_query_seconds']}s" . ( $killed ? " ($killed killed)" : '' );
	}

	return [ $reasons === [], implode( ', ', $reasons ) ];
}

function rampAdmit( array $ramp, int $elapsed ): float {
	$admit = 0.0;
	foreach ( $ramp as [ $after, $ratio ] ) {
		if ( $elapsed >= $after ) {
			$admit = (float)$ratio;
		}
	}

	return $admit;
}

function newState( int $now ): array {
	return [
		'state' => 'up',
		'admit' => 1.0,
		'since' => $now,
		'bad' => 0,
		'good' => 0,
		'reason' => '',
		'holding' => false,
		'held' => 0,
		'downSince' => 0,
	];
}

function advance(
	array $s,
	bool $healthy,
	string $reason,
	int $now,
	array $cfg,
	bool $drained = true,
	string $drainReason = ''
): array {
	$s['reason'] = $healthy ? '' : $reason;
	$s['holding'] = false;

	if ( $s['state'] === 'up' ) {
		$s['bad'] = $healthy ? 0 : $s['bad'] + 1;
		if ( $s['bad'] >= $cfg['down_after'] ) {
			return [
				'state' => 'down',
				'admit' => 0.0,
				'since' => $now,
				'bad' => 0,
				'good' => 0,
				'held' => 0,
				'downSince' => $now,
			] + $s;
		}

		return $s;
	}

	// A drain that never finishes must not keep the section out forever.
	$bypass = $now - $s['downSince'] >= $cfg['drain_timeout'];
	$hold = $healthy && !$drained && !$bypass;
	if ( $hold ) {
		$s['holding'] = true;
		$s['reason'] = $drainReason;
	}

	if ( $s['state'] === 'down' ) {
		$s['good'] = $healthy && !$hold ? $s['good'] + 1 : 0;
		if ( $s['good'] >= $cfg['up_after'] ) {
			$s['state'] = 'recovering';
			$s['since'] = $now;
			$s['held'] = 0;
			$s['admit'] = rampAdmit( $cfg['ramp'], 0 );
		}

		return $s;
	}

	// Recovering. Any bad probe sends the section straight back down.
	if ( !$healthy ) {
		return [ 'state' => 'down', 'admit' => 0.0, 'since' => $now, 'bad' => 0, 'good' => 0 ] + $s;
	}

	// Leftover work freezes the ramp where it is.
	if ( $hold ) {
		$s['held'] += $cfg['interval'];
	}

	$s['admit'] = rampAdmit( $cfg['ramp'], $now - $s['since'] - $s['held'] );
	if ( $s['admit'] >= 1.0 && !$hold ) {
		$s = [ 'state' => 'up', 'admit' => 1.0, 'since' => $now, 'bad' => 0, 'good' => 0 ] + $s;
	}

	return $s;
}

function writeState( string $file, array $states, int $now ): void {
	$sections = [];
	foreach ( $states as $name => $s ) {
		$sections[$name] = [
			'state' => $s['state'],
			'admit' => $s['admit'],
			'since' => $s['since'],
			'reason' => $s['reason'],
		];
	}

	$tmp = $file . '.tmp';
	file_put_contents( $tmp, json_encode( [ 'updated' => $now, 'sections' => $sections ] ) );
	chmod( $tmp, 0644 );
	rename( $tmp, $file );
}

function main( array $argv ): int {
	$cfg = json_decode( (string)@file_get_contents( $argv[1] ?? '' ), true );
	if ( !is_array( $cfg ) || empty( $cfg['sections'] ) ) {
		fwrite( STDERR, "Missing or invalid config.\n" );
		return 1;
	}

	$cfg += [
		'drain_query_seconds' => 30,
		'drain_max_threads_running' => 8,
		'drain_timeout' => 900,
		'kill_after' => 0,
	];

	$pass = readPassword( $cfg['private_settings'] );
	if ( $pass === null ) {
		fwrite( STDERR, "Could not read wgDBpassword.\n" );
		return 1;
	}

	$states = array_map( static fn () => newState( time() ), $cfg['sections'] );

	while ( true ) {
		$cycleStart = microtime( true );

		// Only look at the process list for endpoints that have a section not fully up.
		$out = [];
		foreach ( $cfg['sections'] as $section => $endpoint ) {
			$out[$endpoint] = ( $out[$endpoint] ?? false ) || $states[$section]['state'] !== 'up';
		}

		$results = [];
		foreach ( $cfg['sections'] as $section => $endpoint ) {
			$results[$endpoint] ??= probe(
				$endpoint,
				$cfg['user'],
				$pass,
				$cfg,
				$out[$endpoint],
				$out[$endpoint] && $cfg['kill_after'] > 0
			);
			$r = $results[$endpoint];

			$now = time();
			$before = $states[$section]['state'];
			$wasHolding = $states[$section]['holding'];
			$states[$section] = advance(
				$states[$section],
				$r['healthy'],
				$r['reason'],
				$now,
				$cfg,
				$r['drained'],
				$r['drainReason']
			);

			if ( $states[$section]['state'] !== $before ) {
				fwrite( STDOUT, sprintf(
					"section %s %s -> %s%s\n",
					$section,
					$before,
					$states[$section]['state'],
					$r['reason'] !== '' ? " ({$r['reason']})" : ''
				) );
			}

			if ( $states[$section]['holding'] !== $wasHolding ) {
				fwrite( STDOUT, $states[$section]['holding']
					? "section $section waiting to reopen: {$r['drainReason']}\n"
					: "section $section drained\n"
				);
			}
		}

		writeState( $cfg['state_file'], $states, time() );

		$sleep = $cfg['interval'] - ( microtime( true ) - $cycleStart );
		if ( $sleep > 0 ) {
			usleep( (int)( $sleep * 1e6 ) );
		}
	}
}

if ( !getenv( 'MW_DB_HEALTH_LIB' ) ) {
	exit( main( $argv ) );
}
