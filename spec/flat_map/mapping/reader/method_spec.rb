require 'spec_helper'

describe FlatMap::Mapping::Reader::Method do
  let(:mapper)  { double('mapper') }
  let(:mapping) { double('mapping', :mapper => mapper) }
  let(:reader)  { described_class.new(mapping, :read_with_method) }

  specify("#read delegates to mapper-defined method and passes mapping to it") do
    expect(mapper).to receive(:read_with_method).with(mapping).and_return(:bar)

    expect(reader.read).to eq :bar
  end
end
