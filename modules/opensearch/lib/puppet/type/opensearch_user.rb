# frozen_string_literal: true

Puppet::Type.newtype(:opensearch_user) do
  desc 'Type to model Opensearch users.'

  feature :manages_plaintext_passwords,
          'The provider can control the password in plaintext form.'

  ensurable

  newparam(:name, namevar: true) do
    desc 'User name.'
  end

  newparam(:configdir) do
    desc 'Path to the opensearch configuration directory (ES_PATH_CONF).'

    validate do |value|
      raise Puppet::Error, 'path expected' if value.nil?
    end
  end

  newparam(
    :password,
    required_features: :manages_plaintext_passwords
  ) do
    desc 'Plaintext password for user.'

    validate do |value|
      raise ArgumentError, 'Password must be at least 6 characters long' if value.length < 6
    end

    def is_to_s(_currentvalue)
      '[old password hash redacted]'
    end

    def should_to_s(_newvalue)
      '[new password hash redacted]'
    end
  end

  def refresh
    if @parameters[:ensure]
      provider.passwd
    else
      debug 'skipping password set'
    end
  end
end
