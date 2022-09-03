# TESTING

## Prerequisites
Before starting any test, you should make sure you have installed the Puppet PDK and Bolt,
also Vagrant and VirtualBox have to be installed for acceptance tests.

Required gems are installed with `bundler`:
```
cd puppet-icinga
pdk bundle install
```

Or just do an update:
```
cd puppet-icinga
pdk bundle update
```

## Validation tests
Validation tests will check all manifests, templates and ruby files against syntax violations and style guides .

Run validation tests:
```
cd puppet-icinga
pdk validate
```

## Unit tests
For unit testing we use [RSpec]. All classes, defined resource types and functions should have appropriate unit tests.

Run unit tests:
``` bash
cd puppet-icinga
pdk test unit
```

Or dedicated tests:
``` bash
pdk test unit --tests=spec/classes/repos_spec.rb,spec/classes/server_spec.rb
```

## Acceptance tests
With acceptance tests this module is tested on multiple platforms to check the complete installation and configuration process.
We define these tests with [Litmus] and run them on VMs by using [Vagrant].

### Run tests
All available acceptance tests are listed in the `spec/acceptance` directory.

Provision the virtual machines:
``` bash
cd puppet-icinga
pdk bundle exec rake litmus:provision_list[vagrant]
```

Install the Agent and the Modul itself:
``` bash
pdk bundle exec rake litmus:install_agent
pdk bundle exec bolt task run provision::fix_secure_path --modulepath spec/fixtures/modules -i inventory.yaml -t ssh_nodes
pdk bundle exec rake litmus:install_module
```

Run the acceptance tests:
``` bash
pdk bundle exec rake litmus:acceptance:parallel
```

Cleanup and remove the virtual machines:
``` bash
pdk bundle exec rake litmus:tear_down
```
