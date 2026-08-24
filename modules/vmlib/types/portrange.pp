# Validates a colon separated port range, like '5900:5999', the same shape
# ferm's own dport ranges already use. Each side is checked as a real 0-65535
# port number, not just "some digits".
type VMlib::Portrange = Pattern[/\A(?x:
    (?:
        [0-9]{1,4}|[1-5][0-9]{4}|
        6[0-4][0-9]{3}|
        65[0-4][0-9]{2}|
        655[0-2][0-9]|
        6553[0-5]
    ):(?:
        [0-9]{1,4}|
        [1-5][0-9]{4}|
        6[0-4][0-9]{3}|
        65[0-4][0-9]{2}|
        655[0-2][0-9]|
        6553[0-5]
    )
\z)/]
