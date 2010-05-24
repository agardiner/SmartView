class SmartView

    # Provides provider specific overrides for SmartView methods.
    module HFMProvider

        # Returns the provider type
        def provider_type
            :HFM
        end


        def default_filter(dimension)
            "root.[Hierarchy]"
        end


        def process_filter(dimension, filter_spec = nil)
           return '[Hierarchy]', ['root']
        end

    end

end
