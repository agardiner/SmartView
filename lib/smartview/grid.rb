class SmartView

    class InvalidGridSpecification < RuntimeError; end

    class Grid

        # Cell-type constants
        GRID_TYPE_UPPER_LEFT = '7'
        GRID_TYPE_MEMBER = '0'
        GRID_TYPE_DATA = '2'


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
        def self.define(rows, cols=nil)
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

            Grid.new(row_count, col_count, vals, types, row_dims, col_dims)
        end


        # Creates a Grid object from an XML document returned from a SmartView provider
        def self.from_xml(doc)
            slice = doc.at('*/slice')
            row_count = slice['rows'].to_i
            col_count = slice['cols'].to_i
            vals = slice.at('/data/range/vals').to_plain_text.split('|')
            types = slice.at('data/range/types').to_plain_text.split('|')

            Grid.new(row_count, col_count, vals, types)
        end


        # Creates a new Grid object
        def initialize(row_count, col_count, vals, types, row_dims=nil, col_dims=nil)
            @row_count = row_count
            @col_count = col_count
            @vals = vals
            @types = types
            @row_dims = row_dims
            @col_dims = col_dims
        end


        # Iterates over each row of the grid, returning an array of values (one
        # per column)
        def each_row
            0.upto(@row_count-1) do |row|
                fields = []
                0.upto(@col_count-1) do |col|
                    fields << @vals[row * @col_count + col]
                end
                yield fields
            end
        end


        # Converts a Grid object to an XML representation as required by a
        # SmartView provider
        def to_xml(builder, dimensions, pov)
            builder.grid do |xml|
                xml.cube
                xml.dims do |xml|
                    dimensions.each_with_index do |dim,i|
                        if @row_dims.include? dim
                          xml.dim :id => i, :name => dim, :row => @row_dims.index(dim), :hidden => 0, :expand => 1
                        elsif @col_dims.include? dim
                          xml.dim :id => i, :name => dim, :col => @col_dims.index(dim), :hidden => 0, :expand => 1
                        else
                          xml.dim :id => i, :name => dim, :pov => pov[dim], :display => pov[dim], :hidden => 0, :expand => 1
                        end
                    end
                end
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
