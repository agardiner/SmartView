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

    end

end
