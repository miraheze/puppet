<?php
// Monitoring helper for PHP-FPM 8.x

// Only consider blocks <5M for the fragmentation
define('BLOCK_SIZE', 5*1024*1024);

$sma_info = null;

function opcache_stats(bool $full = false): array {
	// first of all, check if opcache is enabled
	$stats = opcache_get_status($full);
	if ($stats === false) {
		return [];
	}
	return $stats;
}

function apcu_stats(bool $limited = true ): array {
	global $sma_info;
	if (!function_exists('apcu_cache_info')) {
		return [];
	}
	$cache_info = apcu_cache_info($limited);
	if ($cache_info === false) {
		$cache_info = [];
	}
	if ($sma_info === null) {
		$sma_info = apcu_sma_info();
	}
	if ($sma_info === false) {
		$sma_info = [];
	}
	return array_merge($cache_info, $sma_info);
}

// Returns % of APCu fragmentation
// This code is part of https://github.com/krakjoe/apcu/blob/master/apc.php
function apcu_frag() {
	global $sma_info;
	if ($sma_info === null) {
		$sma_info = apcu_sma_info();
	}
	if ($sma_info === false) {
		$sma_info = [];
	}
	$nseg = $freeseg = $fragsize = $freetotal = 0;
	for($i=0; $i < $sma_info['num_seg']; $i++) {
		$ptr = 0;
		foreach($sma_info['block_lists'][$i] as $block) {
			if ($block['offset'] != $ptr) {
				++$nseg;
			}
			$ptr = $block['offset'] + $block['size'];
			if ($block['size'] < BLOCK_SIZE) {
				$fragsize += $block['size'];
			}
			$freetotal += $block['size'];
		}
		$freeseg += count($sma_info['block_lists'][$i]);
	}
	if ($freeseg > 1) {
		$frag = $fragsize / $freetotal * 100;
	} else {
		$frag = 0;
	}
	return round($frag, 5, PHP_ROUND_HALF_UP);
}

/*

  Very simple class to manage prometheus metrics printing.
  Not intended to be complete or useful outside of this context.

*/
class PrometheusMetric {
	public $description;
	public $key;
	private $value;
	private $labels;
	private $type;

	function __construct(string $key, string $type, string $description) {
		$this->key = $key;
		$this->description = $description;
		// Set labels empty
		// We need to tag the prometheus metrics with the php version as well.
		// Given we sometimes report too much info in PHP_VERSION, let's limit
		// this to major.minor.patch
		$php_ver = preg_filter("/^(\d\.\d+\.\d+).*/", "$1", PHP_VERSION);
		$this->labels = ['php_version="' . $php_ver . '"'];
		$this->type = $type;
	}

	public function setValue($value) {
		if (is_bool($value) === true) {
			$this->value = (int) $value;
		} elseif (is_array($value)) {
			$this->value = implode(" ", $value);
		} else {
			$this->value = $value;
		}
	}

	public function setLabel(string $name, string $value) {
		$this->labels[] = "$name=\"{$value}\"";
	}

	private function _helpLine(): string {
		// If the description is empty, don't return
		// any help header.
		if ($this->description == "") {
			return "";
		}
		return sprintf("# HELP %s %s\n# TYPE %s %s\n",
			$this->key, $this->description,
			$this->key, $this->type
		);
	}

	public function __toString() {
		if ($this->labels != []) {
			$full_name = sprintf('%s{%s}',$this->key, implode(",", $this->labels));
		} else {
			$full_name = $this->key;
		}
		return sprintf(
			"%s%s %s\n",
			$this->_helpLine(),
			$full_name,
			$this->value
		);
	}
}


