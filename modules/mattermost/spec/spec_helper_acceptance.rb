require 'beaker-rspec'
require 'beaker/puppet_install_helper'
require 'beaker/module_install_helper'

UNSUPPORTED_PLATFORMS = %w(windows Darwin).freeze

run_puppet_install_helper
install_ca_certs unless ENV['PUPPET_INSTALL_TYPE'] =~ %r{pe}i
install_module_on(hosts)
install_module_from_forge_on(hosts, 'puppetlabs/postgresql', '>= 4.0.0 <5.0.0')
install_module_from_forge_on(hosts, 'puppet/nginx', '>= 0.5.0 <1.0.0')
install_module_dependencies_on(hosts)

RSpec.configure do |c|
  # Project root
  proj_root = File.expand_path(File.join(File.dirname(__FILE__), '..'))

  # Readable test descriptions
  c.formatter = :documentation

  # Configure all nodes in nodeset
  c.before :suite do
    hosts.each do |host|
      copy_module_to(host, source: proj_root, module_name: 'mattermost')
    end
  end
end
