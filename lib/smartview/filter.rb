class SmartView

    # Contains details about a SmartView filter, which is used to filter a
    # list of members in a dimension to a particular subset.
    class Filter

        attr_reader :name, :compose, :decompose, :args


        # Initializes a filter definition from an XML element returned by
        # EnumFilters.
        def initialize(doc)
            @name = doc['name']
            @compose = doc['compose']
            @compose = nil unless @compose.length > 0
            @decompose = doc['decompose']
            @decompose = nil unless @decompose.length > 0
            @decompose = Regexp.new(@decompose) if @decompose
            @args = doc.search('/arg').map{|arg| arg['name']}
        end


        # Returns the name of the filter.
        def to_s
            @name
        end

    end

end
