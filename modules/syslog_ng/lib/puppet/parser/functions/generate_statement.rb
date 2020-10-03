if RUBY_VERSION >= '1.9.2'
    require_relative 'statement'
else
    require File.join(File.expand_path(File.dirname(__FILE__)), './statement')
end

module Puppet::Parser::Functions
    newfunction(:generate_statement, :type => :rvalue) do |args|
        id = args[0]
        type = args[1]
        params = args[2]

        Statement.generate_statement(id, type, params)
    end
end
