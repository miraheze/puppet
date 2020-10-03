module Statement

    # source s_name { .. };
    class Stment
        def initialize(type, id, options=[])
            @type = type
            @id = id
            @options = options
        end

        def add_option(option)
            @options << option
        end

        def build
            header = Statement.getln("#{@type} #{@id} {")
            Statement.increase_indent

            built_options = @options.map {|item| item.build}

            Statement.decrease_indent
            tail = Statement.getln("};")
            return header + built_options.join('') + tail
        end
    end

    # flags( .. )
    class Parameter
        def initialize()
            @params = []
        end

        def build
        end
    end

    # like the file name in a file source
    class SimpleParameter < Parameter
        def initialize(value='')
            @value = value
        end

        def value=(value)
            @value = value
        end

        def build
            return Statement.line(@value)
        end
    end

    # like flags in a source
    class TypedParameter < Parameter
        def initialize(type='')
            @type = type
            @values = []
        end

        def type=(type)
            @type = type
        end

        def add_value(value)
            @values << value
        end

        def build
            header = Statement.getln("#{@type}(")
            Statement.increase_indent

            built_values = @values.map {|item| item.build}

            Statement.decrease_indent
            tail = Statement.line(")")

            if @values.length >= 1
                return header + built_values.join(",\n") + "\n" +  tail
            else
                return header + tail
            end
        end
    end

    class TypedParameterValue
        def build
        end
    end

    # flags(no-parse): like no-parse
    class TypedParameterSimpleValue < TypedParameterValue
        def initialize(value=nil)
            @value = value
        end

        def build
            return Statement.line(@value)
        end
    end

    # like tls in tcp source
    class TypedParameterTypedValue < TypedParameterValue
        def initialize(type='')
            @type = type
            @arguments = []
        end

        def type=(type)
            @type = type
        end

        def add_argument(argument)
            @arguments << argument
        end

        def build
            header = Statement.getln("#{@type}(")
            Statement.increase_indent

            built_args = @arguments.map {|item| item.build }

            Statement.decrease_indent
            tail = Statement.line(")")
            return header + built_args.join("") + "\n" + tail
        end
    end

    # like a key_file parameter 
    class Argument
        def initialize(value='')
            @value = value
        end

        def build
            return Statement.line(@value)
        end
    end

    # source s { interna(); system(); };: like internal and system
    class Option
        def initialize(type='')
            @type = type
            @params = []
        end

        def set_type(type)
            @type = type
        end

        def add_parameter(parameter)
            @params << parameter
        end

        def build
            header = Statement.getln("#{@type}(")
            Statement.increase_indent

            built_params = @params.map {|item| item.build}

            Statement.decrease_indent
            tail = Statement.getln(");")
            return header + built_params.join(",\n") + "\n" + tail
        end
    end

    @@indent = ""
    @@indent_step = "    "
    @@current_statement = nil
    @@current_option = nil
    @@current_parameter = nil
    @@current_parameter_value = nil

    def self.increase_indent()
        @@indent += @@indent_step
    end

    def self.decrease_indent()
        @@indent = @@indent[4..-1]
    end

    def self.get_indent()
        return @@indent
    end

    def self.getln(line)
       return @@indent + "#{line}\n"
    end

    def self.line(line)
        return @@indent + "#{line}"
    end

    def self.expand_one_key_hash(hash)
        type = hash.keys[0]
        value = hash[type]
        return type, value
    end

    def self.parse_typed_parameter_typed_value(values)
        type, value = expand_one_key_hash(values)

        # key_file => ...
        @@current_parameter_value.type = type

        if is_simple_type?(value)
            a = Argument.new(value)
            @@current_parameter_value.add_argument(a)
        elsif value.is_a? Array
            value.each do |item|
                # these should be strings or numbers or whatever simple types
                a = Argument.new(item)
                @@current_parameter_value.add_argument(a)
            end
        end
    end

    def self.is_simple_type?(value)
        return [String, Numeric].any? {|item| value.is_a? item}
    end

    def self.parse_typed_parameter(item)
        type, value = expand_one_key_hash(item)

        @@current_parameter.type = type

        ## flags => 'no-parse'
        if is_simple_type?(value) and value != ''
            @@current_parameter_value = TypedParameterSimpleValue.new(value)
            @@current_parameter.add_value(@@current_parameter_value)
        # flags => ['something', 'no-parse']
        elsif value.is_a? Array
            value.each do |item|
                # 'no-parse'
                if is_simple_type?(item)
                    @@current_parameter_value = TypedParameterSimpleValue.new(item)
                    @@current_parameter.add_value(@@current_parameter_value)
                # { ... }
                elsif item.is_a? Hash
                    @@current_parameter_value = TypedParameterTypedValue.new
                    parse_typed_parameter_typed_value(item)
                    @@current_parameter.add_value(@@current_parameter_value)
                end
            end
        end
    end

    def self.create_and_add_parameters(params)
        params.each do |item|
            if is_simple_type?(item)
                @@current_parameter = SimpleParameter.new(item)
            elsif item.is_a? Hash
                @@current_parameter = TypedParameter.new
                parse_typed_parameter(item)
            end

            @@current_option.add_parameter(@@current_parameter)
        end
    end

    def self.parse_option(option)
        if option.has_key?('type')
            type = option['type']
            params = option['options']
            @@current_option.set_type(type)

            create_and_add_parameters(params)
        else
            type, params = expand_one_key_hash(option)
            @@current_option.set_type(type)

            create_and_add_parameters(params)
        end
    end

    def self.create_and_add_option(item)
        @@current_option = Option.new()
        parse_option(item)
        @@current_statement.add_option(@@current_option)
    end

    def self.parse_tree(options)
        if options.is_a? Array
            options.each do |item|
                create_and_add_option(item)
            end
        elsif options.is_a? Hash
            item = options
            create_and_add_option(item)
        else
            raise Puppet::ParseError, "You must use a Hash or an Array as the parameter"
        end
    end

    def self.create_configuration_tree(id, type, options)
        @@indent = ""
        @@current_statement = Stment.new(type, id)
        parse_tree(options)
    end

    def self.render_configuration()
        text_repr = @@current_statement.build
        @@indent = ""
        return text_repr
    end

    def self.generate_statement(id, type, options)
        create_configuration_tree(id, type, options)
        render_configuration()
    end
end

