require 'spec_helper'

module FlatMap
  describe Mapping do
    let(:mapper)  { double('mapper', :suffixed? => false) }
    let(:mapping) { Mapping.new(mapper, :name, :attr) }

    describe "initialization" do
      it "should be initializable" do
        expect{ mapping }.not_to raise_error
      end

      it 'should delegate #read to reader' do
        expect(mapping.reader).to receive(:read)
        mapping.read
      end

      it 'should delegate #write to writer' do
        expect(mapping.writer).to receive(:write).with(:foo)
        mapping.write(:foo)
      end

      context "properties" do
        let(:mapper){ double('mapper', :suffixed? => true, :suffix => 'foo') }

        subject{ Mapping.new(mapper, :name, :attr, :multiparam => Date) }

        its(:mapper)           { is_expected.to eq mapper }
        its(:name)             { is_expected.to eq :name }
        its(:target_attribute) { is_expected.to eq :attr }
        its(:full_name)        { is_expected.to eq :name_foo }
        its(:multiparam)       { is_expected.to eq Date }
        its(:multiparam?)      { is_expected.to be true }
      end

      describe "#fetch_reader" do
        context 'default' do
          subject{ Mapping.new(mapper, :name, :attr) }

          its(:reader) { is_expected.to be_a(Mapping::Reader::Basic) }
        end

        context 'method' do
          subject{ Mapping.new(mapper, :name, :attr, :reader => :method_name) }

          its(:reader) { is_expected.to be_a(Mapping::Reader::Method) }
        end

        context 'proc' do
          subject{ Mapping.new(mapper, :name, :attr, :reader => lambda{ |t| t.foo }) }

          its(:reader) { is_expected.to be_a(Mapping::Reader::Proc) }
        end

        context 'formatted' do
          subject{ Mapping.new(mapper, :name, :attr, :format => :i18n_l) }

          its(:reader) { is_expected.to be_a(Mapping::Reader::Formatted) }
        end

        context 'blank' do
          subject{ Mapping.new(mapper, :name, :attr, :reader => false) }

          its(:reader) { is_expected.to be_nil }
        end
      end
    end

    describe "#fetch_writer" do
      context 'default' do
        subject{ Mapping.new(mapper, :name, :attr) }

        its(:writer) { is_expected.to be_a(Mapping::Writer::Basic) }
      end

      context 'method' do
        subject{ Mapping.new(mapper, :name, :attr, :writer => :method_name) }

        its(:writer) { is_expected.to be_a(Mapping::Writer::Method) }
      end

      context 'proc' do
        subject{ Mapping.new(mapper, :name, :attr, :writer => lambda{ |t| t.foo }) }

        its(:writer) { is_expected.to be_a(Mapping::Writer::Proc) }
      end

      context 'blank' do
        subject{ Mapping.new(mapper, :name, :attr, :writer => false) }

        its(:writer) { is_expected.to be_nil }
      end
    end

    describe "read_as_params" do
      it "should return mapping as key value pair" do
        stub_target
        expect(mapping.read_as_params).to eq({:name => "target_foo"})
      end
    end

    describe "write_from_params" do
      it "should set the correct value on the target from params" do
        stub_target('value')
        mapping.write_from_params(:name => "value")
      end

      it "should set no value on the target from params" do
        target = stub_target
        expect(target).not_to receive(:attr=)
        mapping.write_from_params(:not_mapping_name => "value")
        expect(target.attr).to eq 'target_foo'
      end
    end

    def stub_target(assignment = nil)
      target = double('target', :attr => 'target_foo')
      mapper.stub(:target).and_return(target)
      expect(target).to receive(:attr=).with(assignment) if assignment.present?
      target
    end
  end
end
