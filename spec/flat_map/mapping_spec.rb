require 'spec_helper'

module FlatMap
  describe Mapping do
    let(:target_class) { Struct.new(:target_attribute) }
    let(:target) { target_class.new }
    let(:mapper) { Mapper.new(target) }

    describe "initialization" do
      it "should be initializable" do
        expect { Mapping.new(mapper, "mapping_name", "target_attribute") }.not_to raise_error
      end
    end

    describe "write_from_params" do
      it "should set the correct value on the target from params" do
        mapping = Mapping.new(mapper, "mapping_name", "target_attribute")
        mapping.write_from_params("mapping_name" => "value")
        target.target_attribute.should == "value"
      end

      it "should set no value on the target from params" do
        mapping = Mapping.new(mapper, "mapping_name", "target_attribute")
        mapping.write_from_params("not_mapping_name" => "value")
        target.target_attribute.should be_nil
      end
    end

    describe "read_as_params" do
      it "should return mapping as key value pair" do
        target.target_attribute = "value"

        mapping = Mapping.new(mapper, "mapping_name", "target_attribute")
        mapping.read_as_params.should == {"mapping_name" => "value"}
      end
    end

    describe "multiparam?" do
      it "should be true if given during initialization" do
        mapping = Mapping.new(mapper, "mapping_name", "target_attribute", :multiparam => true)
        mapping.should be_multiparam
      end

      it "should be false if not given during initialization" do
        mapping = Mapping.new(mapper, "mapping_name", "target_attribute")
        mapping.should_not be_multiparam
      end
    end

    context "readers" do
      let(:value) { "value" }

      context "formatted" do
        describe "i18n_1" do
          it "should use I18n_l to format value" do
            formatted_value = "formatted value"

            target.target_attribute = value
            I18n.should_receive(:l).with(value).and_return(formatted_value)

            mapping = Mapping.new(mapper, "mapping_name", "target_attribute", :format => :i18n_l)
            mapping.read.should == formatted_value
          end
        end

        describe "enum" do
          let(:enum)    { Object.new }
          let(:mapping) { Mapping.new(mapper, "mapping_name", "target_attribute", :format => :enum) }

          before { target.target_attribute = enum }

          it "should use the name property of the target object for value" do
            enum.should_receive(:name).and_return(value)
            mapping.read.should == value
          end

          it "should be able to use the desired method to get enum's property" do
            enum.should_receive(:description).and_return(value)
            mapping.read(:description).should == value
          end
        end
      end

      describe "basic" do
        it "should access named property of target" do
          target.target_attribute = value
          mapping = Mapping.new(mapper, "mapping_name", "target_attribute")
          mapping.read.should == value
        end
      end

      describe "method" do
        it "should access value of method on mapper with mapping as an argument" do
          mapping = Mapping.new(mapper, "mapping_name", "target_attribute", :reader => :target_method)
          mapper.should_receive(:target_method).with(mapping).and_return(value)

          mapping.read.should == value
        end
      end

      describe "proc" do
        it "should execute proc for value with mapping target as argument" do
          l = lambda { |given_target| given_target == target ? value : nil }
          mapping = Mapping.new(mapper, "mapping_name", "target_attribute", :reader => l)

          mapping.read.should == value
        end
      end
    end

    context "writers" do
      let(:value) { "value" }

        it "should set named property of target" do
          mapping = Mapping.new(mapper, "mapping_name", "target_attribute")
          mapping.write(value)
          target.target_attribute.should == value
        end

      describe "method" do
        it "should call a method on the mapper with the mapping and value as the arguments" do
          mapping = Mapping.new(mapper, "mapping_name", "target_attribute", :writer => :target_method)
          mapper.should_receive(:target_method).with(mapping, value).and_return(true)

          mapping.write(value).should be_true
        end
      end

      describe "proc" do
        it "should call given lambda with target and value as the arguments" do
          l = lambda { |given_target, given_value| given_target == target && given_value == value ? true : false }
          mapping = Mapping.new(mapper, "mapping_name", "target_attribute", :writer => l)

          mapping.write(value).should be_true
        end
      end
    end
  end
end
