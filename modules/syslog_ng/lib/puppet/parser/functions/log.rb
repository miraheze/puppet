require 'stringio'

module Log

    def self.build_reference(key, value, indent, buffer)
        buffer << "#{indent}#{key}(#{value});\n"
    end
    
    def self.build_array(array, indent, buffer)
        array.each do |item|
            if item.is_a? Hash
                build(item, indent, buffer)
            end
        end
    end
    
    def self.build(hash, indent, buffer)
        indent = indent + '    '
        if hash.keys.length != 1
            return 'Error'
        end
    
        key = hash.keys[0]
    
        value = hash[key]
    
        if value.is_a? String
            build_reference(key, value, indent, buffer)
        elsif value.is_a? Array
            buffer << "#{indent}#{key} {\n"
            build_array(value, indent, buffer)
            buffer << "#{indent}};\n" 
        elsif value.is_a? Hash
            buffer <<  "#{indent}Build error\n"
        end
    end
    
    def self.generate_log(options)
        buffer = StringIO.new
        indent = ''
        buffer << "log {\n"
        build_array(options, indent, buffer)
        buffer << "};\n"
        return buffer.string
    end
end
