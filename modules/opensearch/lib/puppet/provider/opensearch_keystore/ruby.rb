# frozen_string_literal: true

Puppet::Type.type(:opensearch_keystore).provide(
  :opensearch_keystore
) do
  desc 'Provider for `opensearch-keystore` based secret management.'

  def self.defaults_dir
    @defaults_dir ||= case Facter.value('osfamily')
                      when 'RedHat'
                        '/etc/sysconfig'
                      else
                        '/etc/default'
                      end
  end

  def self.home_dir
    @home_dir ||= case Facter.value('osfamily')
                  when 'OpenBSD'
                    '/usr/local/opensearch'
                  else
                    '/usr/share/opensearch'
                  end
  end

  attr_accessor :defaults_dir, :home_dir

  commands keystore: "#{home_dir}/bin/opensearch-keystore"

  def self.run_keystore(args, instance, configdir = '/etc/opensearch', stdin = nil)
    options = {
      custom_environment: {
        'OPENSEARCH_INCLUDE' => File.join(defaults_dir, "opensearch-#{instance}"),
        'OPENSEARCH_PATH_CONF' => "#{configdir}/#{instance}"
      },
      uid: 'opensearch',
      gid: 'opensearch',
      failonfail: true
    }

    unless stdin.nil?
      stdinfile = Tempfile.new('opensearch-keystore')
      stdinfile << stdin
      stdinfile.flush
      options[:stdinfile] = stdinfile.path
    end

    begin
      stdout = execute([command(:keystore)] + args, options)
    ensure
      unless stdin.nil?
        stdinfile.close
        stdinfile.unlink
      end
    end

    stdout.exitstatus.zero? ? stdout : raise(Puppet::Error, stdout)
  end

  def self.present_keystores
    files = Dir[File.join(%w[/ etc opensearch *])].select do |directory|
      File.exist? File.join(directory, 'opensearch.keystore')
    end

    files.map do |instance|
      settings = run_keystore(['list'], File.basename(instance)).split("\n")
      {
        name: File.basename(instance),
        ensure: :present,
        provider: name,
        settings: settings
      }
    end
  end

  def self.instances
    present_keystores.map do |keystore|
      new keystore
    end
  end

  def self.prefetch(resources)
    instances.each do |prov|
      if (resource = resources[prov.name])
        resource.provider = prov
      end
    end
  end

  def initialize(value = {})
    super(value)
    @property_flush = {}
  end

  def flush
    case @property_flush[:ensure]
    when :present
      debug(self.class.run_keystore(['create'], resource[:name], resource[:configdir]))
      @property_flush[:settings] = resource[:settings]
    when :absent
      File.delete(File.join([
                              '/', 'etc', 'opensearch', resource[:instance], 'opensearch.keystore'
                            ]))
    end

    # Note that since the property is :array_matching => :all, we have to
    # expect that the hash is wrapped in an array.
    if @property_flush[:settings] && !@property_flush[:settings].first.empty?
      # Flush properties that _should_ be present
      @property_flush[:settings].first.each_pair do |setting, value|
        next unless @property_hash[:settings].nil? \
          || (!@property_hash[:settings].include? setting)

        debug(self.class.run_keystore(
                ['add', '--force', '--stdin', setting], resource[:name], resource[:configdir], value
              ))
      end

      # Remove properties that are no longer present
      if resource[:purge] && !(@property_hash.nil? || @property_hash[:settings].nil?)
        (@property_hash[:settings] - @property_flush[:settings].first.keys).each do |setting|
          debug(self.class.run_keystore(
                  ['remove', setting], resource[:name], resource[:configdir]
                ))
        end
      end
    end

    @property_hash = self.class.present_keystores.find do |u|
      u[:name] == resource[:name]
    end
  end

  # settings property setter
  #
  # @return [Hash] settings
  def settings=(new_settings)
    @property_flush[:settings] = new_settings
  end

  # settings property getter
  #
  # @return [Hash] settings
  def settings
    @property_hash[:settings]
  end

  # Sets the ensure property in the @property_flush hash.
  #
  # @return [Symbol] :present
  def create
    @property_flush[:ensure] = :present
  end

  # Determine whether this resource is present on the system.
  #
  # @return [Boolean]
  def exists?
    @property_hash[:ensure] == :present
  end

  # Set flushed ensure property to absent.
  #
  # @return [Symbol] :absent
  def destroy
    @property_flush[:ensure] = :absent
  end
end
