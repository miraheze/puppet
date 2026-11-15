# == Function: systemd_template
#
# Loads a template from a predefined location, and returns its contents.
#
# Based on the value of the only mandatory argument, the template path will be
# determined as follows:
#
# ${module_name}/initscripts/${arg}.systemd.epp
#
# An optional second argument, a hash of parameters, is passed through to the
# EPP template.
#
module Puppet::Parser::Functions
  newfunction(:systemd_template, :type => :rvalue, :arity => -2) do |args|
    tpl_name, params = args
    function_init_template([tpl_name, 'systemd', params])
  end
end
