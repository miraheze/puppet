# frozen_string_literal: true

class OpensearchPackageNotFoundError < StandardError; end

module Puppet_X # rubocop:disable Style/ClassAndModuleCamelCase
  module Opensearch
    # Assists with discerning the locally installed version of Opensearch.
    # Implemented in a way to be called from native types and providers in order
    # to lazily fetch the package version from various arcane Puppet mechanisms.
    class EsVersioning
      # All of the default options we'll set for Opensearch's command
      # invocation.
      DEFAULT_OPTS = {
        'home' => 'OPENSEARCH_HOME',
        'logs' => 'LOG_DIR',
        'data' => 'DATA_DIR',
        'work' => 'WORK_DIR',
        'conf' => 'CONF_DIR'
      }.freeze

      # Create an array of command-line flags to append to an `opensearch`
      # startup command.
      def self.opt_flags(package_name, catalog, opts = DEFAULT_OPTS.dup)
        opt_flag = opt_flag(min_version('1.0.0', package_name, catalog))

        opts.delete 'work' if min_version '1.0.0', package_name, catalog
        opts.delete 'home' if min_version '1.0.0', package_name, catalog

        opt_args = if min_version '1.0.0', package_name, catalog
                     []
                   else
                     opts.map do |k, v|
                       "-#{opt_flag}default.path.#{k}=${#{v}}"
                     end.sort
                   end

        opt_args << '--quiet' if min_version '1.0.0', package_name, catalog

        [opt_flag, opt_args]
      end

      # Get the correct option flag depending on whether Opensearch is post
      # version 1.
      def self.opt_flag(v1_or_later)
        v1_or_later ? 'E' : 'Des.'
      end

      # Predicate to determine whether a package is at least a certain version.
      def self.min_version(ver, package_name, catalog)
        Puppet::Util::Package.versioncmp(
          version(package_name, catalog), ver
        ) >= 0
      end

      # Fetch the package version for a locally installed package.
      def self.version(package_name, catalog)
        os_pkg = catalog.resource("Package[#{package_name}]")
        raise Puppet::Error, "could not find `Package[#{package_name}]` resource" unless os_pkg

        [
          os_pkg.provider.properties[:version],
          os_pkg.provider.properties[:ensure]
        ].each do |property|
          return property if property.is_a? String
        end
        Puppet.warning("could not find valid version for `Package[#{package_name}]` resource")
        raise OpensearchPackageNotFoundError
      end
    end
  end
end
