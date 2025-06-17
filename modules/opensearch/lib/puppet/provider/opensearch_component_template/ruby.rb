# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', '..', '..'))

require 'puppet/provider/opensearch_rest'

require 'puppet_x/opensearch/deep_to_i'
require 'puppet_x/opensearch/deep_to_s'

Puppet::Type.type(:opensearch_component_template).provide(
  :ruby,
  parent: Puppet::Provider::OpensearchREST,
  api_uri: '_component_template',
  metadata: :content,
  metadata_pipeline: [
    lambda { |data|
      # As api returns values keyed under component_template
      data.merge!(data['component_template']) if data['component_template'].is_a? Hash
      data.delete('component_template')
    },
    ->(data) { Puppet_X::Opensearch.deep_to_s data },
    ->(data) { Puppet_X::Opensearch.deep_to_i data }
  ]
) do
  desc 'A REST API based provider to manage Opensearch component templates.'

  mk_resource_methods

  # We need to override parent since actual data comes as array under component_templates key
  def self.process_body(body)
    JSON.parse(body).fetch('component_templates', []).map do |item|
      {
        :name => item['name'],
        :ensure => :present,
        metadata => process_metadata(item.keep_if { |key| key != 'name' }),
        :provider => name
      }
    end
  end

  def self.prefetch(resources)
    instances.each do |prov|
      resource = resources[prov.name]
      if resource
        resource.provider = prov
      end
    end
  end
end
