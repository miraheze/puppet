# frozen_string_literal: true

require File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet/provider/opensearch_user_command')

Puppet::Type.type(:opensearch_user).provide(
  :ruby,
  parent: Puppet::Provider::OpensearchUserCommand
) do
  desc 'Provider for Security user resources.'

  has_feature :manages_plaintext_passwords

  mk_resource_methods

  commands users_cli: "#{homedir}/bin/opensearch-users"
  commands os: "#{homedir}/bin/opensearch"
end
