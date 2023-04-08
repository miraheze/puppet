# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', '..', '..'))

require 'puppet/provider/opensearch_rest'

require 'puppet_x/opensearch/deep_to_i'
require 'puppet_x/opensearch/deep_to_s'

Puppet::Type.type(:opensearch_template).provide(
  :ruby,
  parent: Puppet::Provider::OpensearchREST,
  api_uri: '_template',
  metadata: :content,
  metadata_pipeline: [
    ->(data) { Puppet_X::Opensearch.deep_to_s data },
    ->(data) { Puppet_X::Opensearch.deep_to_i data }
  ]
) do
  desc 'A REST API based provider to manage Opensearch templates.'

  mk_resource_methods
end