function prometheus_metrics(): array {
	$oc = opcache_stats();
	$ac = apcu_stats();
	$af = apcu_frag();
	$defs = [
		[
			'name' => 'php_opcache_enabled',
			'type' => 'gauge',
			'desc' => 'Opcache is enabled',
			'value' => $oc['opcache_enabled']
		],
		[
			'name' => 'php_opcache_full',
			'type' => 'gauge',
			'desc' => 'Opcache is full',
			'value' => $oc['cache_full']
		],
		[
			'name' => 'php_opcache_memory',
			'type' => 'gauge',
			'label' => ['type', 'used'],
			'desc' => 'Used memory stats',
			'value' => $oc['memory_usage']['used_memory']
		],
		[
			'name' => 'php_opcache_memory',
			'type' => 'gauge',
			'label' => ['type', 'free'],
			'desc' => '',
			'value' => $oc['memory_usage']['free_memory']
		],
		[
			'name' => 'php_opcache_memory',
			'type' => 'gauge',
			'label' => ['type', 'wasted'],
			'desc' => '',
			'value' => $oc['memory_usage']['wasted_memory']
		],
		[
			'name' => 'php_opcache_wasted_memory',
			'type' => 'gauge',
			'desc' => 'Percentage of wasted memory in opcache',
			'value' => round($oc['memory_usage']['current_wasted_percentage'],5, PHP_ROUND_HALF_UP)
		],
		[
			'name' => 'php_opcache_strings_memory',
			'type' => 'gauge',
			'label' => ['type', 'used'],
			'desc' => 'Memory usage from interned strings',
			'value' => $oc['interned_strings_usage']['used_memory']
		],
		[
			'name' => 'php_opcache_strings_memory',
			'type' => 'gauge',
			'label' => ['type', 'free'],
			'desc' => '',
			'value' => $oc['interned_strings_usage']['free_memory']
		],
		[
			'name' => 'php_opcache_strings_numbers',
			'type' => 'gauge',
			'desc' => 'Memory usage from interned strings',
			'value' => $oc['interned_strings_usage']['number_of_strings'],
		],
		[
			'name' => 'php_opcache_stats_cached',
			'type' => 'gauge',
			'label' => ['type', 'scripts'],
			'desc' => 'Stats about cached objects',
			'value' => $oc['opcache_statistics']['num_cached_scripts']
		],
		[
			'name' => 'php_opcache_stats_cached',
			'type' => 'gauge',
			'label' => ['type', 'keys'],
			'desc' => '',
			'value' => $oc['opcache_statistics']['num_cached_keys']
		],
		[
			'name' => 'php_opcache_stats_cached',
			'type' => 'counter',
			'label' => ['type', 'max_keys'],
			'desc' => '',
			'value' => $oc['opcache_statistics']['max_cached_keys']
		],
		[
			'name' => 'php_opcache_stats_cache_hit',
			'type' => 'counter',
			'label' => ['type', 'hits'],
			'desc' => 'Stats about cached object hit/miss ratio',
			'value' => $oc['opcache_statistics']['hits']
		],
		[
			'name' => 'php_opcache_stats_cache_hit',
			'type' => 'counter',
			'label' => ['type', 'misses'],
			'desc' => '',
			'value' => $oc['opcache_statistics']['misses']
		],
		[
			'name' => 'php_opcache_stats_cache_hit',
			'type' => 'counter',
			'label' => ['type', 'total'],
			'desc' => '',
			'value' => ($oc['opcache_statistics']['misses'] + $oc['opcache_statistics']['hits'])
		],
		[
			'name' => 'php_apcu_num_slots',
			'type' => 'counter',
			'desc' => 'Number of distinct APCu slots available',
			'value' => $ac['num_slots'],
		],
		[
			'name' => 'php_apcu_cache_ops',
			'type' => 'counter',
			'label' => ['type', 'hits'],
			'desc' => 'Stats about APCu operations',
			'value' => $ac['num_hits'],
		],
		[
			'name' => 'php_apcu_cache_ops',
			'type' => 'counter',
			'label' => ['type', 'misses'],
			'desc' => '',
			'value' => $ac['num_misses'],
		],
		[
			'name' => 'php_apcu_cache_ops',
			'type' => 'counter',
			'label' => ['type', 'total_gets'],
			'desc' => '',
			'value' => ($ac['num_misses'] + $ac['num_hits']),
		],
		[
			'name' => 'php_apcu_cache_ops',
			'type' => 'counter',
			'label' => ['type', 'inserts'],
			'desc' => '',
			'value' => $ac['num_inserts'],
		],
		[
			'name' => 'php_apcu_cache_ops',
			'type' => 'counter',
			'label' => ['type', 'entries'],
			'desc' => '',
			'value' => $ac['num_entries'],
		],
		[
			'name' => 'php_apcu_cache_ops',
			'type' => 'counter',
			'label' => ['type', 'expunges'],
			'desc' => '',
			'value' => $ac['expunges'],
		],
		[
			'name' => 'php_apcu_memory',
			'type' => 'gauge',
			'label' => ['type', 'free'],
			'desc' => 'APCu memory status',
			'value' => $ac['avail_mem'],
		],
		[
			'name' => 'php_apcu_memory',
			'type' => 'gauge',
			'label' => ['type', 'total'],
			'desc' => '',
			'value' => $ac['seg_size'],
		],
		[
			'name' => 'php_apcu_fragmentation',
			'type' => 'gauge',
			'desc' => 'APCu fragementation percentage',
			'value' => $af,
		],
	];
	$metrics = [];
	foreach ($defs as $metric_def) {
		$t = isset($metric_def['type'])? $metric_def['type'] : 'counter';
		$p = new PrometheusMetric($metric_def['name'], $t, $metric_def['desc']);
		if (isset($metric_def['label'])) {
			$p->setLabel(...$metric_def['label']);
		}
		if (isset($metric_def['value'])) {
			$p->setValue($metric_def['value']);
		}
		$metrics[] = $p;
	}
	return $metrics;
}


