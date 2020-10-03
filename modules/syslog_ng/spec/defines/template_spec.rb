if RUBY_VERSION >= '1.9.2'
    require_relative 'statement'
else
    require File.join(File.expand_path(File.dirname(__FILE__)), './statement')
end

describe "syslog_ng::template" do
    it_behaves_like "Statement", 'id', 'template'
end
