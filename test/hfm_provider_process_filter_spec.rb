require 'smartview/hfm_provider'

class HFMProvider
    include SmartView::HFMProvider
end

describe SmartView::HFMProvider, '#process_filter' do

    before :each do
        @hfm = HFMProvider.new
    end

    it "parses a nil filter spec as the [Hierarchy] / root filter" do
        @hfm.process_filter('Entity', nil).should == ['[Hierarchy]', ['root']]
    end

    it "parses a dimension name as the [Hierarchy] / root filter" do
        @hfm.process_filter('Period', 'Period').should == ['[Hierarchy]', ['root']]
    end

    it "parses '[filter](member) as [filter] / member" do
        @hfm.process_filter('Account', '[Base](Account)').should == ['[Base]', ['Account']]
        @hfm.process_filter('Period', '[Third Generation](Period)').should == ['[Third Generation]', ['Period']]
    end

    it "parses '{[Base]}' as [Base] / Dimension" do
        @hfm.process_filter('Account', '{[Base]}').should == ['[Base]', ['Account']]
    end

    it "parses '{Member.[Descendants]} as [Descendants] / Member" do
        @hfm.process_filter('Account', '{IS.[Descendants]}').should == ['[Descendants]', ['IS']]
    end

end
