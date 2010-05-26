class SmartView

    # Provides provider specific overrides for SmartView methods.
    module HFMProvider

        # Returns the provider type
        def provider_type
            :HFM
        end


        # Processes a filter string specification, and returns the filter name
        # and an array of arguments. The filter string specification should be
        # as it is displayed in the member selection dialog in SmartView, e.g.
        #   * _Dimension name_
        #   * [Descendants](_Member name_)
        #   * [Base](_Member name_)
        #   * [Third Generation](Period)
        #   * _Member list name_(_Dimension name_)
        # Alternatively, it can also be as displayed in HFM, e.g.
        #   * {Q1.[Descendants]}
        #   * {[Base]}
        #   * {_Member list name_}
        def process_filter(dimension, filter_spec = nil)
            filter_spec.strip! if filter_spec
            case filter_spec
            when /^([^(]+)\(([^)]+)\)$/
                [$1, [$2]]
            when /^\{(?:([\w\s]+)\.)?(\[[\w\s]+\])\}$/
                [$2, [$1 || dimension]]
            when /^\{([\w\s]+)\}$/
                [$1, [dimension]]
            when NilClass, /^\w+$/
                ['[Hierarchy]', ['root']]
            else
                raise UnrecognisedFilterExpression, "Unable to parse filter expression '#{filter_spec}'"
            end
        end

    end

end
