# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', '..'))

require 'puppet_x/opensearch/asymmetric_compare'
require 'puppet_x/opensearch/deep_to_i'
require 'puppet_x/opensearch/deep_to_s'
require 'puppet_x/opensearch/opensearch_rest_resource'

Puppet::Type.newtype(:opensearch_index) do
  extend OpensearchRESTResource

  desc 'Manages Opensearch index settings.'

  ensurable

  newparam(:name, namevar: true) do
    desc 'Index name.'
  end

  newproperty(:settings) do
    desc 'Structured settings for the index in hash form.'

    def insync?(value)
      Puppet_X::Opensearch.asymmetric_compare(should, value)
    end

    munge do |value|
      Puppet_X::Opensearch.deep_to_i(Puppet_X::Opensearch.deep_to_s(value))
    end

    validate do |value|
      raise Puppet::Error, 'hash expected' unless value.is_a? Hash
    end
  end
end
