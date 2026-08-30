# == Function: init_template
#
# Loads a template from a predefined location, and returns its contents.
#
# Based on the value of the two mandatory arguments, the template path will be
# determined as follows:
#
# ${module_name}/initscripts/${arg}.${initsystem}.epp
#
# An optional third argument, a hash of parameters, is passed through to the
# EPP template.
#
module Puppet::Parser::Functions
  newfunction(:init_template, :type => :rvalue, :arity => -3) do |args|
    tpl_name, initsystem, params = args
    params ||= {}
    module_name = lookupvar('module_name')
    tpl_arg = "#{module_name}/initscripts/#{tpl_name}.#{initsystem}.epp"
    call_function('epp', tpl_arg, params)
  end
end
