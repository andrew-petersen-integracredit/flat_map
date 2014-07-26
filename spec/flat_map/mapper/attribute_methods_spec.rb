require 'spec_helper'

module FlatMap
  module AttributeMethodsSpec
    class SpecMapper < Mapper
      map :attr_a, :attr_b
    end
  end

  describe 'Attribute Methods' do
    let(:target){ OpenStruct.new }
    let(:mapper){ AttributeMethodsSpec::SpecMapper.new(target) }

    before do
      target.attr_a = 'a'
      target.attr_b = 'b'
    end

    it 'correctly responds to dynamic methods' do
      mapper.respond_to?(:attr_a=).should be_true
      mapper.method(:attr_a=).should_not be_nil

      mapper.respond_to?(:attr_b=).should be_true
      mapper.method(:attr_b=).should_not be_nil
    end

    it 'should be able to read values via method calls' do
      mapper.attr_a.should == 'a'
      mapper.attr_b.should == 'b'
    end

    it 'should be able to write values via method calls' do
      mapper.attr_a = 'A'
      mapper.attr_b = 'B'
      target.attr_a.should == 'A'
      target.attr_b.should == 'B'
    end

    it 'should still raise for unknown or private method calls' do
      expect{ mapper.undefined_method }.to raise_error(NoMethodError)
      expect{ mapper.attribute_methods }.to raise_error(NoMethodError)
    end
  end
end
