# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure('2') do |config|
  debian_script = <<-SCRIPT
  dpkg -s puppet-agent >/dev/null
  if [ $? -ne 0 ]; then
    wget http://apt.puppet.com/puppet7-release-focal.deb
    dpkg -i puppet7-release-focal.deb
    apt-get update
    apt-get install -y puppet-agent
  fi
  SCRIPT

  debian_systemd_script = <<-SCRIPT
  # To make init.d jobs work with systemd
  apt-get install -y init-system-helpers
  SCRIPT

  rhel_script = <<-SCRIPT
  yum install -y https://yum.puppet.com/puppet7/puppet7-release-el-8.noarch.rpm
  yum install -y puppet-agent
  yum install -y rubygems
  SCRIPT


  # Using a custom shell provisioner to run Puppet because the vagrant puppet
  # provisioner does not work for me...
  common_script = <<-SCRIPT
  ln -sf /vagrant /etc/puppetlabs/code/environments/production/modules/graylog

  # Required to run graylog::allinone
  test -d /etc/puppetlabs/code/environments/production/modules/apt || puppet module install puppetlabs-apt
  test -d /etc/puppetlabs/code/environments/production/modules/mongodb || puppet module install puppet-mongodb
  test -d /etc/puppetlabs/code/environments/production/modules/opensearch || puppet module install puppet-opensearch

  cp /home/vagrant/site.pp /etc/puppetlabs/code/environments/production/manifests/

  puppet apply --show_diff /etc/puppetlabs/code/environments/production/manifests/site.pp
  SCRIPT

  config.vm.provision 'file', source: 'tests/vagrant.pp',
                              destination: '/home/vagrant/site.pp'

  config.vm.define 'ubuntu2004' do |machine|
    machine.vm.box = 'geerlingguy/ubuntu2004'
    machine.vm.network 'private_network', type: 'dhcp'
    machine.vm.network "forwarded_port", guest: 9000, host: 9000
    machine.vm.network "forwarded_port", guest: 12900, host: 12900

    machine.vm.provision 'debian', type: 'shell', inline: debian_script
    machine.vm.provision 'debian-systemd', type: 'shell', inline: debian_systemd_script
    machine.vm.provision 'common', type: 'shell', inline: common_script
  end

  config.vm.define 'rockylinux8' do |machine|
    machine.vm.box = "geerlingguy/rockylinux8"

    machine.vm.network 'private_network', type: 'dhcp'
    machine.vm.network "forwarded_port", guest: 9000, host: 9000
    machine.vm.network "forwarded_port", guest: 12900, host: 12900

    machine.vm.provision "shell", inline: rhel_script
    machine.vm.provision "puppet" do |machine|
      machine.manifests_path = "tests/install/manifests"
      machine.manifest_file = "puppetserver.pp"
    end

    machine.vm.provision 'common', type: 'shell', inline: common_script
  end

  config.vm.provider 'virtualbox' do |v|
    v.memory = 4096
    v.cpus = 4
  end
end
