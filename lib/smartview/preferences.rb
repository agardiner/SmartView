class SmartView

    class Preferences
        attr_accessor :suppress_zero, :suppress_invalid, :suppress_missing, :suppress_underscore, :suppress_noaccess
        attr_reader   :ancestor_position, :zoom_mode
        attr_accessor :navigate_with_data
        attr_accessor :include_selection, :within_selected_group, :remove_unselected_groups
        attr_accessor :no_access_text, :missing_text
        attr_accessor :suppress_repeated_members
        attr_reader   :indent

        def initialize
            @ancestor_position = 'bottom'
            @zoom_mode = 'children'
            @navigate_with_data = true
            @include_selection = true
            @missing_text = '#Missing'
            @no_access_text = '#No Access'
            @suppress_repeated_members = false
            @indent = 'none'
        end

        def ancestor_position=(pos)
            raise InvalidPreference unless pos =~ /^(top|bottom)$/i
            @ancestor_position = pos
        end

        def zoom_mode=(mode)
            raise InvalidPreference unless mode =~ /^(descendents|children|base)$/i
            @zoom_mode = mode
        end

        def indent=(ind)
            raise InvalidPreference unless indent =~ /^(none|subitems|totals)$/i
            @indent = indent
        end

        def inject_xml(xml)
            xml.preferences do
                xml.row_suppression :zero => @suppress_zero ? 1 : 0, :invalid => @suppress_invalid ? 1 : 0,
                    :underscore => @suppress_underscore ? 1 : 0, :noaccess => @suppress_noaccess ? 1 : 0
                xml.celltext :val => 0
                xml.zoomin :ancestor => @ancestor_position, :mode => @zoom_mode
                xml.navigate :withData => @navigate_with_data ? 1 : 0
                xml.includeSelection :val => @include_selection ? 1 : 1
                xml.repeatMemberLabels :val => @suppress_repeated_members ? 0 : 1
                xml.withinSelectedGroup :val => @within_selected_group ? 1 : 0
                xml.removeUnselectedGroup :val => @remove_unselected_groups ? 1 : 0
                xml.includeDescriptionInLabel :val => @name_and_description ? 1 : 0
                xml.missingLabelText :val => @missing_text
                xml.noAccessText :val => @no_access_text
                xml.essIndent :val => case @indent
                    when /subitems/i then 1
                    when /totals/i then 2
                    else 0
                end
            end
        end
    end

end

