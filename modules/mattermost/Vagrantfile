# -*- mode: ruby -*-
# vi: set ft=ruby :

$el = <<'EL'
setenforce 0
release=$(sed -r 's/^.* ([0-9]).*$/\1/g' /etc/redhat-release)
rpm -q puppet6-release || yum -y install https://yum.puppetlabs.com/puppet6/puppet6-release-el-${release}.noarch.rpm
rpm -q puppet-agent || yum -y install puppet-agent
EL

$centos6 = <<CENTOS6
service iptables status || {
  yum -y install authconfig system-config-firewall-base
  lokkit --default=server
  service iptables restart
}
CENTOS6

$debian = <<DEBIAN
if grep UBUNTU_CODENAME /etc/os-release ; then
  release=$(grep UBUNTU_CODENAME /etc/os-release|cut -f2 -d'=')
else
  release=$(dpkg --status tzdata|grep Provides|cut -f2 -d'-')
fi
if [ "$release" == "wheezy" ]; then
  version='5'
else
  version='6'
fi
if [ "$release" == "disco" ] || [ "$release" == "buster" ]; then
  if ! dpkg -l puppet ; then
    apt-get update
    apt-get -y install apt-transport-https wget
    apt-get -y install puppet
  fi
else 
  if ! dpkg -l puppet-agent ; then
    apt-get update
    apt-get -y install apt-transport-https wget
    wget https://apt.puppetlabs.com/puppet${version}-release-${release}.deb
    dpkg -i puppet${version}-release-${release}.deb
    apt-get update
    apt-get -y install puppet-agent
  fi
fi
DEBIAN

$module = <<MODULE
rm -rf /vagrant/vagrant/puppet/environments/dev/modules/mattermost
mkdir -p /vagrant/vagrant/puppet/environments/dev/modules/mattermost
cp -R /vagrant/manifests /vagrant/vagrant/puppet/environments/dev/modules/mattermost
cp -R /vagrant/templates /vagrant/vagrant/puppet/environments/dev/modules/mattermost
cp -R /vagrant/lib /vagrant/vagrant/puppet/environments/dev/modules/mattermost
rm -rf /vagrant/vagrant/puppet/environments/dev/modules/mattermost
mkdir -p /tmp/vagrant-puppet/environments/dev/modules/mattermost
cp -R /vagrant/manifests /tmp/vagrant-puppet/environments/dev/modules/mattermost
cp -R /vagrant/templates /tmp/vagrant-puppet/environments/dev/modules/mattermost
cp -R /vagrant/lib /tmp/vagrant-puppet/environments/dev/modules/mattermost
MODULE

