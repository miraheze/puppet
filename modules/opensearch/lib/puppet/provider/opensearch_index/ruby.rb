# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', '..', '..'))

require 'puppet/provider/opensearch_rest'

require 'puppet_x/opensearch/deep_to_i'
require 'puppet_x/opensearch/deep_to_s'

Puppet::Type.type(:opensearch_index).provide(
  :ruby,
  parent: Puppet::Provider::OpensearchREST,
  metadata: :settings,
  metadata_pipeline: [
    ->(data) { data['settings'] },
    ->(data) { Puppet_X::Opensearch.deep_to_s data },
    ->(data) { Puppet_X::Opensearch.deep_to_i data }
  ],
  api_uri: '_settings',
  api_discovery_uri: '_all',
  api_resource_style: :prefix,
  discrete_resource_creation: true
) do
  desc 'A REST API based provider to manage Opensearch index settings.'

  mk_resource_methods
end
