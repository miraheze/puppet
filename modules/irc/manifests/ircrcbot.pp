# class: irc::ircrcbot
class irc::ircrcbot(
    $nickname   = undef,
    $network    = undef,
    $channel    = undef,
    $port       = '5070',
    $sleeptime  = '0.5',
) {
    include ::irc
    
    file { '/usr/local/bin/ircrcbot.py':
        ensure  => present,
        content => template('irc/ircrcbot.py'),
    }
}
