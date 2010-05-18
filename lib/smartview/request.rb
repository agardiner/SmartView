class SmartView

    class Request
        attr_reader :method

        def initialize
            @xml = Builder::XmlMarkup.new(:indent => 2, :target => self)
        end

        def <<(val)
            @buffer << val
        end

        def new_request
            @buffer = ""
            @xml.instruct!
        end

        def to_s
            @buffer
        end

        def method_missing(method, *args, &block)
            new_request
            @method = method
            @xml.__send__(('req_' + method.to_s).intern, *args, &block)
        end
    end

end
