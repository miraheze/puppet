# frozen_string_literal: true

require 'puppet/provider/opensearch_parsedfile'

Puppet::Type.type(:opensearch_user_file).provide(
  :ruby,
  parent: Puppet::Provider::OpensearchParsedFile
) do
  desc 'Provider for security opensearch users using plain files.'

  security_config 'users'

  has_feature :manages_encrypted_passwords

  text_line :comment,
            match: %r{^\s*#}

  record_line :ruby,
              fields: %w[name hashed_password],
              separator: ':',
              joiner: ':'

  def self.valid_attr?(klass, attr_name)
    if klass.respond_to? :parameters
      klass.parameters.include?(attr_name)
    else
      true
    end
  end
end
