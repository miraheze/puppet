# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', '..'))

require 'puppet_x/opensearch/deep_to_i'
require 'puppet_x/opensearch/deep_to_s'
require 'puppet_x/opensearch/opensearch_rest_resource'

Puppet::Type.newtype(:opensearch_pipeline) do
  extend OpensearchRESTResource

  desc 'Manages Opensearch ingest pipelines.'

  ensurable

  newparam(:name, namevar: true) do
    desc 'Pipeline name.'
  end

  newproperty(:content) do
    desc 'Structured content of pipeline.'

    validate do |value|
      raise Puppet::Error, 'hash expected' unless value.is_a? Hash
    end

    munge do |value|
      Puppet_X::Opensearch.deep_to_i(Puppet_X::Opensearch.deep_to_s(value))
    end
  end
end
