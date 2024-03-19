# == Class: graphite::monitoring::graphite
#
# Monitor a graphite stack for important vitals, namely what it is interesting
# if we are losing data and how much.
# To that end, both "carbon-relay" (what accepts metrics from the outside) and
# "carbon-cache" (what read/writes datapoints from/to disk) are monitored, e.g.
# if there is any dropping of datapoints in their queues or errors otherwise.

class graphite::monitoring::graphite (
    Stdlib::HTTPUrl $graphite_url = 'https://graphite.wikitide.net/',
) {
    monitoring::graphite_threshold {
        default:
            graphite_url    => $graphite_url,
            percentage      => 80,
            nagios_critical => false,
            notes_link      => 'https://meta.miraheze.org/wiki/Tech:Graphite';
        'carbon-frontend-relay_drops':
            description => 'carbon-frontend-relay metric drops',
            metric      => 'sumSeries(transformNull(perSecond(carbon.relays.graphite*_frontend.destinations.*.dropped)))',
            from        => '5minutes',
            warning     => 25,
            critical    => 100;
        'carbon-local-relay_drops':
            description => 'carbon-local-relay metric drops',
            metric      => 'sumSeries(transformNull(perSecond(carbon.relays.graphite*_local.destinations.*.dropped)))',
            from        => '5minutes',
            warning     => 25,
            critical    => 100;
        # is carbon-cache able to write to disk (e.g. permissions)
        'carbon-cache_write_error':
            description => 'carbon-cache write error',
            metric      => 'secondYAxis(sumSeries(carbon.agents.mon181-*.errors))',
            from        => '10minutes',
            warning     => 1,
            critical    => 8;
        # are carbon-cache queues overflowing their capacity?
        'carbon-cache_overflow':
            description => 'carbon-cache queues overflow',
            metric      => 'secondYAxis(sumSeries(carbon.agents.mon181-*.cache.overflow))',
            from        => '10minutes',
            warning     => 1,
            critical    => 8;
        # are we creating too many metrics?
        'carbon-cache_many_creates':
            description => 'carbon-cache too many creates',
            metric      => 'sumSeries(carbon.agents.mon181-*.creates)',
            from        => '30min',
            warning     => 500,
            critical    => 1000;
    }
}
