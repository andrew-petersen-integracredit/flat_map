require 'spec_helper'

describe FlatMap::Errors do
  let(:errors) {
    described_class.new(
      double( 'mapper', :suffixed? => true,
                        :suffix    => 'foo',
                        'attr_foo' => 2)
    )
  }

  it "preserved errors should appear on #empty? call exactly once" do
    errors.preserve :base, 'an error'
    expect(errors).not_to be_empty
    expect(errors[:base]).to eq ['an error']
    expect{ errors.empty? }.not_to change{ errors[:base].length }
  end

  it "should add error to mapper with suffix" do
    errors.add(:attr, 'an error')
    expect(errors[:attr_foo]).to eq ['an error']
  end
end
