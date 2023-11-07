# frozen_string_literal: true

require 'puppet/provider/opensearch_yaml'

Puppet::Type.type(:opensearch_role).provide(
  :ruby,
  parent: Puppet::Provider::OpensearchYaml,
  metadata: :privileges
) do
  desc 'Provider for security role resources.'

  security_config 'roles.yml'
end
