require 'smartview/grid'

describe SmartView::Grid, '.cross_join' do

    it "accepts any number of arguments" do
        lambda{ SmartView::Grid.cross_join() }.should_not raise_exception
        lambda{ SmartView::Grid.cross_join('a') }.should_not raise_exception
        lambda{ SmartView::Grid.cross_join('a', 'b') }.should_not raise_exception
        lambda{ SmartView::Grid.cross_join('a', 'b', 'c') }.should_not raise_exception
        lambda{ SmartView::Grid.cross_join('a', 'b', 'c', 'd') }.should_not raise_exception
        lambda{ SmartView::Grid.cross_join('a', 'b', 'c', 'd', 'e') }.should_not raise_exception
    end

    it "returns nil if no arguments are specified" do
        SmartView::Grid.cross_join(nil).should be_nil
    end

    it "returns nil if any argument is nil" do
        SmartView::Grid.cross_join(nil).should be_nil
        SmartView::Grid.cross_join('a', nil).should be_nil
        SmartView::Grid.cross_join(nil, 'a').should be_nil
    end

    it "converts a to [[a]]" do
        SmartView::Grid.cross_join('a').should == [['a']]
    end

    it "converts a,b to [[a, b]]" do
        SmartView::Grid.cross_join('a', 'b').should == [['a', 'b']]
    end

    it "converts a,b,c to [[a, b, c]]" do
        SmartView::Grid.cross_join('a', 'b', 'c').should == [['a', 'b', 'c']]
    end

    it "converts [a, b] to [[a], [b]]" do
        SmartView::Grid.cross_join(['a', 'b']).should == [['a'], ['b']]
    end

    it "converts [a, b, c] to [[a], [b], [c]]" do
        SmartView::Grid.cross_join(['a', 'b']).should == [['a'], ['b']]
    end

    it "converts a, [b, c] to [[a, b], [a, c]]" do
        SmartView::Grid.cross_join('a', ['b', 'c']).should == [['a', 'b'], ['a', 'c']]
    end

    it "converts [a, b], [c, d] to [[a, c], [a, d], [b, c], [b, d]]" do
        SmartView::Grid.cross_join(['a', 'b'], ['c', 'd']).should == [['a', 'c'], ['a', 'd'], ['b', 'c'], ['b', 'd']]
    end

end
