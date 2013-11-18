require 'spec_helper'

class MountedMapper < FlatMap::Mapper
  map :attribute_4
  validate :attribute_4, :presence => true
end

class TestMapper < FlatMap::Mapper
  class FooValidator < ActiveModel::EachValidator
    def validate_each(object, attribute, value)
      object.errors.add(attribute, "is not foo") unless value == "foo"
    end
  end

  map :attribute_1
  map :attribute_2
  map :alternate_1 => :attribute_1

  mount :mounted do
    # This is an empty extension for mounted mapper
  end

  set_callback :save, :before, :before_save_callback
  set_callback :validate, :before, :before_validate_callback

  validates_presence_of :attribute_1
  validates :attribute_2, :foo => true

  def before_save_callback
    self.attribute_2 = "save callback value"
  end

  def before_validate_callback
    self.attribute_2 = "validate callback value"
  end

  def a_method
    'a_method return value'
  end

  def skip_trait
    trait(:has_a_trait).skip!
  end

  trait :has_a_trait do
    map :attribute_3
    map :attribute_4

    set_callback :save, :before, :set_attribute_3
    set_callback :validate, :before, :set_attribute_4

    validates :attribute_3, :presence => true

    def set_attribute_3
      self.attribute_3 = "callback value"
    end

    def set_attribute_4
      self.attribute_4 = "callback value"
    end
  end
end

module Mod
end

class BaseMapper < FlatMap::Mapper
  class MapperTarget < Struct.new(:attribute_1, :attribute_2, :attribute_3)
    def mounted
      Struct.new(:attribute_4).new
    end
  end

  include Mod

  self.target_class_name = 'BaseMapper::MapperTarget'

  map :attr1 => :attribute_1, :attr2 => :attribute_2

  mount :mounted

  trait :a_trait do
    map :attr3 => :attribute_3
  end

  class Inherited < self
  end
end

