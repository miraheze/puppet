# frozen_string_literal: true

require 'open-uri'
begin
  require 'net/ftp'
rescue LoadError
  # Ruby 3.0 changed net-ftp to a default gem
end
require 'tempfile'

Puppet::Type.type(:apt_key).provide(:apt_key) do
  desc 'apt-key provider for apt_key resource'

  confine    osfamily: :debian
  defaultfor osfamily: :debian
  commands   apt_key: 'apt-key'
  commands   gpg: '/usr/bin/gpg'

  def self.instances
    cli_args = ['adv', '--no-tty', '--list-keys', '--with-colons', '--fingerprint', '--fixed-list-mode']

    key_output = apt_key(cli_args).encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')

    pub_line, sub_line, fpr_line = nil

    key_array = key_output.split("\n").map do |line|
      if line.start_with?('pub')
        pub_line = line
        # reset fpr_line, to skip any previous subkeys which were collected
        fpr_line = nil
        sub_line = nil
      elsif line.start_with?('sub')
        sub_line = line
      elsif line.start_with?('fpr')
        fpr_line = line
      end

      if sub_line && fpr_line
        sub_line, fpr_line = nil
        next
      end

      next unless pub_line && fpr_line

      line_hash = key_line_hash(pub_line, fpr_line)

      # reset everything
      pub_line, fpr_line = nil

      expired = false

      if line_hash[:key_expiry]
        expired = Time.now >= line_hash[:key_expiry]
      end

      new(
        name: line_hash[:key_fingerprint],
        id: line_hash[:key_long],
        fingerprint: line_hash[:key_fingerprint],
        short: line_hash[:key_short],
        long: line_hash[:key_long],
        ensure: :present,
        expired: expired,
        expiry: line_hash[:key_expiry].nil? ? nil : line_hash[:key_expiry].strftime('%Y-%m-%d'),
        size: line_hash[:key_size],
        type: line_hash[:key_type],
        created: line_hash[:key_created].strftime('%Y-%m-%d'),
      )
    end
    key_array.compact!
  end

  def self.prefetch(resources)
    apt_keys = instances
    resources.each_key do |name|
      if name.length == 40
        provider = apt_keys.find { |key| key.fingerprint == name }
        resources[name].provider = provider if provider
      elsif name.length == 16
        provider = apt_keys.find { |key| key.long == name }
        resources[name].provider = provider if provider
      elsif name.length == 8
        provider = apt_keys.find { |key| key.short == name }
        resources[name].provider = provider if provider
      end
    end
  end

  def self.key_line_hash(pub_line, fpr_line)
    pub_split = pub_line.split(':')
    fpr_split = fpr_line.split(':')

    fingerprint = fpr_split.last
    return_hash = {
      key_fingerprint: fingerprint,
      key_long: fingerprint[-16..-1], # last 16 characters of fingerprint
      key_short: fingerprint[-8..-1], # last 8 characters of fingerprint
      key_size: pub_split[2],
      key_type: nil,
      key_created: Time.at(pub_split[5].to_i),
      key_expiry: pub_split[6].empty? ? nil : Time.at(pub_split[6].to_i),
    }

    # set key type based on types defined in /usr/share/doc/gnupg/DETAILS.gz
    case pub_split[3]
    when '1'
      return_hash[:key_type] = :rsa
    when '17'
      return_hash[:key_type] = :dsa
    when '18'
      return_hash[:key_type] = :ecc
    when '19'
      return_hash[:key_type] = :ecdsa
    end

    return_hash
  end

  def source_to_file(value)
    parsed_value = URI.parse(value)
    if parsed_value.scheme.nil?
      raise(_('The file %{_value} does not exist') % { _value: value }) unless File.exist?(value)
      # Because the tempfile method has to return a live object to prevent GC
      # of the underlying file from occuring too early, we also have to return
      # a file object here.  The caller can still call the #path method on the
      # closed file handle to get the path.
      f = File.open(value, 'r')
      f.close
      f
    else
      exceptions = [OpenURI::HTTPError]
      exceptions << Net::FTPPermError if defined?(Net::FTPPermError)

      begin
        # Only send basic auth if URL contains userinfo
        # Some webservers (e.g. Amazon S3) return code 400 if empty basic auth is sent
        if parsed_value.userinfo.nil?
          key = if parsed_value.scheme == 'https' && resource[:weak_ssl] == true
                  open(parsed_value, ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE).read
                else
                  parsed_value.read
                end
        else
          user_pass = parsed_value.userinfo.split(':')
          parsed_value.userinfo = ''
          key = open(parsed_value, http_basic_authentication: user_pass).read
        end
      rescue *exceptions => e
        raise(_('%{_e} for %{_resource}') % { _e: e.message, _resource: resource[:source] })
      rescue SocketError
        raise(_('could not resolve %{_resource}') % { _resource: resource[:source] })
      else
        tempfile(key)
      end
    end
  end

  # The tempfile method needs to return the tempfile object to the caller, so
  # that it doesn't get deleted by the GC immediately after it returns.  We
  # want the caller to control when it goes out of scope.
  def tempfile(content)
    file = Tempfile.new('apt_key')
    file.write content
    file.close
    # confirm that the fingerprint from the file, matches the long key that is in the manifest
    if name.size == 40
      if File.executable? command(:gpg)
        extracted_key = execute(["#{command(:gpg)} --no-tty --with-fingerprint --with-colons #{file.path} | awk -F: '/^fpr:/ { print $10 }'"], failonfail: false)
        extracted_key = extracted_key.chomp

        found_match = false
        extracted_key.each_line do |line|
          if line.chomp == name
            found_match = true
          end
        end
        unless found_match
          raise(_('The id in your manifest %{_resource} and the fingerprint from content/source don\'t match. Check for an error in the id and content/source is legitimate.') % { _resource: resource[:name] }) # rubocop:disable Layout/LineLength
        end
      else
        warning('/usr/bin/gpg cannot be found for verification of the id.')
      end
    end
    file
  end

  def exists?
    # report expired keys as non-existing when refresh => true
    @property_hash[:ensure] == :present && !(resource[:refresh] && @property_hash[:expired])
  end

  def create
    command = []
    if resource[:source].nil? && resource[:content].nil?
      # Breaking up the command like this is needed because it blows up
      # if --recv-keys isn't the last argument.
      command.push('adv', '--no-tty', '--keyserver', resource[:server])
      unless resource[:options].nil?
        command.push('--keyserver-options', resource[:options])
      end
      command.push('--recv-keys', resource[:id])
    elsif resource[:content]
      key_file = tempfile(resource[:content])
      command.push('add', key_file.path)
    elsif resource[:source]
      key_file = source_to_file(resource[:source])
      command.push('add', key_file.path)
    # In case we really screwed up, better safe than sorry.
    else
      raise(_('an unexpected condition occurred while trying to add the key: %{_resource}') % { _resource: resource[:id] })
    end
    apt_key(command)
    @property_hash[:ensure] = :present
  end

  def destroy
    loop do
      apt_key('del', resource.provider.short)
      r = execute(["#{command(:apt_key)} list | grep '/#{resource.provider.short}\s'"], failonfail: false)
      break unless r.exitstatus.zero?
    end
    @property_hash.clear
  end

  def read_only(_value)
    raise(_('This is a read-only property.'))
  end

  mk_resource_methods

  # Alias the setters of read-only properties
  # to the read_only function.
  alias_method :created=, :read_only
  alias_method :expired=, :read_only
  alias_method :expiry=, :read_only
  alias_method :size=, :read_only
  alias_method :type=, :read_only
end
