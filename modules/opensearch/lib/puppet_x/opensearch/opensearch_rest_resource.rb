# frozen_string_literal: true

require 'puppet/parameter/boolean'

# Provides common properties and parameters for REST-based Opensearch types
module OpensearchRESTResource
  def self.extended(extender)
    extender.newparam(:ca_file) do
      desc 'Absolute path to a CA file to authenticate server certs against.'
    end

    extender.newparam(:ca_path) do
      desc 'Absolute path to a directory containing CA files.'
    end

    extender.newparam(:host) do
      desc 'Hostname or address of Opensearch instance.'
      defaultto 'localhost'

      validate do |value|
        raise Puppet::Error, 'invalid parameter, expected string' unless value.is_a? String
      end
    end

    extender.newparam(:password) do
      desc 'Optional HTTP basic auth plaintext password for Opensearch.'
    end

    extender.newparam(:port) do
      desc 'Port to use for Opensearch HTTP API operations.'
      defaultto 9200

      munge do |value|
        case value
        when String
          value.to_i
        when Integer
          value
        else
          raise Puppet::Error, "unknown '#{value}' timeout type #{value.class}"
        end
      end

      validate do |value|
        raise Puppet::Error, "invalid port value '#{value}'" \
          unless value.to_s =~ %r{^([0-9]+)$}
        raise Puppet::Error, "invalid port value '#{value}'" \
          unless Regexp.last_match[0].to_i.positive? \
            && (Regexp.last_match[0].to_i < 65_535)
      end
    end

    extender.newparam(:protocol) do
      desc 'Protocol to use for communication with Opensearch.'
      defaultto 'http'
    end

    extender.newparam(:timeout) do
      desc 'HTTP timeout for reading/writing content to Opensearch.'
      defaultto 10

      munge do |value|
        case value
        when String
          value.to_i
        when Integer
          value
        else
          raise Puppet::Error, "unknown '#{value}' timeout type #{value.class}"
        end
      end

      validate do |value|
        raise Puppet::Error, 'timeout must be a positive integer' if value.to_s !~ %r{^\d+$}
      end
    end

    extender.newparam(:username) do
      desc 'Optional HTTP basic auth username for Opensearch.'
    end

    extender.newparam(
      :validate_tls,
      boolean: true,
      parent: Puppet::Parameter::Boolean
    ) do
      desc 'Whether to verify TLS/SSL certificates.'
      defaultto true
    end
  end
end
