# frozen_string_literal: true

require 'puppet/provider/opensearch_rest'

Puppet::Type.type(:opensearch_pipeline).provide(
  :ruby,
  parent: Puppet::Provider::OpensearchREST,
  metadata: :content,
  api_uri: '_ingest/pipeline'
) do
  desc 'A REST API based provider to manage Opensearch ingest pipelines.'

  mk_resource_methods
end
