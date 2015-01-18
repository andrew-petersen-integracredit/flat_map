require 'spec_helper'

describe FlatMap::Mapping::Reader::Basic do
  let(:target)  { double('target') }
  let(:mapping) { double('mapping') }
  let(:reader)  { described_class.new(mapping) }

  specify("#read should fetch value from mapping's target_attribute") do
    expect(mapping).to receive(:target          ).and_return(target)
    expect(mapping).to receive(:target_attribute).and_return(:foo)
    expect(target ).to receive(:foo             ).and_return(:bar)

    expect(reader.read).to eq :bar
  end
end
