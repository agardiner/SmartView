class SmartView

    class InvalidPreference < RuntimeError; end

    # Represents the options that govern how SmartView retrievals operate.
    # The settings held in instances of this class correspond to the options
    # available in the Hyperion -> Options menu in SmartView. Preference
    # settings are independent of a session, and may be persisted and restored.
    class Preferences
        attr_accessor :suppress_zero, :suppress_invalid, :suppress_missing, :suppress_underscore, :suppress_noaccess
        attr_reader   :ancestor_position, :zoom_mode
        attr_accessor :navigate_with_data
        attr_accessor :include_selection, :within_selected_group, :remove_unselected_groups
        attr_accessor :no_access_text, :missing_text
        attr_reader   :member_display
        attr_accessor :suppress_repeated_members
        attr_reader   :indent
        attr_accessor :alias_table


        # Create a Preferences instance, with default settings.
        def initialize
            @ancestor_position = 'bottom'
            @zoom_mode = 'children'
            @navigate_with_data = true
            @include_selection = true
            @missing_text = '#Missing'
            @no_access_text = '#No Access'
            @member_display = 'name'
            @suppress_repeated_members = false
            @indent = 'none'
            @alias_table = 'none'
        end


        # Sets the ancestor position when expanding a hierarchy.
        # Valid options are 'top' or 'bottom'.
        # This setting is only applicable to HFM providers.
        def ancestor_position=(pos)
            pos = pos.to_s.downcase
            raise InvalidPreference unless pos =~ /^(top|bottom)$/
            @ancestor_position = pos
        end


        # Sets the zoom-in mode, controlling the extent to which a node is
        # expanded when zooming in.
        # Valid options are 'children', 'descendents', or 'base'.
        def zoom_mode=(mode)
            mode = mode.to_s.downcase
            raise InvalidPreference unless mode =~ /^(descendents|children|base)$/
            @zoom_mode = mode
        end


        # Set the indentation mode for totals and sub-items.
        # Valid options are 'none', 'subitems', or 'totals'.
        def indent=(ind)
            ind = ind.to_s.downcase
            raise InvalidPreference unless ind =~ /^(none|subitems|totals)$/
            @indent = ind
        end


        # Sets how members are displayed.
        # Valid options are 'name', 'description', or 'both'.
        # This setting is only applicable to HFM providers.
        def member_display=(display)
            display = display.to_s.downcase
            raise InvalidPreference unless display =~ /^(name|description|both)$/i
            @member_display = display
        end


        # Outputs preference settings to the supplied XML document. The
        # provider_type is used to determine what preferences are output.
        def inject_xml(xml, provider_type = :Unknown)
            xml.preferences do
                xml.row_suppression :zero => @suppress_zero ? 1 : 0, :invalid => @suppress_invalid ? 1 : 0,
                    :missing => @suppress_missing ? 1 : 0, :underscore => @suppress_underscore ? 1 : 0,
                    :noaccess => @suppress_noaccess ? 1 : 0
                xml.celltext :val => 0
                xml.zoomin :ancestor => @ancestor_position, :mode => @zoom_mode
                xml.navigate :withData => @navigate_with_data ? 1 : 0
                xml.includeSelection :val => @include_selection ? 1 : 0
                xml.repeatMemberLabels :val => @suppress_repeated_members ? 0 : 1
                xml.withinSelectedGroup :val => @within_selected_group ? 1 : 0
                xml.removeUnselectedGroup :val => @remove_unselected_groups ? 1 : 0
                xml.includeDescriptionInLabel :val => case @member_display
                    when /name/ then 0
                    when /description/ then 1
                    when /both/ then 2
                end
                xml.missingLabelText :val => @missing_text
                xml.noAccessText :val => @no_access_text
                xml.aliasTableName :val => @alias_table if provider_type == :Essbase
                xml.essIndent :val => case @indent
                    when /subitems/ then 1
                    when /totals/ then 2
                    when /none/ then 0
                end
            end
        end

    end

end

