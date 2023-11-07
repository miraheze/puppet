# frozen_string_literal: true

require 'puppet/provider/parsedfile'

# Parent class for Opensearch-based providers that need to access
# specific configuration directories.
class Puppet::Provider::OpensearchParsedFile < Puppet::Provider::ParsedFile
  # Find/set an x-pack configuration file.
  #
  # @return String
  def self.security_config(val)
    self.default_target ||= "/etc/opensearch/#{val}"
  end
end
