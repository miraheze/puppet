module Puppet::Parser::Functions
  newfunction(:require_sslcert, :arity => -2) do |args|
    Puppet::Parser::Functions.function :create_resources
    args.flatten.each do |ssl_cert|
      # Create host class
      host = compiler.topscope.find_hostclass(class_name)
      unless host
        host = Puppet::Resource::Type.new(:hostclass, class_name)
        compiler.environment.known_resource_types.add_hostclass(host)
      end

      # Create class scope
      cls = Puppet::Parser::Resource.new(
          'class', class_name, :scope => compiler.topscope)
      begin
        catalog.add_resource(cls)
      rescue
        nil
      end
      begin
        host.evaluate_code(cls)
      rescue
        nil
      end

      # Create ssl::cert resource
      begin
        host_scope = compiler.topscope.class_scope(host)
        host_scope.call_function(:create_resources,
                                 ['Ssl::Cert', ssl_cert])
      rescue Puppet::Resource::Catalog::DuplicateResourceError
        nil
      end

      # Declare dependency
      call_function :require, [class_name]
    end
  end
end