module FlatMap
  describe Mapper do
    let(:mounted_target_class) { Struct.new(:attribute_4) }
    let(:mounted_target) { mounted_target_class.new }

    let(:target_class) { Struct.new(:attribute_1, :attribute_2, :attribute_3, :attribute_4, :mounted) }
    let(:target) { target = target_class.new; target.mounted = mounted_target; target  }

    describe "initialization" do
      it "should raise exception without target" do
        expect { Mapper.new(nil) }.to raise_error(Mapper::NoTargetError)
      end

      it "should be initializable" do
        expect { Mapper.new(Object.new) }.not_to raise_error
      end
    end

    describe '#logger' do
      it 'should be delegated to target' do
        model = stub(:model,:logger => "Logger")
        mapper = Mapper.new(model)
        mapper.logger.should == "Logger"
      end
    end

    describe 'behavior' do
      let(:mapper){ TestMapper.new(target) }

      specify '#persisted? should delegate to target' do
        target.should_receive(:persisted?).and_return(:foo)
        mapper.persisted?.should == :foo
      end

      specify '#id is delegated to target' do
        target.should_receive(:id).and_return(5)
        mapper.id.should == 5
      end
    end

    describe "hosting" do
      let(:mapper){ TestMapper.new(target) }
      let(:mounted){ mapper.mounting(:mounted) }

      it "mounted mapper should be hosted" do
        mounted.should be_hosted
        mounted.host.should == mapper
      end

      it "not mounted should not be hosted" do
        mapper.should_not be_hosted
      end
    end

    describe "validations" do
      let(:mapper) { TestMapper.new(target) }

      it "should support ActiveModel::Validations class methods" do
        mapper.should_not be_valid
        mapper.errors[:attribute_1].should include("can't be blank")
      end

      it "should support ActiveModel::Validations custom validations" do
        mapper.should_not be_valid
        mapper.errors[:attribute_2].should include("is not foo")
      end
    end

    describe "callbacks" do
      let(:mapper) { TestMapper.new(target) }

      describe "save" do
        it "should run before callbacks" do
          mapper.save
          mapper.attribute_2.should == "save callback value"
        end
      end

      it "should run callbacks once" do
        mapper.should_receive(:before_save_callback).once.and_call_original
        mapper.save
      end

      describe "valid?" do
        it "should run before callbacks" do
          mapper.valid?
          mapper.attribute_2.should == "validate callback value"
        end
      end
    end

    describe "inheritance" do
      let(:inherited){ BaseMapper::Inherited }

      it "should obtain target class name from superclass" do
        inherited.target_class_name.should == 'BaseMapper::MapperTarget'
        inherited.default_target_class_name.should == 'Base'
      end

      it "should be able to use mappings and mounted from superclass" do
        inherited.build.read.keys.should =~ [:attr1, :attr2, :attribute_4]
      end

      it "should be able to use traits from superclass" do
        inherited.build(:a_trait).read.keys.should include :attr3
      end
    end

    describe 'suffix' do
      let(:mapper){ TestMapper.new(target){ mount :mounted, :suffix => 'foo', :target => lambda{ |_| mounted_target } } }

      it "should read suffixed value" do
        mounted_target.attribute_4 = 'bar'
        mapper.attribute_4_foo.should == 'bar'
      end

      it "should write suffixed value" do
        mapper.attribute_4_foo = 'baz'
        mounted_target.attribute_4.should == 'baz'
      end
    end

    describe Mapping do
      describe "mappings" do
        it "should contain hash of all mappings" do
          TestMapper.mappings.should have(3).mappings
        end

        it "should not include trait mappings" do
          mapper = TestMapper.new(target)
          mapper.should_not respond_to(:attribute_3)
        end
      end

      context "reading" do
        it "should test basic attribute mapping" do
          target.attribute_1 = "foo"

          mapper = TestMapper.new(target)
          mapper.attribute_1.should == "foo"
        end

        it "should test aliased attribute mapping" do
          target.attribute_1 = "foo"

          mapper = TestMapper.new(target)
          mapper.alternate_1.should == "foo"
        end

        it "should read attributes as named hash" do
          target.attribute_1 = "foo"
          target.attribute_2 = "bar"

          mapper = TestMapper.new(target)
          hash   = mapper.read
          hash[:attribute_1].should == "foo"
          hash[:alternate_1].should == "foo"
          hash[:attribute_2].should == "bar"
        end
      end

      context "writing" do
        it "should test basic attribute mapping" do
          mapper = TestMapper.new(target)
          mapper.attribute_1 = "foo"
          target.attribute_1.should == "foo"
        end

        it "should test aliased attribute mapping" do
          mapper = TestMapper.new(target)
          mapper.alternate_1 = "foo"
          target.attribute_1.should == "foo"
        end

        it "should write attributes given hash" do
          target.attribute_1 = "foo"
          target.attribute_2 = "bar"
          mapper = TestMapper.new(target)

          target.attribute_1.should == "foo"
          target.attribute_2.should == "bar"
        end
      end
    end

    describe Mapper::Mounting do
      describe "reader" do
        it "should map mounted attributes" do
          mounted_target.attribute_4 = "baz"
          mapper = TestMapper.new(target)
          mapper.attribute_4.should == "baz"
        end

        it "should include mappings of mounted mapper" do
          mounted_target.attribute_4 = "baz"
          mapper = TestMapper.new(target)
          hash = mapper.read
          hash[:attribute_4].should == "baz"
        end

        it "should read via brackets" do
          target.attribute_1 = "baz"
          mapper = TestMapper.new(target)
          mapper[:attribute_1].should == 'baz'
        end
      end

      describe "writer" do
        it "should map mounted attributes" do
          mapper = TestMapper.new(target)
          mapper.attribute_4 = "baz"
          mounted_target.attribute_4.should == "baz"
        end

        it "should include mappings of mounted mapper" do
          mapper = TestMapper.new(target)
          mapper.write(:attribute_4 => "baz")
          mounted_target.attribute_4.should == "baz"
        end

        it "should write via brackets" do
          mapper = TestMapper.new(target)
          mapper[:attribute_1] = "baz"
          target.attribute_1.should == "baz"
        end
      end

      describe "validations" do
        it "should include validations of mounted mapper" do
          mapper = TestMapper.new(target, :has_a_trait)
          mapper.should_not be_valid
          mapper.errors[:attribute_3].length.should == 1
        end
      end

      describe "accessing" do
        it "trait should have access to all mountings of owner" do
          mapper = TestMapper.new(target, :has_a_trait)
          trait = mapper.trait(:has_a_trait)
          trait.send(:all_mountings).should == mapper.send(:all_mountings)
        end

        it "trait should be able to receive methods of the owner" do
          mapper = TestMapper.new(target, :has_a_trait)
          trait  = mapper.trait(:has_a_trait)
          trait.a_method.should == 'a_method return value'
        end
      end

      describe "properties of the extension for mounted mapper" do
        let(:mapper){ TestMapper.new(target) }
        let(:mounted){ mapper.mounting(:mounted) }
        subject{ mounted.mountings.first }

        it{ should be_owned }
        it{ should be_hosted }
        it{ should be_extension }

        its(:owner){ should == mounted }
        its(:host){ should == mapper }
      end
    end

    describe Mapper::Skipping do
      let(:mapper){ TestMapper.new(target) }

      describe "skipped?" do
        it "should be true when skipped" do
          mapper.skip!

          mapper.should be_skipped
        end
      end

      describe "use!" do
        it "should revert skipping" do
          mapper.skip!
          mapper.use!

          mapper.should_not be_skipped
        end
      end

      describe "valid" do
        it "should return true when skipped" do
          mapper.skip!

          mapper.should be_valid
        end
      end

      describe "write" do
        it "should cause attribute to be unskipped" do
          mapper.skip!
          mapper.should be_skipped

          mapper.write(:attribute_1 => "foo")
          mapper.should_not be_skipped
        end
      end

      it 'should be possible to skip a trait' do
        mapper = TestMapper.new(target, :has_a_trait)
        mapper.skip_trait
        mapper.save
        mapper.attribute_3.should be_nil
      end

      describe Mapper::Skipping::ActiveRecord do
        describe '#skip!' do
          it "should mark new records for destruction if they are ActiveRecord Models" do
            target.should_receive(:is_a?).with(ActiveRecord::Base).and_return(true)
            target.should_receive(:new_record?).and_return(true)

            mapper.skip!

            target.instance_variable_get('@destroyed').should be_true
          end

          it "should reset changes of persisted models, and also waterfall to all_nested_mountings" do
            target.should_receive(:is_a?).with(ActiveRecord::Base).and_return(true)
            target.should_receive(:new_record?).and_return(false)
            target.should_receive(:reload)

            mapper.skip!
          end

          it "should return true when skipped" do
            mapper.skip!
            mapper.save.should be_true
          end
        end
      end
    end

    describe Mapper::Traits do
      let(:mapper) { TestMapper.new(target, :has_a_trait) }

      it "a trait should not be extension" do
        mapper.trait(:has_a_trait).should_not be_extension
      end

      it "should add mappings as readers" do
        target.attribute_3 = "foo"
        mapper.read.should have_key(:attribute_3)
      end

      it "should add mappings as writers" do
        mapper.write("attribute_3" => "foo")
        target.attribute_3.should == "foo"
      end

      it "should add validations" do
        mapper.should_not be_valid
        mapper.errors[:attribute_3].should include("can't be blank")
      end

      it "should add callbacks" do
        mapper.save
        mapper.attribute_3.should == "callback value"
      end

      context "extension trait" do
        let(:mapper) do
          TestMapper.new(target, :has_a_trait) do
            set_callback :validate, :before, :extension_callback

            def extension_callback
              self.attribute_4 = "extension value"
            end

            def writing_error=(value)
              raise ArgumentError, 'cannot be foo' if value == 'foo'
            rescue ArgumentError => e
              errors.preserve :writing_error, e.message
            end
          end
        end

        it "should call extension first" do
          mapper.extension.should_receive(:extension_callback).and_call_original
          mapper.write :attribute_4 => 'foo'
          mapper.should_not be_valid
          # attribute_4 should be overriden by trait which is processed after extension
          mapper.attribute_4.should == 'callback value'
        end

        it "should be able to handle save exception of traits" do
          expect{ mapper.apply(:writing_error => 'foo') }.not_to raise_error
          mapper.errors[:writing_error].should include 'cannot be foo'
        end
      end
    end
  end
end
