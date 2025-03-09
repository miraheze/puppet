require 'rspec-puppet-facts'
include RspecPuppetFacts
add_custom_fact :staging_http_get, 'curl'
add_custom_fact :path, '/opt'

# suppress backtrace
RSpec.configure do |c|
  c.filter_gems_from_backtrace 'puppet', 'rspec-puppet'
end