Vagrant.configure("2") do |config|
  if Vagrant.has_plugin?("vagrant-hostmanager")
    config.hostmanager.enabled = true
    config.hostmanager.manage_host = true
    config.hostmanager.manage_guest = true
    config.hostmanager.ignore_private_ip = false
    config.hostmanager.include_offline = true
  end
  config.vm.define "centos6" do |host|
    host.vm.box = "centos/6"
    host.vm.hostname = "centos6.test"
    host.vm.network :private_network, ip: "172.16.3.6"
    host.r10k.puppet_dir = "vagrant/puppet/environments/dev"
    host.r10k.module_path = 'vagrant/puppet/environments/dev/modules'
    host.r10k.puppetfile_path = "vagrant/puppet/environments/dev/Puppetfile"
    host.vm.provision "shell", inline: $el
    host.vm.provision "shell", inline: $centos6
    host.vm.provision "shell", inline: $module
    host.vm.provision "puppet" do |puppet|
      puppet.environment_path = "vagrant/puppet/environments"
      puppet.environment = "dev"
      puppet.hiera_config_path = "vagrant/puppet/environments/dev/hiera.yaml"
    end
  end
  config.vm.define "centos6env" do |host|
    host.vm.box = "centos/6"
    host.vm.hostname = "centos6env.test"
    host.vm.network :private_network, ip: "172.16.3.12"
    host.r10k.puppet_dir = "vagrant/puppet/environments/dev"
    host.r10k.module_path = 'vagrant/puppet/environments/dev/modules'
    host.r10k.puppetfile_path = "vagrant/puppet/environments/dev/Puppetfile"
    host.vm.provision "shell", inline: $el
    host.vm.provision "shell", inline: $centos6
    host.vm.provision "shell", inline: $module
    host.vm.provision "puppet" do |puppet|
      puppet.environment_path = "vagrant/puppet/environments"
      puppet.environment = "dev"
      puppet.hiera_config_path = "vagrant/puppet/environments/dev/hiera.yaml"
      puppet.options = "--verbose --debug"
    end
  end
  config.vm.define "centos7" do |host|
    host.vm.box = "centos/7"
    host.vm.hostname = "centos7.test"
    host.vm.network :private_network, ip: "172.16.3.7"
    host.vm.synced_folder ".", "/vagrant", type: "rsync", rsync__exclude: ".git/"
    host.r10k.puppet_dir = "vagrant/puppet/environments/dev"
    host.r10k.module_path = 'vagrant/puppet/environments/dev/modules'
    host.r10k.puppetfile_path = "vagrant/puppet/environments/dev/Puppetfile"
    host.vm.provision "shell", inline: $el
    host.vm.provision "shell", inline: $module
    host.vm.provision "puppet" do |puppet|
      puppet.environment_path = "vagrant/puppet/environments"
      puppet.environment = "dev"
      puppet.hiera_config_path = "vagrant/puppet/environments/dev/hiera.yaml"
      puppet.synced_folder_type ="rsync"
    end
  end
  config.vm.define "centos7env" do |host|
    host.vm.box = "centos/7"
    host.vm.hostname = "centos7env.test"
    host.vm.network :private_network, ip: "172.16.3.14"
    host.vm.synced_folder ".", "/vagrant", type: "rsync", rsync__exclude: ".git/"
    host.r10k.puppet_dir = "vagrant/puppet/environments/dev"
    host.r10k.module_path = 'vagrant/puppet/environments/dev/modules'
    host.r10k.puppetfile_path = "vagrant/puppet/environments/dev/Puppetfile"
    host.vm.provision "shell", inline: $el
    host.vm.provision "shell", inline: $module
    host.vm.provision "puppet" do |puppet|
      puppet.environment_path = "vagrant/puppet/environments"
      puppet.environment = "dev"
      puppet.hiera_config_path = "vagrant/puppet/environments/dev/hiera.yaml"
      puppet.synced_folder_type ="rsync"
    end
  end
  config.vm.define "centos7pkg" do |host|
    host.vm.box = "centos/7"
    host.vm.hostname = "centos7pkg.test"
    host.vm.network :private_network, ip: "172.16.3.21"
    host.r10k.puppet_dir = "vagrant/puppet/environments/dev"
    host.r10k.module_path = 'vagrant/puppet/environments/dev/modules'
    host.r10k.puppetfile_path = "vagrant/puppet/environments/dev/Puppetfile"
    host.vm.provision "shell", inline: $el
    host.vm.provision "shell", inline: $module
    host.vm.provision "puppet" do |puppet|
      puppet.environment_path = "vagrant/puppet/environments"
      puppet.environment = "dev"
      puppet.hiera_config_path = "vagrant/puppet/environments/dev/hiera.yaml"
    end
  end
  # RHEL boxes require registration
  # See: https://github.com/projectatomic/adb-vagrant-registration
  # See: https://github.com/projectatomic/adb-vagrant-registration/issues/126#issuecomment-380931941
  config.vm.define "rhel8" do |host|
    host.vm.box = "generic/rhel8"
    host.vm.hostname = "rhel8.test"
    host.vm.network :private_network, ip: "172.16.18.8"
    host.vm.synced_folder ".", "/vagrant", type: "rsync", rsync__exclude: ".git/"
    host.r10k.puppet_dir = "vagrant/puppet/environments/dev"
    host.r10k.module_path = 'vagrant/puppet/environments/dev/modules'
    host.r10k.puppetfile_path = "vagrant/puppet/environments/dev/Puppetfile"
    host.vm.provision "shell", inline: $el
    host.vm.provision "shell", inline: $module
    host.vm.provision "puppet" do |puppet|
      puppet.environment_path = "vagrant/puppet/environments"
      puppet.environment = "dev"
      puppet.hiera_config_path = "vagrant/puppet/environments/dev/hiera.yaml"
    end
  end
  config.vm.define "wheezyenv" do |host|
    host.vm.box = "alxgrh/debian-wheezy-x86_64"
    host.vm.hostname = "wheezyenv.test"
    host.vm.network :private_network, ip: "172.16.4.14"
    host.vm.synced_folder ".", "/vagrant", type: "nfs", nfs_version: 3, nfs_udp: false
    host.r10k.puppet_dir = "vagrant/puppet/environments/dev"
    host.r10k.module_path = 'vagrant/puppet/environments/dev/modules'
    host.r10k.puppetfile_path = "vagrant/puppet/environments/dev/Puppetfile"
    host.vm.provision "shell", inline: $debian
    host.vm.provision "shell", inline: $module
    host.vm.provision "puppet" do |puppet|
      puppet.environment_path = "vagrant/puppet/environments"
      puppet.environment = "dev"
      puppet.hiera_config_path = "vagrant/puppet/environments/dev/hiera.yaml"
    end
  end
  config.vm.define "stretch" do |host|
    host.vm.box = "generic/debian9"
    host.vm.hostname = "stretch.test"
    host.vm.network :private_network, ip: "172.16.4.9"
    host.vm.synced_folder ".", "/vagrant", type: "nfs", nfs_version: 3, nfs_udp: false
    host.r10k.puppet_dir = "vagrant/puppet/environments/dev"
    host.r10k.module_path = 'vagrant/puppet/environments/dev/modules'
    host.r10k.puppetfile_path = "vagrant/puppet/environments/dev/Puppetfile"
    host.vm.provision "shell", inline: $debian
    host.vm.provision "shell", inline: $module
    host.vm.provision "puppet" do |puppet|
      puppet.environment_path = "vagrant/puppet/environments"
      puppet.environment = "dev"
      puppet.hiera_config_path = "vagrant/puppet/environments/dev/hiera.yaml"
    end
  end
  config.vm.define "buster" do |host|
    host.vm.box = "generic/debian10"
    host.vm.hostname = "buster.test"
    host.vm.network :private_network, ip: "172.16.4.10"
    host.vm.synced_folder ".", "/vagrant", type: "nfs", nfs_version: 3, nfs_udp: false
    host.r10k.puppet_dir = "vagrant/puppet/environments/dev"
    host.r10k.module_path = 'vagrant/puppet/environments/dev/modules'
    host.r10k.puppetfile_path = "vagrant/puppet/environments/dev/Puppetfile"
    host.vm.provision "shell", inline: $debian
    host.vm.provision "shell", inline: $module
    host.vm.provision "puppet" do |puppet|
      puppet.environment_path = "vagrant/puppet/environments"
      puppet.environment = "dev"
      puppet.hiera_config_path = "vagrant/puppet/environments/dev/hiera.yaml"
    end
  end
  config.vm.define "trustyenv" do |host|
    host.vm.box = "peru/ubuntu-14.04-server-amd64"
    host.vm.hostname = "trustyenv.test"
    host.vm.network :private_network, ip: "172.16.21.28"
    host.vm.synced_folder ".", "/vagrant", type: "nfs", nfs_version: 3, nfs_udp: false
    host.r10k.puppet_dir = "vagrant/puppet/environments/dev"
    host.r10k.module_path = 'vagrant/puppet/environments/dev/modules'
    host.r10k.puppetfile_path = "vagrant/puppet/environments/dev/Puppetfile"
    host.vm.provision "shell", inline: $debian
    host.vm.provision "shell", inline: $module
    host.vm.provision "puppet" do |puppet|
      puppet.environment_path = "vagrant/puppet/environments"
      puppet.environment = "dev"
      puppet.hiera_config_path = "vagrant/puppet/environments/dev/hiera.yaml"
    end
  end
  config.vm.define "xenial" do |host|
    host.vm.box = "generic/ubuntu1604"
    host.vm.hostname = "xenial.test"
    host.vm.network :private_network, ip: "172.16.21.16"
    host.vm.synced_folder ".", "/vagrant", type: "nfs", nfs_version: 3, nfs_udp: false
    host.r10k.puppet_dir = "vagrant/puppet/environments/dev"
    host.r10k.module_path = 'vagrant/puppet/environments/dev/modules'
    host.r10k.puppetfile_path = "vagrant/puppet/environments/dev/Puppetfile"
    host.vm.provision "shell", inline: $debian
    host.vm.provision "shell", inline: $module
    host.vm.provision "puppet" do |puppet|
      puppet.environment_path = "vagrant/puppet/environments"
      puppet.environment = "dev"
      puppet.hiera_config_path = "vagrant/puppet/environments/dev/hiera.yaml"
    end
  end
  config.vm.define "disco" do |host|
    host.vm.box = "generic/ubuntu1904"
    host.vm.hostname = "disco.test"
    host.vm.network :private_network, ip: "172.16.21.19"
    host.vm.synced_folder ".", "/vagrant", type: "nfs", nfs_version: 3, nfs_udp: false
    host.r10k.puppet_dir = "vagrant/puppet/environments/dev"
    host.r10k.module_path = 'vagrant/puppet/environments/dev/modules'
    host.r10k.puppetfile_path = "vagrant/puppet/environments/dev/Puppetfile"
    host.vm.provision "shell", inline: $debian
    host.vm.provision "shell", inline: $module
    host.vm.provision "puppet" do |puppet|
      puppet.environment_path = "vagrant/puppet/environments"
      puppet.environment = "dev"
      puppet.hiera_config_path = "vagrant/puppet/environments/dev/hiera.yaml"
    end
  end
end
