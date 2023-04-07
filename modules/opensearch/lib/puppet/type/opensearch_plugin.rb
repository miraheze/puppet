# frozen_string_literal: true

Puppet::Type.newtype(:opensearch_plugin) do
  @doc = 'Plugin installation type'

  ensurable

  newparam(:name, namevar: true) do
    desc 'An arbitrary name used as the identity of the resource.'
  end

  newparam(:configdir) do
    desc 'Path to the opensearch configuration directory (ES_PATH_CONF).'
    defaultto '/etc/opensearch'

    validate do |value|
      raise Puppet::Error, 'path expected' if value.nil?
    end
  end

  newparam(:opensearch_package_name) do
    desc 'Name of the system Opensearch package.'
  end

  newparam(:java_opts) do
    desc 'Optional array of Java options for OPENSEAERCH_JAVA_OPTS.'
    defaultto []
  end

  newparam(:java_home) do
    desc 'Optional string to set the environment variable JAVA_HOME.'
  end

  newparam(:url) do
    desc 'Url of the package'
  end

  newparam(:source) do
    desc 'Source of the package. puppet:// or file:// resource'
  end

  newparam(:proxy) do
    desc 'Proxy Host'
  end

  newparam(:plugin_dir) do
    desc 'Path to the Plugins directory'
    defaultto '/usr/share/opensearch/plugins'
  end

  newparam(:plugin_path) do
    desc 'Override name of the directory created for the plugin'
  end
end
