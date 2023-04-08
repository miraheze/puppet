# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', '..'))

require 'uri'
require 'puppet_x/opensearch/os_versioning'
require 'puppet_x/opensearch/plugin_parsing'

# Generalized parent class for providers that behave like Opensearch's plugin
# command line tool.
class Puppet::Provider::OpensearchPlugin < Puppet::Provider
  # Opensearch's home directory.
  #
  # @return String
  def homedir
    case Facter.value('osfamily')
    when 'OpenBSD'
      '/usr/local/opensearch'
    else
      '/usr/share/opensearch'
    end
  end

  def exists?
    properties_files = Dir[File.join(@resource[:plugin_dir], plugin_path, '**', '*plugin-descriptor.properties')]
    return false if properties_files.empty?

    begin
      # Use the basic name format that the plugin tool supports in order to
      # determine the version from the resource name.
      plugin_version = Puppet_X::Opensearch.plugin_version(@resource[:name])

      # Naively parse the Java .properties file to check version equality.
      # Because we don't have the luxury of installing arbitrary gems, perform
      # simple parse with a degree of safety checking in the call chain
      #
      # Note that x-pack installs "meta" plugins which bundle multiple plugins
      # in one. Therefore, we need to find the first "sub" plugin that
      # indicates which version of x-pack this is.
      properties = properties_files.sort.map do |prop_file|
        lines = File.readlines(prop_file).map(&:strip).reject do |line|
          line.start_with?('#') || line.empty?
        end
        lines = lines.map do |property|
          property.split('=')
        end
        lines = lines.select do |pairs|
          pairs.length == 2
        end
        lines.to_h
      end
      properties = properties.find { |prop| prop.key? 'version' }

      if properties && properties['version'] != plugin_version
        debug "Opensearch plugin #{@resource[:name]} not version #{plugin_version}, reinstalling"
        destroy
        return false
      end
    rescue OpensearchPluginParseFailure
      debug "Failed to parse plugin version for #{@resource[:name]}"
    end

    # If there is no version string, we do not check version equality
    debug "No version found in #{@resource[:name]}, not enforcing any version"
    true
  end

  def plugin_path
    @resource[:plugin_path] || Puppet_X::Opensearch.plugin_name(@resource[:name])
  end

  # Intelligently returns the correct installation arguments for Opensearch.
  #
  # @return [Array<String>]
  #   arguments to pass to the plugin installation utility
  def install_args
    if !@resource[:url].nil?
      [@resource[:url]]
    elsif !@resource[:source].nil?
      ["file://#{@resource[:source]}"]
    else
      [@resource[:name]]
    end
  end

  # Format proxy arguments for consumption by the opensearch plugin
  # management tool (i.e., Java properties).
  #
  # @return Array
  #   of flags for command-line tools
  def proxy_args(url)
    parsed = URI(url)
    %w[http https].map do |schema|
      %i[host port user password].map do |param|
        option = parsed.send(param)
        "-D#{schema}.proxy#{param.to_s.capitalize}=#{option}" unless option.nil?
      end
    end.flatten.compact
  end

  # Install this plugin on the host.
  def create
    commands = []
    commands += proxy_args(@resource[:proxy]) if @resource[:proxy]
    commands << 'install'
    commands << '--batch'
    commands += install_args
    debug("Commands: #{commands.inspect}")

    retry_count = 3
    retry_times = 0
    begin
      with_environment do
        plugin(commands)
      end
    rescue Puppet::ExecutionFailure => e
      retry_times += 1
      debug("Failed to install plugin. Retrying... #{retry_times} of #{retry_count}")
      sleep 2
      retry if retry_times < retry_count
      raise "Failed to install plugin. Received error: #{e.inspect}"
    end
  end

  # Remove this plugin from the host.
  def destroy
    with_environment do
      plugin(['remove', Puppet_X::Opensearch.plugin_name(@resource[:name])])
    end
  end

  # Run a command wrapped in necessary env vars
  def with_environment(&block)
    env_vars = {
      'OPENSEARCH_JAVA_OPTS' => @resource[:java_opts],
      'OPENSEARCH_PATH_CONF' => @resource[:configdir]
    }
    saved_vars = {}

    # Use 'java_home' param if supplied, otherwise default to Opensearch shipped JDK
    env_vars['JAVA_HOME'] = if @resource[:java_home].nil? || @resource[:java_home] == ''
                              "#{homedir}/jdk"
                            else
                              @resource[:java_home]
                            end

    env_vars['OPENSEARCH_JAVA_OPTS'] = env_vars['OPENSEARCH_JAVA_OPTS'].join(' ')

    env_vars.each do |env_var, value|
      saved_vars[env_var] = ENV[env_var]
      ENV[env_var] = value
    end

    ret = block.yield

    saved_vars.each do |env_var, value|
      ENV[env_var] = value
    end

    ret
  end
end