/**
 * Simple class to manage combining prometheus metrics from multiple ports/php versions
 */
class RemoteMetrics {
	const ADMIN_PORT_BASE = 9181;

	function __construct() {}

	private static function _url($port) {
		return sprintf("http://localhost:%d/local-metrics", $port);
	}

	private function _get_remote_metrics() {
		$output = "";
		return $output;
	}

	public function show_metrics() {
		echo $this->_get_remote_metrics();
	}
}

function dump_file($name, $contents) {
	if (is_file($name)) {
		if (!unlink($name)) {
			die("Could not remove {$name}.\n");
		}
	}
	file_put_contents(
		$name,
		json_encode($contents)
	);
	echo "Requested data dumped at {$name}.\n";
}

// Views
function show_prometheus_metrics() {
	header("Content-Type: text/plain");
	foreach (prometheus_metrics() as $k) {
		printf("%s", $k);
	}
}

function show_all_prometheus_metrics() {
	show_prometheus_metrics();
	$rm = new RemoteMetrics();
	$rm->show_metrics();
}

function show_apcu_info() {
	header("Content-Type: application/json");
	print json_encode(apcu_stats());
}

function show_apcu_frag() {
	header("Content-Type: application/json");
	print json_encode(array('fragmentation'=>apcu_frag()));
}

function dump_apcu_full() {
	header("Content-Type: text/plain");
	$stats = apcu_stats(true);
	dump_file('/tmp/apcu_dump_meta', $stats['cache_list']);
}

function clear_apcu() {
	header("Content-Type: text/plain");
	apcu_clear_cache();
	echo "APCu cache cleared\n";
}

function show_opcache_info() {
	header("Content-Type: application/json");
	print json_encode(opcache_stats());
}

function dump_opcache_meta() {
	header("Content-Type: text/plain");
	$oc = opcache_stats(true);
	dump_file('/tmp/opcache_dump_meta', $oc['scripts']);
}

function clear_opcache() {
	header("Content-Type: text/plain");
	opcache_reset();
}

function ini_value() {
	header("Content-Type: application/json");
	$all_ini_values = ini_get_all();
	if (isset($_GET['key'])) {
		$key = $_GET['key'];
		if (array_key_exists($key, $all_ini_values)) {
			$val = $all_ini_values[$key];
			print json_encode([$key => $val]);
		} else {
			http_response_code(400);
			print json_encode(['error' => "parameter '$key' not found"]);
		}
	} else {
		print json_encode($all_ini_values);
	}
	# Add a new line to beautify output on the console
	print "\n";
}

