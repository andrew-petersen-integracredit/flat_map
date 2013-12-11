require 'spec_helper'

module EmptyMapperSpec
  class MountedMapper < ::FlatMap::Mapper
  end

  class Mapper < ::FlatMap::EmptyMapper
    mount :mounted,
      :mapper_class_name => 'EmptyMapperSpec::MountedMapper',
      :target => Object.new

    trait :some_trait do
    end
  end
end

module FlatMap
  describe EmptyMapper do
    let(:mapper){ EmptyMapperSpec::Mapper.new(:some_trait){} }

    it 'should be normally initialized' do
      mapper.mounting(:mounted).should be_present
      mapper.trait(:some_trait).should be_present
      mapper.extension.should be_present
    end

    it 'should raise error for malounted mapper when target is not specified' do
      mapper_class = Class.new(::FlatMap::EmptyMapper) do
        mount :mounted, :mapper_class_name => 'EmptyMapperSpec::MountedMapper'
      end

      expect{ mapper_class.new.mounting(:mounted) }.
        to raise_error(::FlatMap::Mapper::Targeting::NoTargetError)
    end
  end
end
