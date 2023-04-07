# frozen_string_literal: true

class OpensearchPluginParseFailure < StandardError; end

module Puppet_X # rubocop:disable Style/ClassAndModuleCamelCase
  # Custom functions for plugin string parsing.
  module Opensearch
    def self.plugin_name(raw_name)
      plugin_split(raw_name, 1)
    end

    def self.plugin_version(raw_name)
      v = plugin_split(raw_name, 2, false).gsub(%r{^[^0-9]*}, '')
      raise OpensearchPluginParseFailure, "could not parse version, got '#{v}'" if v.empty?

      v
    end

    # Attempt to guess at the plugin's final directory name
    def self.plugin_split(original_string, position, soft_fail = true)
      # Try both colon (maven) and slash-delimited (github/opensearch.co) names
      %w[/ :].each do |delimiter|
        parts = original_string.split(delimiter)
        # If the string successfully split, assume we found the right format
        return parts[position].gsub(%r{(opensearch-|os-)}, '') unless parts[position].nil?
      end

      unless soft_fail
        raise(
          OpensearchPluginParseFailure,
          "could not find element '#{position}' in #{original_string}"
        )
      end

      original_string
    end
  end
end
