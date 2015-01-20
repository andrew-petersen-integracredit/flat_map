require 'spec_helper'

describe FlatMap::Mapping::Reader::Proc do
  let(:target)  { double('target') }
  let(:mapping) { double('mapping', :target => target) }
  let(:reader)  { described_class.new(mapping, lambda{ |t| t.foo }) }

  specify("#read should pass target to Proc object to fetch value") do
    expect(target).to receive(:foo).and_return(:bar)

    expect(reader.read).to eq :bar
  end
end
