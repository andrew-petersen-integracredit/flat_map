require 'spec_helper'

describe FlatMap::Mapping::Reader::Proc do
  let(:target){ double('target') }
  let(:mapping){ double('mapping', :target => target) }
  let(:reader){ described_class.new(mapping, lambda{ |t| t.foo }) }

  specify("#read should pass target to Proc object to fetch value") do
    target.should_receive(:foo).and_return(:bar)

    reader.read.should == :bar
  end
end
