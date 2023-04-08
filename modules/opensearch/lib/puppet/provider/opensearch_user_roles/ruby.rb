# frozen_string_literal: true

require 'puppet/provider/opensearch_user_roles'

Puppet::Type.type(:opensearch_user_roles).provide(
  :ruby,
  parent: Puppet::Provider::OpensearchUserRoles
) do
  desc 'Provider for security user roles (parsed file.)'

  security_config 'users_roles'
end
