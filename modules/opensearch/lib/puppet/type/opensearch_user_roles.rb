# frozen_string_literal: true

Puppet::Type.newtype(:opensearch_user_roles) do
  desc 'Type to model Opensearch user roles.'

  ensurable

  newparam(:name, namevar: true) do
    desc 'User name.'
  end

  newproperty(:roles, array_matching: :all) do
    desc 'Array of roles that the user should belong to.'
    def insync?(value)
      value.sort == should.sort
    end
  end

  autorequire(:opensearch_user) do
    self[:name]
  end
end
