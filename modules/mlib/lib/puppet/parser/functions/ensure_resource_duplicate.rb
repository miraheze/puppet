# == Function: ensure_resource_duplicate( .... )
#
# This ensures that if there are duplicate resources in the catalog
# that we will fail gracefully, ie, not causing errors in the catalog.
#
# === Examples
#
#  ensure_resource_duplicate('user', 'dan', {'ensure' => 'present' })
#

require 'puppet/parser/functions'

Puppet::Parser::Functions.newfunction(:ensure_resource_duplicate,
                                      :type => :statement,
                                      :doc => <<-'DOC'
    Takes a resource type, title, and a list of attributes that describe a
    resource.

        user { 'dan':
          ensure => present,
        }

    This example only creates the resource if it does not already exist:

        ensure_resource_duplicate('user', 'dan', {'ensure' => 'present' })

    If the resource already exists but does not match the specified parameters,
    this function will attempt to recreate the resource leading to a duplicate
    resource definition error.

    An array of resources can also be passed in and each will be created with
    the type and parameters specified if it doesn't already exist.

        ensure_resource_duplicate('user', ['dan','alex'], {'ensure' => 'present'})

DOC
                                     ) do |vals|
  type, title, params = vals
  raise(ArgumentError, 'Must specify a type') unless type
  raise(ArgumentError, 'Must specify a title') unless title
  params ||= {}

  items = [title].flatten

  items.each do |item|
    Puppet::Parser::Functions.function(:defined_with_params)
    if function_defined_with_params(["#{type}[#{item}]", params])
      Puppet.debug("Resource #{type}[#{item}] with params #{params} not created because it already exists")
    else
      Puppet.debug("Create new resource #{type}[#{item}] with params #{params}")
      begin
        Puppet::Parser::Functions.function(:create_resources)
        function_create_resources([type.capitalize, { item => params }])
      rescue Puppet::Resource::Catalog::DuplicateResourceError
        nil
      end
    end
  end
end
