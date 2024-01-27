# frozen_string_literal: true

require 'json'
require 'net/http'
require 'openssl'

# Parent class encapsulating general-use functions for children REST-based
# providers.
class Puppet::Provider::OpensearchREST < Puppet::Provider
  class << self
    attr_accessor :api_discovery_uri, :api_resource_style, :api_uri, :discrete_resource_creation, :metadata, :metadata_pipeline, :query_string
  end

  # Fetch arbitrary metadata for the class from an instance object.
  #
  # @return String
  def metadata
    self.class.metadata
  end

  # Retrieve the class query_string variable
  #
  # @return String
  def query_string
    self.class.query_string
  end

  # Perform a REST API request against the indicated endpoint.
  #
  # @return Net::HTTPResponse
  def self.rest(http,
                req,
                timeout = 10,
                username = nil,
                password = nil,
                validate_tls: true)

    if username && password
      req.basic_auth username, password
    elsif username || password
      Puppet.warning(
        'username and password must both be defined, skipping basic auth'
      )
    end

    req['Accept'] = 'application/json'

    http.read_timeout = timeout
    http.open_timeout = timeout
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE unless validate_tls

    begin
      http.request req
    rescue EOFError => e
      # Because the provider attempts a best guess at API access, we
      # only fail when HTTP operations fail for mutating methods.
      unless %w[GET OPTIONS HEAD].include? req.method
        raise Puppet::Error,
              "Received '#{e}' from the Opensearch API. Are your API settings correct?"
      end
    end
  end

  # Helper to format a remote URL request for Opensearch which takes into
  # account path ordering, et cetera.
  def self.format_uri(resource_path, property_flush = {})
    return api_uri if resource_path.nil? || api_resource_style == :bare

    if discrete_resource_creation && !property_flush[:ensure].nil?
      resource_path
    else
      case api_resource_style
      when :prefix
        "#{resource_path}/#{api_uri}"
      else
        "#{api_uri}/#{resource_path}"
      end
    end
  end

  # Fetch Opensearch API objects. Accepts a variety of argument functions
  # dictating how to connect to the Opensearch API.
  #
  # @return Array
  #   an array of Hashes representing the found API objects, whether they be
  #   templates, pipelines, et cetera.
  def self.api_objects(protocol = 'http',
                       host = 'os151-private.wikitide.net',
                       port = 9200,
                       timeout = 10,
                       username = nil,
                       password = nil,
                       ca_file = nil,
                       ca_path = nil,
                       validate_tls: true)

    uri = URI("#{protocol}://#{host}:#{port}/#{format_uri(api_discovery_uri)}")
    http = Net::HTTP.new uri.host, uri.port
    req = Net::HTTP::Get.new uri.request_uri

    http.use_ssl = uri.scheme == 'https'
    [[ca_file, :ca_file=], [ca_path, :ca_path=]].each do |arg, method|
      http.send method, arg if arg && http.respond_to?(method)
    end

    response = rest http, req, timeout, username, password, validate_tls: validate_tls

    results = []

    results = process_body(response.body) if response.respond_to?(:code) && response.code.to_i == 200

    results
  end

  # Process the JSON response body
  def self.process_body(body)
    JSON.parse(body).map do |object_name, api_object|
      {
        :name => object_name,
        :ensure => :present,
        metadata => process_metadata(api_object),
        :provider => name
      }
    end
  end

  # Passes API objects through arbitrary Procs/lambdas in order to postprocess
  # API responses.
  def self.process_metadata(raw_metadata)
    if metadata_pipeline.is_a?(Array) && !metadata_pipeline.empty?
      metadata_pipeline.reduce(raw_metadata) do |md, processor|
        processor.call md
      end
    else
      raw_metadata
    end
  end

  # Fetch an array of provider objects from the Opensearch API.
  def self.instances
    api_objects.map { |resource| new resource }
  end

  # Unlike a typical #prefetch, which just ties discovered #instances to the
  # correct resources, we need to quantify all the ways the resources in the
  # catalog know about Opensearch API access and use those settings to
  # fetch any templates we can before associating resources and providers.
  def self.prefetch(resources)
    # Get all relevant API access methods from the resources we know about
    res = resources.map do |_, resource|
      p = resource.parameters
      [
        p[:protocol].value,
        p[:host].value,
        p[:port].value,
        p[:timeout].value,
        (p.key?(:username) ? p[:username].value : nil),
        (p.key?(:password) ? p[:password].value : nil),
        (p.key?(:ca_file) ? p[:ca_file].value : nil),
        (p.key?(:ca_path) ? p[:ca_path].value : nil),
        { validate_tls: p[:validate_tls].value },
      ]
      # Deduplicate identical settings, and fetch templates
    end.uniq
    res = res.map do |api|
      api_objects(*api)
      # Flatten and deduplicate the array, instantiate providers, and do the
      # typical association dance
    end
    res.flatten.uniq.map { |resource| new resource }.each do |prov|
      if (resource = resources[prov.name])
        resource.provider = prov
      end
    end
  end

  def initialize(value = {})
    super(value)
    @property_flush = {}
  end

  # Generate a request body
  def generate_body
    JSON.generate(
      if metadata != :content && @property_flush[:ensure] == :present
        { metadata.to_s => resource[metadata] }
      else
        resource[metadata]
      end
    )
  end

  # Call Opensearch's REST API to appropriately PUT/DELETE/or otherwise
  # update any managed API objects.
  def flush
    Puppet.debug('Got to flush')
    uri = URI(
      format(
        '%s://%s:%d/%s',
        resource[:protocol],
        resource[:host],
        resource[:port],
        self.class.format_uri(resource[:name], @property_flush)
      )
    )
    uri.query = URI.encode_www_form query_string if query_string

    Puppet.debug("Generated URI = #{uri.inspect}")

    case @property_flush[:ensure]
    when :absent
      req = Net::HTTP::Delete.new uri.request_uri
    else
      req = Net::HTTP::Put.new uri.request_uri
      req.body = generate_body
      Puppet.debug("Generated body looks like: #{req.body.inspect}")
      req['Content-Type'] = 'application/json' if req['Content-Type'].nil?
    end

    http = Net::HTTP.new uri.host, uri.port
    http.use_ssl = uri.scheme == 'https'
    %i[ca_file ca_path].each do |arg|
      http.send "#{arg}=".to_sym, resource[arg] if !resource[arg].nil? && http.respond_to?(arg)
    end

    response = self.class.rest(
      http,
      req,
      resource[:timeout],
      resource[:username],
      resource[:password],
      validate_tls: resource[:validate_tls]
    )

    # Attempt to return useful error output
    unless response.code.to_i == 200
      Puppet.debug("Non-OK reponse: Body = #{response.body.inspect}")
      json = JSON.parse(response.body)

      err_msg = if json.key? 'error'
                  if json['error'].is_a?(Hash) \
                      && json['error'].key?('root_cause')
                    # Newer versions have useful output
                    json['error']['root_cause'].first['reason']
                  else
                    # Otherwise fallback to old-style error messages
                    json['error']
                  end
                else
                  # As a last resort, return the response error code
                  "HTTP #{response.code}"
                end

      raise Puppet::Error, "Opensearch API responded with: #{err_msg}"
    end
    @property_hash = self.class.api_objects(
      resource[:protocol],
      resource[:host],
      resource[:port],
      resource[:timeout],
      resource[:username],
      resource[:password],
      resource[:ca_file],
      resource[:ca_path],
      validate_tls: resource[:validate_tls]
    ).find do |t|
      t[:name] == resource[:name]
    end
  end

  # Set this provider's `:ensure` property to `:present`.
  def create
    @property_flush[:ensure] = :present
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  # Set this provider's `:ensure` property to `:absent`.
  def destroy
    @property_flush[:ensure] = :absent
  end
end
