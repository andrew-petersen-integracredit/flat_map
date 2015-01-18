require 'spec_helper'

class SpecFooValidator < ActiveModel::EachValidator
  def validate_each(object, attribute, value)
    object.errors.add(attribute, "can't be foo") if value == "foo"
  end
end

module FlatMap
  module ValidationsSpec
    class TargetClass < Struct.new(:attr_a, :attr_b, :attr_c)
    end

    class MountTargetClass < Struct.new(:attr_d)
    end

    class MountMapper < Mapper
      map :attr_d

      validates :attr_d, :presence => true
    end

    class HostMapper < Mapper
      map :attr_a

      validates_presence_of :attr_a

      trait :with_trait do
        map :attr_b

        validates :attr_b, :spec_foo => true

        set_callback :validate, :before, :set_default_attr_b, :prepend => true

        def set_default_attr_b
          self.attr_b = 'foo' if attr_b.blank?
        end
      end

      mount :mounted,
        :target            => lambda{ |_| ValidationsSpec::MountTargetClass.new },
        :mapper_class_name => 'FlatMap::ValidationsSpec::MountMapper'
    end
  end

  describe 'Validations' do
    let(:mapper) do
      ValidationsSpec::HostMapper.new(ValidationsSpec::TargetClass.new, :with_trait) do
        map :attr_c
        validates_presence_of :attr_c
      end
    end

    it 'should not be valid' do
      expect(mapper).not_to be_valid
    end

    it 'should call callbacks' do
      expect(mapper.trait(:with_trait)).to receive(:set_default_attr_b).and_call_original
      mapper.valid?
      expect(mapper.attr_b).to eq 'foo'
    end

    it 'should have all the errors' do
      mapper.valid?
      expect(mapper.errors[:attr_a]).to eq ["can't be blank"]
      expect(mapper.errors[:attr_b]).to eq ["can't be foo"]
      expect(mapper.errors[:attr_c]).to eq ["can't be blank"]
      expect(mapper.errors[:attr_d]).to eq ["can't be blank"]
    end
  end
end
