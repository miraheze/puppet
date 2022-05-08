blacklist /sbin
blacklist /usr/sbin
blacklist /usr/local/sbin

blacklist ${PATH}/umount
blacklist ${PATH}/mount
blacklist ${PATH}/fusermount
blacklist ${PATH}/su
blacklist ${PATH}/sudo
blacklist ${PATH}/xinput
blacklist ${PATH}/evtest
blacklist ${PATH}/xev
blacklist ${PATH}/strace
blacklist ${PATH}/nc
blacklist ${PATH}/ncat

blacklist /etc/ssh
blacklist /var/www/.ssh
blacklist /root
blacklist /home

caps.drop all
