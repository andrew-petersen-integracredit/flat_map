require 'spec_helper'

describe FlatMap::Mapping::Writer::Method do
  let(:mapper)  { double('mapper') }
  let(:mapping) { double('mapping', :mapper => mapper) }
  let(:writer)  { described_class.new(mapping, :write_with_method) }

  specify("#write delegates to mapper-defined method and passes mapping and value to it") do
    expect(mapper).to receive(:write_with_method).with(mapping, :foo)

    writer.write(:foo)
  end
end
