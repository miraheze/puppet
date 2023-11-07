# frozen_string_literal: true

require 'puppet/provider/opensearch_yaml'

Puppet::Type.type(:opensearch_role_mapping).provide(
  :ruby,
  parent: Puppet::Provider::OpensearchYaml,
  metadata: :mappings
) do
  desc 'Provider for security role mappings.'

  security_config 'role_mapping.yml'
end
