# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', '..', '..'))
require 'puppet/util/os_instance_validator'

# This file contains a provider for the resource type `es_instance_conn_validator`,
# which validates the Opensearch connection by attempting a tcp connection.

Puppet::Type.type(:os_instance_conn_validator).provide(:tcp_port) do
  desc "A provider for the resource type `os_instance_conn_validator`,
        which validates the  connection by attempting an https
        connection to Opensearch."

  def exists?
    start_time = Time.now
    timeout = resource[:timeout]
    sleep_interval = resource[:sleep_interval]

    success = validator.attempt_connection

    while success == false && ((Time.now - start_time) < timeout)
      # It can take several seconds for the Opensearch to start up;
      # especially on the first install.  Therefore, our first connection attempt
      # may fail.  Here we have somewhat arbitrarily chosen to retry every 10
      # seconds until the configurable timeout has expired.
      Puppet.debug("Failed to connect to Opensearch; sleeping #{sleep_interval} seconds before retry")
      sleep sleep_interval
      success = validator.attempt_connection
    end

    if success
      Puppet.debug("Connected to the Opensearch in #{Time.now - start_time} seconds.")
    else
      Puppet.notice("Failed to connect to the Opensearch within timeout window of #{timeout} seconds; giving up.")
    end

    success
  end

  def create
    # If `#create` is called, that means that `#exists?` returned false, which
    # means that the connection could not be established... so we need to
    # cause a failure here.
    raise Puppet::Error, "Unable to connect to Opensearch! (#{@validator.instance_server}:#{@validator.instance_port})"
  end

  private

  # @api private
  def validator
    @validator ||= Puppet::Util::OsInstanceValidator.new(resource[:server], resource[:port])
  end
end
