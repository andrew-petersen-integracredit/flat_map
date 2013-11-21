require 'spec_helper'

describe FlatMap::Mapping::Reader::Basic do
  let(:target){ double('target') }
  let(:mapping){ double('mapping') }
  let(:reader){ described_class.new(mapping) }

  specify("#read should fetch value from mapping's target_attribute") do
    mapping.should_receive(:target).and_return(target)
    mapping.should_receive(:target_attribute).and_return(:foo)
    target.should_receive(:foo).and_return(:bar)

    reader.read.should == :bar
  end
end
