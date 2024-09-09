Puppet::Type.newtype(:mattermost_settings) do
  file_param_validation = proc do
    validate do |value|
      unless Puppet::Util.absolute_path?(value)
        fail Puppet::Error, "File paths must be fully qualified, not '#{value}'"
      end
    end

    munge do |value|
      File.join(File.split(File.expand_path(value)))
    end
  end

  # parameters

  newparam :name, namevar: true do
    desc <<-'EOT'
      An arbitrary name for the resource. It will be the default for 'target'.
    EOT
  end

  newparam :target do
    isrequired
    desc <<-'EOT'
      The path to the mattermost config file to manage. Either this should file should
      already exist, or the source parameter needs to be specified.
    EOT

    class_eval(&file_param_validation)

    def default
      @resource[:name]
    end
  end

  newparam :source do
    desc <<-'EOT'
      The file from which to load the current settings. If unspecified, it
      defaults to the target file.
    EOT

    class_eval(&file_param_validation)
  end

  # boolean: true generates an allow_new_values? method in the type
  newparam :allow_new_values, boolean: true do
    desc 'Whether it should be allowed to specify values for non-existing tree portions'

    defaultto :true
    newvalues :true, :false
  end

  newparam :allow_new_file, boolean: true do
    desc 'Whether it should be allowed to create a new target file'

    defaultto :true
    newvalues :true, :false
  end

  newparam :user do
    desc 'The user with which to make the changes'
  end

  # the property

  newproperty :values do
    isrequired

    desc <<-'EOT'
      The portions to change and their new values.
      This should be a hash. The subtree to change is specified in the form:
        <key 1>/<key 2>/.../<key n>
      where <key x> admits three variants:
        * the plain contents of the string key, as long as they do not start
          with : or ' and do not contain /
        * '<contents>', to represent a string key that contains the characters
          mentioned above. Single quotes must be doubled to have literal value.
        * :'<contents>', likewise, but the value will be a symbol.
    EOT

    # invalid value, but even with isrequired puppet doesn't require the
    # property to be managed otherwise
    defaultto :absent

    def self.keys_regex
      %r{(?:\A | /)
         (?'key' [^:'][^/]* |
                 :?'(?: [^'] | '')+'
         )
         (?= / | \z)}x
    end

    def self.keys(path)
      # match regex, transform keys
      pos = 0
      res = []
      loop do
        match = path.match(keys_regex, pos)
        fail "could not match on position #{pos} the string: #{path}. Matched so far: #{res}" unless match

        value = match['key']
        if value.start_with?(':\'')
          value = value[2..-2].gsub("''", "'").to_sym
        elsif value.start_with?("'")
          value = value[1..-2].gsub("''", "'")
        end
        res << value
        break if match.end(0) == path.length
        pos = match.end(0)
      end
      res
    end

    def self.convert_value(v)
      return v.values.first.to_sym if
        defined?(Puppet::Pops::Types::PEnumType) && v.instance_of?(Puppet::Pops::Types::PEnumType)

      case v
      when :undef then nil
      when Array then v.map(&method(:convert_value))
      when Hash then Hash[v.map { |k, inner_v| [convert_value(k), convert_value(inner_v)] }]
      else v
      end
    end

    # override so not to call munge/validate on each value array value individually if array
    def should=(values)
      @shouldorig = values

      validate(values)
      @should = [munge(values)]
    end

    validate do |value|
      fail "Expected 'values' property to be a hash, " \
           "got #{value} (class #{value.class})" unless value.instance_of? Hash

      value.keys.each do |key|
        fail "One of the keys of the 'values' hash is not a non-empty string: found: #{key.inspect}" unless
            key.instance_of? String and !key.empty?
      end
    end

    munge do |value|
      res = value.each_with_object({}) do |(k, v), memo|
        key_array = self.class.keys(k)
        memo[key_array] = v
      end

      self.class.convert_value(res)
    end

    def retrieve
      return :absent unless File.file?(@resource[:target])
      provider.current_values
    end

    # rubocop:disable UnusedMethodArgument
    def set(value)
      @resource.refresh
    end
    # rubocop:enable UnusedMethodArgument

    def insync?(is)
      return false unless is.instance_of? Hash # e.g. :absent

      # go over each one
      result = true
      #should = is.merge(should)
      should.each_pair do |key, desired_value|
        cur_value = is.subtree_fetch key
        desired_value = cur_value.merge(desired_value) if cur_value.instance_of? Hash
        unless cur_value == desired_value
          Puppet.notice "Mattermost setting #{key} is out of sync: '#{JSON.pretty_generate(cur_value)}'\nshould be\n'#{JSON.pretty_generate(desired_value)}'"
          result = false
        end
      end

      result
    end
  end

  # end properties / params

  def refresh
    provider.refresh
  end

  def autorequire(rel_catalog = nil)
    reqs = super

    rel_catalog ||= catalog

    if self[:source] and (dep = rel_catalog.resource(:file, self[:source]))
      reqs << Puppet::Relationship.new(dep, self, event: :ALL_EVENTS, callback: :refresh)
    end

    reqs
  end
end
