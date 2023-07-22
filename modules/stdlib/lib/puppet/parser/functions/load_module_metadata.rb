# frozen_string_literal: true

#
# load_module_metadata.rb
#
module Puppet::Parser::Functions
  newfunction(:load_module_metadata, type: :rvalue, doc: <<-DOC
    @summary
      This function loads the metadata of a given module.

    @example Example Usage:
      $metadata = load_module_metadata('archive')
      notify { $metadata['author']: }

    @return
      The modules metadata
  DOC
  ) do |args|
    raise(Puppet::ParseError, 'load_module_metadata(): Wrong number of arguments, expects one or two') unless [1, 2].include?(args.size)

    mod = args[0]
    allow_empty_metadata = args[1]
    module_path = function_get_module_path([mod])
    metadata_json = File.join(module_path, 'metadata.json')

    metadata_exists = File.exist?(metadata_json)
    if metadata_exists
      metadata = if Puppet::Util::Package.versioncmp(Puppet.version, '8.0.0').negative?
                   PSON.load(File.read(metadata_json))
                 else
                   JSON.parse(File.read(metadata_json))
                 end
    else
      metadata = {}
      raise(Puppet::ParseError, "load_module_metadata(): No metadata.json file for module #{mod}") unless allow_empty_metadata
    end

    return metadata
  end
end
