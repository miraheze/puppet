Puppet repo for new farm project

How to run puppet (as is!)

apt-get install puppet

clone this repo so manifests and module directories are /etc/puppet/manifests and /etc/puppet/modules

run "puppet apply /etc/puppet/manifests/site.pp"

If you want to test roles, apply them to the default node locally and run.