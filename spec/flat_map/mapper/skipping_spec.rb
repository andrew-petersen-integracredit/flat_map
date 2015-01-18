require 'spec_helper'

module FlatMap
  module SkippingSpec
    class SpecMapper < Mapper
      trait :with_trait do
        map :attr_a, :attr_b

        set_callback :validate, :before, :set_attr_a, :prepend => true
        set_callback :save, :before, :set_attr_b

        validates_numericality_of :attr_a

        def set_attr_a
          self.attr_a = 'a'
        end

        def set_attr_b
          self.attr_b = 'b'
        end
      end
    end
  end

  describe 'Skipping' do
    let(:mapper){ SkippingSpec::SpecMapper.new(OpenStruct.new, :with_trait) }

    before{ mapper.trait(:with_trait).skip! }

    it 'should completely ignore skipped mounting' do
      expect(mapper       ).to be_valid
      expect(mapper.save  ).to be true
      expect(mapper.attr_a).to be_nil
      expect(mapper.attr_b).to be_nil
    end

    it '#use! should enable skipped mounting' do
      mapper.trait(:with_trait).use!

      expect(mapper).not_to be_valid
      expect(mapper.attr_a).to eq 'a'
      expect(mapper.errors[:attr_a]).to be_present

      mapper.attr_a = 5
      mapper.save
      expect(mapper.attr_b).to eq 'b'
    end
  end

  describe 'Skipping ActiveRecord' do
    let(:target){ OpenStruct.new }
    let(:mapper){ SkippingSpec::SpecMapper.new(target, :with_trait) }

    before{ expect(target).
        to receive(:is_a?).at_least(1).times.with(ActiveRecord::Base).and_return(true) }

    context 'for new record' do
      before do
        expect(target).to receive(:new_record?).at_least(1).times.and_return(true)
        mapper.trait(:with_trait).skip!
      end

      specify '#skip! should set ivar @destroyed to true' do
        expect(target.instance_variable_get('@destroyed')).to be true
      end

      specify '#use! should set ivar @destroyed to true' do
        mapper.trait(:with_trait).use!
        expect(target.instance_variable_get('@destroyed')).to be false
      end
    end

    context 'for persisted record' do
      before do
        expect(target).to receive(:new_record?).at_least(1).times.and_return(false)
      end

      specify '#skip! should reload persisted record' do
        expect(target).to receive(:reload)
        mapper.trait(:with_trait).skip!
      end

      specify '#use! should use all nested mountings' do
        mapper.trait(:with_trait).skip!
        mock = double('mounting')
        expect(mock).to receive(:use!)
        expect(mapper.trait(:with_trait)).to receive(:all_nested_mountings).and_return([mock])
        mapper.trait(:with_trait).use!
      end
    end
  end
end
