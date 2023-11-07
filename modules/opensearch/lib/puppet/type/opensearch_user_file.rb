# frozen_string_literal: true

Puppet::Type.newtype(:opensearch_user_file) do
  desc 'Type to model Opensearch users.'

  feature :manages_encrypted_passwords,
          'The provider can control the password hash without a need
          to explicitly refresh.'

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

  newproperty(
    :hashed_password,
    required_features: :manages_encrypted_passwords
  ) do
    desc 'Hashed password for user.'

    newvalues(%r{^[$]2a[$].{56}$})
  end
end
