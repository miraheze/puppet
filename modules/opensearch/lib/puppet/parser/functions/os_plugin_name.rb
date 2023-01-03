# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', '..', '..'))

require 'puppet_x/opensearch/plugin_parsing'

# Top-level Puppet functions
module Puppet::Parser::Functions
  newfunction(
    :os_plugin_name,
    type: :rvalue,
    doc: <<-'ENDHEREDOC') do |args|
    Given a string, return the best guess at what the directory name
    will be for the given plugin. Any arguments past the first will
    be fallbacks (using the same logic) should the first fail.

    For example, all the following return values are "plug":

        os_plugin_name('plug')
        os_plugin_name('foo/plug')
        os_plugin_name('foo/plug/1.0.0')
        os_plugin_name('foo/opensearch-plug')
        os_plugin_name('foo/os-plug/1.3.2')

    @return String
    ENDHEREDOC

    if args.empty?
      raise Puppet::ParseError,
            'wrong number of arguments, at least one value required'
    end

    ret = args.select do |arg|
      arg.is_a?(String) && !arg.empty?
    end.first

    if ret
      Puppet_X::Opensearch.plugin_name ret
    else
      raise Puppet::Error,
            'could not determine plugin name'
    end
  end
end
