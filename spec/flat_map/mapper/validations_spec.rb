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

  describe 'Mapper Validations' do
    let(:mapper) do
      ValidationsSpec::HostMapper.new(ValidationsSpec::TargetClass.new, :with_trait) do
        map :attr_c
        validates_presence_of :attr_c
      end
    end

    it 'should not be valid' do
      mapper.should_not be_valid
    end

    it 'should call callbacks' do
      mapper.trait(:with_trait).should_receive(:set_default_attr_b).and_call_original
      mapper.valid?
      mapper.attr_b.should == 'foo'
    end

    it 'should have all the errors' do
      mapper.valid?
      mapper.errors[:attr_a].should == ["can't be blank"]
      mapper.errors[:attr_b].should == ["can't be foo"]
      mapper.errors[:attr_c].should == ["can't be blank"]
      mapper.errors[:attr_d].should == ["can't be blank"]
    end
  end
end
