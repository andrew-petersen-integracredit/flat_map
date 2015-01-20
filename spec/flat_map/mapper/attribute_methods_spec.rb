require 'spec_helper'

module FlatMap
  module AttributeMethodsSpec
    class SpecMapper < Mapper
      map :attr_a, :attr_b
    end
  end

  describe 'Attribute Methods' do
    let(:target) { OpenStruct.new }
    let(:mapper) { AttributeMethodsSpec::SpecMapper.new(target) }

    before do
      target.attr_a = 'a'
      target.attr_b = 'b'
    end

    it 'correctly responds to dynamic methods' do
      expect(mapper).to respond_to(:attr_a=)
      expect(mapper.method(:attr_a=)).not_to be_nil

      expect(mapper).to respond_to(:attr_b=)
      expect(mapper.method(:attr_b=)).not_to be_nil
    end

    it 'should be able to read values via method calls' do
      expect(mapper.attr_a).to eq 'a'
      expect(mapper.attr_b).to eq 'b'
    end

    it 'should be able to write values via method calls' do
      mapper.attr_a = 'A'
      mapper.attr_b = 'B'
      expect(target.attr_a).to eq 'A'
      expect(target.attr_b).to eq 'B'
    end

    it 'should still raise for unknown or private method calls' do
      expect{ mapper.undefined_method  }.to raise_error(NoMethodError)
      expect{ mapper.attribute_methods }.to raise_error(NoMethodError)
    end
  end
end
