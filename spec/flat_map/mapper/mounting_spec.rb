require 'spec_helper'

module FlatMap
  module MountingSpec
    MountTarget = Struct.new(:attr_a, :attr_b)

    class MountMapper < Mapper
      map :attr_a

      trait :with_b do
        map :mapped_attr_b => :attr_b
      end

      def a_method
        'a value'
      end
    end

    class HostMapper < Mapper
      map :host_attr, :reader => :attr_value, :writer => false

      mount :spec_mount,
        :traits            => :with_b,
        :target            => lambda{ |obj| MountingSpec.mount_target },
        :mapper_class_name => 'FlatMap::MountingSpec::MountMapper'

      mount :spec_mount_before,
        :target            => lambda{ |obj| MountingSpec.mount_target },
        :mapper_class_name => 'FlatMap::MountingSpec::MountMapper',
        :save              => :before

      def attr_value(*)
        'attr'
      end
    end

    class EmptyMapper < Mapper; end

    def self.mount_target
      @mount_target ||= MountTarget.new('a', 'b')
    end

    def self.reset_mount_target
      @mount_target = nil
    end
  end

  module MountingSuffixSpec
    class SpecMapper < Mapper
      mount_options = {
        :suffix            => 'foo',
        :mapper_class_name => 'FlatMap::MountingSuffixSpec::MountMapper',
        :target            => lambda{ |_| OpenStruct.new } }
      mount :mount, mount_options do
        mount :nested,
          :mapper_class_name => 'FlatMap::MountingSuffixSpec::NestedMapper',
          :target            => lambda{ |_| OpenStruct.new }
      end
    end

    class MountMapper < Mapper
      map :attr_mount
    end

    class NestedMapper < Mapper
      map :attr_nested
    end
  end

  describe 'Mounting' do
    let(:mapper){ MountingSpec::HostMapper.new(Object.new) }
    let(:mounting){ mapper.mounting(:spec_mount) }

    after{ MountingSpec.reset_mount_target }

    context 'defining mountings' do
      it "should use Factory for defining mappings" do
        Mapper::Factory.should_receive(:new).
                        with(:foo, :mapper_class_name => 'FooMapper').
                        and_call_original

        expect{ MountingSpec::EmptyMapper.mount(:foo, :mapper_class_name => 'FooMapper') }.
          to change{ MountingSpec::EmptyMapper.mountings.length }.from(0).to(1)
      end
    end

    describe 'properties' do
      it{ mapper.hosted?.should be false }
      it{ mounting.hosted?.should be true }
      it{ mounting.host.should == mapper }
    end

    it 'should be able to access mapping by name' do
      mapper.mounting(:spec_mount).should be_a(FlatMap::Mapper)
      mapper.mounting(:undefined_mount).should be_nil
    end

    describe "#read" do
      it 'should add mounted mappers to a result' do
        mapper.read.should == {
          :host_attr     => 'attr',
          :attr_a        => 'a',
          :mapped_attr_b => 'b'
        }
      end

      it 'should define dynamic writer methods' do
        mapper.respond_to?(:attr_a).should be true
        mapper.method(:attr_a).should_not be nil

        mapper.respond_to?(:mapped_attr_b).should be true
        mapper.method(:mapped_attr_b).should_not be nil
      end
    end

    describe "#write" do
      it 'should define dynamic writer methods' do
        mapper.respond_to?(:attr_a=).should be true
        mapper.method(:attr_a=).should_not be nil

        mapper.respond_to?(:mapped_attr_b=).should be true
        mapper.method(:mapped_attr_b=).should_not be nil
      end

      it 'should pass values to mounted mappers' do
        target = MountingSpec.mount_target
        mapper.write :attr_a => 'A', :mapped_attr_b => 'B'
        target.attr_a.should == 'A'
        target.attr_b.should == 'B'
      end
    end

    it 'should delegate missing methods to mounted mappers' do
      expect{ mapper.a_method.should == 'a value' }.not_to raise_error
    end

    specify '#before_save_mountings' do
      mapper.before_save_mountings.should == [mapper.mounting(:spec_mount_before)]
    end

    specify '#after_save_mountings' do
      mapper.after_save_mountings.should == [mapper.mounting(:spec_mount)]
    end

    context 'with suffix' do
      let(:mapper){ MountingSuffixSpec::SpecMapper.new(OpenStruct.new) }
      let(:mounting){ mapper.mounting(:mount_foo) }

      it{ mapper.should_not be_suffixed }
      it{ mounting.should be_suffixed }

      it 'should cascade to nested mappings' do
        mapper.attr_mount_foo  = 'foo'
        mapper.attr_nested_foo = 'bar'

        mapper.read.should include({
          :attr_mount_foo  => 'foo',
          :attr_nested_foo => 'bar' })
      end
    end
  end
end
