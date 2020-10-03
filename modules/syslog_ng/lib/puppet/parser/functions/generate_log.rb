if RUBY_VERSION >= '1.9.2'
    require_relative 'log'
else
    require File.join(File.expand_path(File.dirname(__FILE__)), './log')
end

module Puppet::Parser::Functions
  newfunction(:generate_log, :type => :rvalue) do |args|
    options = args[0]
   
    Log.generate_log(options) 
   end
end
