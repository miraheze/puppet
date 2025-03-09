require 'json'

Puppet::Type.type(:mattermost_settings).provide(:mattermost_settings_provider) do
  module HashSubtreeTraverse
    include Puppet::Util::Errors

    UNREACHABLE = Class.new do
      def to_s
        '<unreachable value>'
      end
    end.new

    def subtree_fetch(spec)
      spec.inject(self) do |accum, cur_index|
        return UNREACHABLE unless accum.instance_of? Hash
        accum[cur_index]
      end
    end

    def subtree_assign(spec, value, allow_new = true)
      target = self
      spec[0..-2].each do |cur_index|
        raise "Cannot go into element #{cur_index} of #{target.inspect}, not hash" unless target.instance_of? Hash

        if target.key? cur_index
          target = target[cur_index]
        else
          target = (target[cur_index] = {})
          next
        end
      end

      final_index = spec.last
      fail "Cannot assign element #{final_index} of #{target}; " \
           "not a hash (got #{target.inspect})" unless target.instance_of? Hash
      fail "Not allowing new values, so rejecting setting '#{spec}' to #{value}" unless
          target.key?(final_index) or allow_new
      value = target[final_index].merge(value) if target[final_index].instance_of? Hash
      target[final_index] = value
    end
  end

  def refresh
    # a little validation
    fail "Template/source file not found: #{resource[:source]}" if
        resource[:source] and !File.exist? resource[:source]
    fail "allow_new_file is false and #{resource[:target]} does not exist" unless
        resource.allow_new_file? or File.exist? resource[:target]

    values = template_values
    should = resource[:values]
    should.each_pair do |key, desired_value|
      values.subtree_assign key, desired_value, resource.allow_new_values?
    end

    write(resource[:target], values)
  end

  def current_values
    return @current_values unless @current_values.nil?
    return :absent unless File.file? resource[:target]

    @current_values = load(resource[:target])
                      .instance_eval { extend HashSubtreeTraverse }
  end

  private

  def starting_point_file
    resource[:source] || resource[:target]
  end

  def template_values
    val =
      if File.exist? starting_point_file
        load starting_point_file
      else
        {}
      end

    val.instance_eval { extend HashSubtreeTraverse }
  end

  def load(file_path)
    with_chosen_user do
      res = JSON.parse(File.read(file_path))
      case res
      when false then {}
      when Hash then res
      else fail("File #{file_path} is not a JSON Hash. Content: #{res}")
      end
    end
  end

  def write(file_path, contents)
    with_chosen_user do
      IO.write file_path, JSON.pretty_generate(contents)
    end
  end

  def with_chosen_user
    user = resource[:user]
    return yield if @changed_user or user.nil?

    begin
      @changed_user = true
      Puppet::Util::SUIDManager.asuser(user) { yield }
    ensure
      @changed_user = false
    end
  end
end
