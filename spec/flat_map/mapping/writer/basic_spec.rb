require 'spec_helper'

describe FlatMap::Mapping::Writer::Basic do
  let(:target)  { double('target') }
  let(:mapping) { double('mapping') }
  let(:writer)  { described_class.new(mapping) }

  specify("#write use target_attribute as writer to assign value to target") do
    expect(mapping).to receive(:target          ).and_return(target)
    expect(mapping).to receive(:target_attribute).and_return(:foo)
    expect(target ).to receive(:foo=).with(:bar)

    writer.write(:bar)
  end
end
