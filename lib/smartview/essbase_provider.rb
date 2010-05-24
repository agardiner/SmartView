class SmartView

    # Provides provider specific overrides for SmartView methods.
    module EssbaseProvider

        # Returns the provider type
        def provider_type
            :Essbase
        end


        def default_filter(dimension)
            "#{dimension}.Descendants"
        end


        def process_filter(dimension, filter_spec = nil)
            return 'Hierarchy', [dimension]
        end


        # Implement Essbase-specific method for MDX queries.
        def mdx_query(mdx)
            check_attached

            @logger.info "Executing MDX query: #{mdx}"
            @req.ExecuteQuery do |xml|
                xml.sID @session_id
                @preferences.inject_xml xml, @alias_table
                xml.mdx mdx
            end
            doc = invoke
            Grid.from_xml(doc)
        end

    end

end
