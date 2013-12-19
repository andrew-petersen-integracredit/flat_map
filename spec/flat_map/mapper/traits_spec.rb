require 'spec_helper'

module FlatMap
  module TraitsSpec
    TargetClass = Struct.new(:attr_a, :attr_b)
    MountClass  = Struct.new(:attr_c, :attr_d)

    class HostMapper < Mapper
      map :attr_a

      trait :trait_one do
        map :attr_b

        mount :spec_mount,
          :mapper_class_name => 'FlatMap::TraitsSpec::MountMapper',
          :target => lambda{ |_| TraitsSpec.mount_target }

        def method_one
          'one'
        end

        trait :trait_one_nested do
          def method_one_nested
            'nested_one'
          end
        end
      end

      trait :trait_two do
        def method_two
          method_one
        end
      end
    end

    class MountMapper < Mapper
      map :attr_c, :attr_d
    end

    class EmptyMapper < Mapper; end

    def self.mount_target
      @mount_target ||= MountClass.new('c', 'd')
    end
  end

  describe 'Traits' do
    describe 'trait definition' do
      it "should add a traited mapper factory to a class" do
        TraitsSpec::EmptyMapper.should_receive(:mount).
                                with(kind_of(Class), :trait_name => :a_trait).
                                and_call_original
        expect{ TraitsSpec::EmptyMapper.trait(:a_trait) }.
          to change{ TraitsSpec::EmptyMapper.mountings.length }.by(1)
        trait_mapper_class =
          TraitsSpec::EmptyMapper.mountings.first.instance_variable_get('@identifier')
        trait_mapper_class.name.should == 'FlatMap::TraitsSpec::EmptyMapperATraitTrait'
      end
    end

    describe 'trait usage' do
      let(:target){ TraitsSpec::TargetClass.new('a', 'b') }
      let(:mount_target){ TraitsSpec.mount_target }
      let(:mapper){ TraitsSpec::HostMapper.new(target, :trait_one) }
      let(:trait){ mapper.trait(:trait_one) }

      describe 'trait properties' do
        subject{ trait }

        it{ should_not be_extension }
        it{ should be_owned }
        its(:owner){ should == mapper }
      end

      it 'should be able to access trait by name' do
        mapper.trait(:trait_one).should be_a(Mapper)
        mapper.trait(:undefined).should be_nil
      end

      it 'should not contain unused trait' do
        mapper.trait(:trait_two).should be_nil
      end

      it 'should have mountings of a trait' do
        mapper.mounting(:spec_mount).should be_present
      end

      it '#read should read values with respect to trait' do
        mapper.read.should == {
          :attr_a => 'a',
          :attr_b => 'b',
          :attr_c => 'c',
          :attr_d => 'd'
        }
      end

      it '#write should properly distribute values' do
        mapper.write \
          :attr_a => 'A',
          :attr_b => 'B',
          :attr_c => 'C',
          :attr_d => 'D'
        target.attr_a.should == 'A'
        target.attr_b.should == 'B'
        mount_target.attr_c.should == 'C'
        mount_target.attr_d.should == 'D'
      end

      specify 'mapper should be avle to call methods of enabled traits' do
        mapper = TraitsSpec::HostMapper.new(target, :trait_one)
        mapper.method_one.should == 'one'
        expect{ mapper.method_two }.to raise_error(NoMethodError)
      end

      specify 'traits should be able to call methods of each other' do
        mapper = TraitsSpec::HostMapper.new(target, :trait_one, :trait_two)
        mapper.trait(:trait_two).method_two.should == 'one'
      end

      describe 'trait nesting' do
        let(:mapper){ TraitsSpec::HostMapper.new(target, :trait_one_nested) }

        it 'should still be able to have top-level trait definitions' do
          mapper.mounting(:spec_mount).should be_present
          mapper.method_one.should == 'one'
        end

        it 'should have new definitions' do
          mapper.method_one_nested.should == 'nested_one'
        end
      end

      describe 'extension trait' do
        let(:mapper) do
          TraitsSpec::HostMapper.new(target) do
            map :attr_b

            def writing_error=(value)
              raise ArgumentError, 'cannot be foo' if value == 'foo'
            rescue ArgumentError => e
              errors.preserve :writing_error, e.message
            end
          end
        end

        it 'should behave like a normal trait' do
          mapper.trait(:extension).should be_present
          mapper.read.should include :attr_b => 'b'
        end

        it 'should be accessible' do
          mapper.extension.should be_present
        end

        it 'should be_extension' do
          mapper.extension.should be_extension
        end

        it "should be able to handle save exception of traits" do
          expect{ mapper.apply(:writing_error => 'foo') }.not_to raise_error
          mapper.errors[:writing_error].should include 'cannot be foo'
        end
      end
    end
  end
end
