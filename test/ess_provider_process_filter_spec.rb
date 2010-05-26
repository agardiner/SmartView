require 'smartview/essbase_provider'
require 'smartview/filter'
require 'hpricot'

class EssbaseProvider
    include SmartView::EssbaseProvider

    FILTERS_XML = %q{
        <res_EnumFilters>
        <filterList>
          <filter name="Hierarchy" id="0" compose="" decompose="">
            <arg id="0" name="top" type="str" prompt="Member"/>
          </filter>
          <filter name="Children" id="1" compose="(%0.CHILDREN)" decompose="^\((.+)\.CHILDREN\)$">
            <arg id="0" name="top" type="str" prompt="Member"/>
          </filter>
          <filter name="Level" id="2" compose="DESCENDANTS(%0,%0.DIMENSION.LEVELS(%1))" decompose="^DESCENDANTS\((.+),.*\.LEVELS\((.+)\)\)$">
            <arg id="0" name="top" type="str" prompt="Member"/>
            <arg id="1" name="n" type="int" prompt="Level"/>
          </filter>
          <filter name="Descendants" id="3" compose="DESCENDANTS(%0)" decompose="^DESCENDANTS\( *(.+) *\)$">
            <arg id="0" name="top" type="str" prompt="Member"/>
          </filter>
          <filter name="Generation" id="4" compose="(%0.GENERATIONS(%1).MEMBERS)" decompose="^\((.+)\.GENERATIONS\((.+)\)\.MEMBERS\)$">
            <arg id="0" name="top" type="str" prompt="Member"/>
            <arg id="1" name="n" type="int" prompt="Generation"/>
          </filter>
          <filter name="UDA" id="5" compose="UDA(%0, %1)" decompose="^UDA\((.+), *(.+)\)$">
            <arg id="0" name="top" type="str" prompt="Top Dimension or Member"/>
            <arg id="1" name="uda" type="str" prompt="UDA"/>
          </filter>
          <filter name="Attribute" id="6" compose="ATTRIBUTE(%0)" decompose="^ATTRIBUTE\( *(.+) *\)$">
            <arg id="0" name="name" type="attribute" prompt="Attribute Member"/>
          </filter>
          <filter name="SharedLevel" id="7" compose="SHAREDLEVEL(%0,%0.DIMENSION.LEVELS(%1))" decompose="^SHAREDLEVEL\((.+),.*\.LEVELS\((.+)\)\)$">
            <arg id="0" name="top" type="str" prompt="Member"/>
            <arg id="1" name="n" type="int" prompt="Level"/>
          </filter>
        </filterList>
        </res_EnumFilters>
    }

    def get_filters(dimension)
        filters = []
        Hpricot.XML(FILTERS_XML).search('//res_EnumFilters/filterList/filter').each do |filter|
            filters << SmartView::Filter.new(filter)
        end
        filters
    end
end

describe SmartView::EssbaseProvider, '#process_filter' do

    before :each do
        @ess = EssbaseProvider.new
    end

    it "parses a nil filter spec as the Hierarchy filter" do
        @ess.process_filter('Entity', nil).should == ['Hierarchy', ['Entity']]
    end

    it "parses (Member.CHILDREN) as a Children filter" do
        @ess.process_filter('Market', '(West.CHILDREN)').should == ['Children', ['West']]
    end

    it "parses DESCENDANTS(Member) as a Descendants filter" do
        @ess.process_filter('Accounts', 'DESCENDANTS([IS])').should == ['Descendants', ['[IS]']]
    end

    it "parses DESCENDANTS([VN001],[VN001].DIMENSION.LEVELS(1)) as a Level filter" do
        @ess.process_filter('Entity', 'DESCENDANTS([VN001],[VN001].DIMENSION.LEVELS(1))').should == ['Level', ['[VN001]', '1']]
    end

    it "parses ([BS].GENERATIONS(3).MEMBERS) as a Generation filter" do
        @ess.process_filter('Account', '([BS].GENERATIONS(3).MEMBERS)').should == ['Generation', ['[BS]', '3']]
    end

    it "parses UDA(Entity, LC010) as a UDA filter" do
        @ess.process_filter('Entity', 'UDA(Entity, LC030)').should == ['UDA', ['Entity', 'LC030']]
    end

end
