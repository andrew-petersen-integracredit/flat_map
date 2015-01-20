require 'spec_helper'

describe FlatMap::Mapping::Writer::Proc do
  let(:target)  { double('target') }
  let(:mapping) { double('mapping', :target => target) }
  let(:writer)  { described_class.new(mapping, lambda{ |t, v| t.foo(v) }) }

  specify("#write should pass target and value to Proc object for assignment") do
    expect(target).to receive(:foo).with(:bar)

    writer.write(:bar)
  end
end
