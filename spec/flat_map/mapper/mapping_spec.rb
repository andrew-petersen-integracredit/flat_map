require 'spec_helper'

module FlatMap
  module MappingSpec
    SpecTarget = Struct.new(:attr_a, :attr_b, :attr_c, :attr_d)

    class SpecMapper < Mapper
      # explicit mapping
      map :mapped_attr_a => :attr_a

      # implicit mapping
      map :attr_b

      # implicit and explicit with options in one call
      map :attr_c, :mapped_attr_d => :attr_d,
        :reader => :read_mappings,
        :writer => :write_mappings

      def read_mappings(mapping)
        "#{mapping.name}-#{target.send(mapping.target_attribute)}"
      end

      def write_mappings(mapping, value)
        target.send("#{mapping.target_attribute}=", value.upcase)
      end
    end

    class EmptyMapper < Mapper; end
  end

  describe 'Mapping' do
    context 'defining mappings' do
      it "should use Factory for defining mappings" do
        MappingSpec::EmptyMapper.should_receive(:define_mappings).once.
          with({:attr_a => :attr_a, :mapped_attr_b => :attr_b}, {:writer => false}).
          and_call_original
        Mapping::Factory.should_receive(:new).
                         with(:attr_a, :attr_a, :writer => false).
                         and_call_original
        Mapping::Factory.should_receive(:new).
                         with(:mapped_attr_b, :attr_b, :writer => false).
                         and_call_original

        MappingSpec::EmptyMapper.class_eval do
          map :attr_a, :mapped_attr_b => :attr_b, :writer => false
        end
      end
    end

    specify 'mapper class should have defined mappings' do
      MappingSpec::SpecMapper.should have(4).mappings
      MappingSpec::SpecMapper.mappings.all?{ |m| m.is_a?(Mapping::Factory) }.should be_true
    end

    context "for initialized mapper" do
      let(:target){ MappingSpec::SpecTarget.new('a', 'b', 'c', 'd') }
      let(:mapper){ MappingSpec::SpecMapper.new(target) }

      it "should be able to access mapping by its name" do
        mapper.mapping(:mapped_attr_a).should be_a(FlatMap::Mapping)
        mapper.mapping(:not_defined).should be_nil
      end

      describe 'reading and writing' do
        it "should be able to read from target via brackets" do
          mapper[:mapped_attr_a].should == 'a'
        end

        it 'should be able to write to target via brackets' do
          mapper[:attr_b] = 'B'
          target.attr_b.should == 'B'
        end

        it '#read should read all mappings to a hash' do
          mapper.read.should == {
            :mapped_attr_a => 'a',
            :attr_b        => 'b',
            :attr_c        => 'attr_c-c',
            :mapped_attr_d => 'mapped_attr_d-d'
          }
        end

        it '#write should assign values using mappings, ignoring invalid ones' do
          mapper.write \
            :mapped_attr_a => 'A',
            :attr_b        => 'B',
            :attr_c        => 'new-c',
            :mapped_attr_d => 'new-d'

          target.attr_a.should == 'A'
          target.attr_b.should == 'B'
          target.attr_c.should == 'NEW-C'
          target.attr_d.should == 'NEW-D'
        end
      end
    end
  end
end
