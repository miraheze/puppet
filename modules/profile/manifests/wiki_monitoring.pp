# monitoring for user wikis
class profile::wiki_monitoring {

    monitoring::wiki {'s23': }
    
    monitoring::wiki { 'meta':
        testpage => 'Miraheze',
    }

}
