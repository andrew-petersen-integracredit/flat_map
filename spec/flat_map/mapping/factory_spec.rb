require 'spec_helper'

describe FlatMap::Mapping::Factory do
  let(:factory){ described_class.new(:foo, :bar, :baz) }

  specify('#create should delegate all initialization params to new mapping') do
    mapper_stub = double('mapper')
    expect(FlatMap::Mapping).to receive(:new).with(mapper_stub, :foo, :bar, :baz)

    factory.create(mapper_stub)
  end
end
