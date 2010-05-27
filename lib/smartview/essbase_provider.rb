class SmartView

    # Provides provider specific overrides for SmartView methods.
    module EssbaseProvider

        # Returns the provider type
        def provider_type
            :Essbase
        end


        # Parses a filter spec and returns a filter name and array of filter
        # arguments. Essbase supports a different set of filters that also use
        # a different syntax than the HFM filters. The lack of commonality with
        # HFM for common operations is a pain.  Therefore, we also support
        # the common filter operations via the alternate HFM syntax, e.g.
        #   * {Q1.[Descendants]}
        #   * {IS.[Children]}
        #   * {Year.[Base]}
        def process_filter(dimension, filter_spec = nil)
            # Default filter is entire dimension
            result = ['Hierarchy', [dimension]]
            if filter_spec
                if filter_spec =~ /^\{(?:([\w\s]+)\.)?\[([\w\s]+)\]\}$/
                    # Support a common filter syntax across providers - {(Member.)?[Filter]}
                    mbr = $1 || dimension
                    result = [$2, [mbr]]
                    if $2 =~ /^Base$/i
                        result = ['Level', [mbr, '0']]
                    end
                else
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
