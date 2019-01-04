# monitoring for user wikis
class profile::wiki_monitoring {

    # to add a wiki to monitoring just add the short name to this array
    $monitored_wikis = [ 'meta', 's23' ]

    monitoring::wiki {'s23': }
    
    monitoring::wiki { 'meta':
        testpage => 'Miraheze',
    }

}
