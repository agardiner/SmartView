class SmartView

    # Provides provider specific overrides for SmartView methods.
    module EssbaseProvider

        # Returns the provider type
        def provider_type
            :Essbase
        end


        # Parses a filter spec and returns a filter name and array of filter
        # arguments.
        def process_filter(dimension, filter_spec = nil)
            # Default filter is entire dimension
            result = ['Hierarchy', [dimension]]
            if filter_spec
                # Retrieve list of filters for dimension, and search for one
                # that matches the filter spec
                filters = get_filters(dimension)
                filters.each do |filter|
                    if md = (filter.decompose && filter.decompose.match(filter_spec))
                        result = [filter.name, md.captures]
                        break
                    end
                end
            end
            result
        end


        # Implement Essbase-specific method for MDX queries.
        def mdx_query(mdx)
            check_attached

            @logger.info "Executing MDX query: #{mdx}"
            @req.ExecuteQuery do |xml|
                xml.sID @session_id
                @preferences.inject_xml xml, @provider_type
                xml.mdx mdx
            end
            doc = invoke
            Grid.from_xml(doc)
        end

    end

end
