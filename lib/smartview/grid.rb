class SmartView

    class InvalidGridSpecification < RuntimeError; end

    # Represents a grid of data, either for a request or as returned by a
    # SmartView provider.
    # To create a gird for a request, use the Grid.define method.
    class Grid

        include Enumerable

        # Cell-type constants
        GRID_TYPE_UPPER_LEFT = '7'
        GRID_TYPE_MEMBER = '0'
        GRID_TYPE_DATA = '2'
        GRID_TYPE_TEXT = '3'


        # Utility method for building up a set of tuples by cross-joining sets of
        # members for each dimension. A cross-join creates a tuple that is a
        # combination of every member of one set with every member of another.
        # This method handles any number of sets, each of which may be a single
        # member (String), or an array of members. However, if any argument is nil,
        # the result is nil.
        def self.cross_join(*args)
            result = nil
            return result unless args
            args.each do |arg|
                return nil if arg.nil?
                arg = [arg] unless arg.is_a? Array
                if result
                    new_result = []
                    result.each do |tuple|
                        arg.each do |next_val|
                            new_result << (tuple.is_a?(Array) ? tuple : [tuple]) + [next_val]
                        end
                    end
                    result = new_result
                else
                    # First dimension added to result
                    result = arg.map{|el| [el]}
                end
            end
            result
        end


        # Creates a grid definition from row and column tuple definitions.
        # The row and column tuple definitions are in the form of a hash. Either
        # a single hash with two entries (one for rows and one for columns), or
        # two hashes each with one entry may be specified as the argument(s) to
        # this method.
        #
        # Within each hash:
        #   * the key may be either:
        #     * a single dimension name where a single dimension exists on the
        #       axis
        #     * an array of dimension names, where multiple dimensions exist on
        #       the axis. The dimensions will be placed with the first dimension
        #       as the outermost dimension on the axis.
        #   * the value must be either:
        #     * a single member or array of members (single dimension on axis)
        #     * an array of arrays, where each inner array represents a tuple
        #       of members (one member for each dimension on that axis).
        def self.define(dimensions, pov, rows, cols=nil)
            if !rows.is_a? Hash
                raise InvalidGridSpecification, "Row and column specifications must be in the form of a hash"
            end

            if cols.nil?
                if rows.size == 2
                    cols = rows[rows.keys[1]]
                    rows = rows[rows.keys[0]]
                else
                    raise InvalidGridSpecification, "No column specification was provided"
                end
            end

            # Extract dimension names and members for rows and cols
            row_dims, row_tuples = process_axis_spec(rows, "Row")
            col_dims, col_tuples = process_axis_spec(cols, "Column")

            # Convert axis specifications into a grid
            row_count = col_dims.size + row_tuples.size
            col_count = row_dims.size + col_tuples.size
            vals, types = [], []

            # Convert column header rows
            0.upto(col_dims.size-1) do |row_num|
                0.upto(row_dims.size-1) do |col_num|
                    vals << ''
                    types << GRID_TYPE_UPPER_LEFT
                end
                col_tuples.each do |col_tuple|
                    vals << col_tuple[row_num]
                    types << GRID_TYPE_MEMBER
                end
            end

            # Convert row header rows
            row_tuples.each do |row_tuple|
                row_tuple.each do |mbr|
                    vals << mbr
                    types << GRID_TYPE_MEMBER
                end
                0.upto(col_tuples.size-1) do
                    vals << ''
                    types << GRID_TYPE_DATA
                end
            end

            Grid.new(dimensions, pov, row_dims, col_dims, row_count, col_count, vals, types)
        end


        # Creates a Grid object from an XML document returned from a SmartView provider
        def self.from_xml(doc)
            dimensions = [], pov = {}, row_dims = [], col_dims = []
            doc.search('*/grid/dims/dim').each do |dim|
                dimensions[dim['id'].to_i] = dim['name']
                if dim['pov']
                    pov[dim['name']] = dim['pov']
                elsif dim['row']
                    row_dims[dim['row'].to_i] = dim['name']
                elsif dim['col']
                    col_dims[dim['col'].to_i] = dim['name']
                end
            end

            slice = doc.at('*/slice')
            row_count = slice['rows'].to_i
            col_count = slice['cols'].to_i
            vals = slice.at('/data/range/vals').to_plain_text.split('|', -1)
            types = slice.at('data/range/types').to_plain_text.split('|', -1)

            Grid.new(dimensions, pov, row_dims, col_dims, row_count, col_count, vals, types)
        end


        attr_reader :row_count, :col_count, :row_dims, :col_dims, :pov


        # Creates a new Grid object
        def initialize(dimensions, pov, row_dims, col_dims, row_count, col_count, vals, types)
            @dimensions = dimensions
            @pov = pov
            @row_dims = row_dims
            @col_dims = col_dims
            @row_count = row_count
            @col_count = col_count
            @vals = vals
            @types = types
        end


        # Retrieve a cell value at the specified row and column intersection.
        def [](row, col)
            val = @vals[row * @col_count + col]
            val && val.length > 0 && cell_type(row, col) == GRID_TYPE_DATA ? val.to_f : val
        end


        # Returns a Fixnum identifying the type of the value at the specified
        # row and column intersection. The return value will be one of the
        # GRID_TYPE_* constants.
        def cell_type(row, col)
            @types[row * @col_count + col]
        end


        # Returns the number of rows needed for the column headers.
        def header_rows
            @col_dims.count
        end


        # Returns the number of columns needed for the row headers.
        def header_cols
            @row_dims.count
        end


        # Iterates over each row of the grid, returning an array of values (one
        # per column)
        def each
            0.upto(@row_count-1) do |row|
                fields = []
                0.upto(@col_count-1) do |col|
                    fields << self[row, col]
                end
                yield fields
            end
        end


        # Converts a Grid object to an XML representation as required by a
        # SmartView provider
        def to_xml(builder, include_dims=true)
            builder.grid do |xml|
                xml.cube
                dims_to_xml(xml) if include_dims
                xml.slices do |xml|
                    xml.slice :rows => @row_count, :cols => @col_count do |xml|
                        xml.data do |xml|
                            xml.range :start => 0, :end => @row_count * @col_count - 1 do
                                xml.vals @vals.join('|')
                                xml.types @types.join('|')
                            end
                        end
                    end
                end
            end
        end


        # Outputs a list of dimnesions, indicating the axis and position of each
        def dims_to_xml(xml)
            xml.dims do |xml|
                if @dimensions && @pov
                    @dimensions.each_with_index do |dim,i|
                        if @row_dims.include? dim
                          xml.dim :id => i, :name => dim, :row => @row_dims.index(dim), :hidden => 0, :expand => 1
                        elsif @col_dims.include? dim
                          xml.dim :id => i, :name => dim, :col => @col_dims.index(dim), :hidden => 0, :expand => 1
                        else
                          xml.dim :id => i, :name => dim, :pov => @pov[dim], :display => @pov[dim], :hidden => 0, :expand => 1
                        end
                    end
                end
            end
        end


        # Converts the grid to a text representation.
        def to_s(sep="\t")
            map do |row|
                row.join(sep)
            end.join("\n")
        end


    private

        # Converts an axis specification into an array of dimension name(s) and
        # an array of arrays for the axis member combinations
        def self.process_axis_spec(axis_spec, axis_name)
            # Extract dimension names and members for axis
            axis_dims = axis_spec.keys.first
            axis_dims = [axis_dims] if axis_dims.is_a? String
            axis_tuples = axis_spec.values.first
            if axis_tuples.is_a? String
                axis_tuples = [[axis_tuples]]
            elsif axis_tuples.first.is_a? String
                axis_tuples = axis_tuples.map{|mbr| [mbr]}
            end
            axis_tuples.each do |tuple|
                if tuple.size != axis_dims.size
                    raise InvalidGridSpecification, "#{axis_name} tuple size (#{tuple.size}) does not match number of dimensions (#{axis_dims.size})"
                end
            end
            return axis_dims, axis_tuples
        end

    end

end
