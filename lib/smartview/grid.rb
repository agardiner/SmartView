class SmartView

    class Grid
        def initialize(doc)
            slice = doc.at('*/slice')
            @row_count = slice['rows'].to_i
            @col_count = slice['cols'].to_i
            @vals = slice.at('/data/range/vals').to_plain_text.split('|')
            @types = slice.at('data/range/types').to_plain_text.split('|')
        end

        def output
            0.upto(@row_count-1) do |row|
                fields = []
                0.upto(@col_count-1) do |col|
                    fields << @vals[row * @col_count + col]
                end
                yield fields
            end
        end
    end

end
