require 'spec_helper'

module FlatMap
  module ModelMethodsSpec
    class TargetClass < Struct.new(:attr_a, :attr_b)
    end

    class OtherTargetClass < Struct.new(:attr_c, :attr_d)
    end

    module ArbitraryModule
    end

    class TargetClassMapper < Mapper
      include ArbitraryModule

      map :attr_a
      map :dob => :attr_b, :multiparam => Date
    end

    class InheritedClassMapper < TargetClassMapper
    end

    class ExplicitNameMapper < Mapper
      self.target_class_name = 'FlatMap::ModelMethodsSpec::OtherTargetClass'
    end
  end

  describe 'Working with Target' do
    describe '#target_class' do
      it 'should detect target_class from mapper class name' do
        expect(ModelMethodsSpec::TargetClassMapper.target_class).to eq ModelMethodsSpec::TargetClass
      end

      it 'should detect target_class from nearest ancestor when inherited' do
        expect(ModelMethodsSpec::InheritedClassMapper.target_class.ancestors).
          to include ModelMethodsSpec::TargetClass
      end

      it 'should use explicit class name if specified' do
        expect(ModelMethodsSpec::ExplicitNameMapper.target_class.ancestors).
          to include ModelMethodsSpec::OtherTargetClass
      end
    end

    describe '.build' do
      it 'should use target class to build a new object for mapper' do
        expect(ModelMethodsSpec::TargetClassMapper).to receive(:new).
          with(kind_of(ModelMethodsSpec::TargetClass), :used_trait)
        ModelMethodsSpec::TargetClassMapper.build(:used_trait)
      end
    end

    describe '.find' do
      let(:target){ ModelMethodsSpec::TargetClass.new('a', 'b') }

      context "with preload" do
        it 'should preload tables and find object for mapper' do
          expect(ModelMethodsSpec::TargetClassMapper).to receive_message_chain(:relation, :find).
            with([:used_trait]).with(1).and_return(target)
          expect(ModelMethodsSpec::TargetClassMapper).to receive(:new).with(target, :used_trait)
          ModelMethodsSpec::TargetClassMapper.find(1, :used_trait, preload: true)
        end
      end

      context "without preload" do
        it 'should delegate to target class to find object for mapper' do
          expect(ModelMethodsSpec::TargetClass).to receive(:find).with(1).and_return(target)
          expect(ModelMethodsSpec::TargetClassMapper).to receive(:new).with(target, :used_trait)
          ModelMethodsSpec::TargetClassMapper.find(1, :used_trait)
        end
      end
    end

    describe 'behavior' do
      let(:target){ ModelMethodsSpec::TargetClass.new('a', 'b') }
      let(:mapper){ ModelMethodsSpec::TargetClassMapper.new(target){} }

      specify '#model_name' do
        expect(mapper.model_name).to respond_to :human
      end

      specify '#to_key should delegate to target' do
        expect(target).to receive(:to_key).and_return(1)
        expect(mapper.to_key).to eq 1
      end

      specify '#persisted? when target does not respond to :persised?' do
        expect(mapper).not_to be_persisted
      end

      specify '#persisted? when target responds to :persisted?' do
        expect(target).to receive(:persisted?).and_return(true)
        expect(mapper).to be_persisted
      end

      specify '#id when target does not respond to :id' do
        expect(mapper.id).to be_nil
      end

      specify '#id when target responds to :id' do
        expect(target).to receive(:id).and_return(1)
        expect(mapper.id).to eq 1
      end

      describe '#write with multiparams' do
        let(:params) {{
          'attr_a'     => 'A',
          'dob(0i)' => '1999',
          'dob(1i)' => '01',
          'dob(2i)' => '02'
        }}

        it 'should assign values properly' do
          mapper.write(params)
          expect(target.attr_a).to eq 'A'
          expect(target.attr_b).to eq Date.new(1999, 1, 2)
        end
      end

      describe '#save_target' do
        it 'should return true for owned mappers' do
          expect(mapper.extension.save_target).to be true
        end

        it 'should return true if target does not respond to #save' do
          expect(mapper.save_target).to be true
        end

        it 'should save with no validation if target responds to #save' do
          expect(target).to receive(:save).with(:validate => false).and_return(true)
          expect(mapper.save_target).to be true
        end
      end

      describe '#apply' do
        let(:params){{ :attr_a => 'A' }}

        it 'should write params first' do
          expect(mapper).to receive(:write).with(params)
          expect(ActiveRecord::Base).to receive(:transaction).and_yield
          mapper.apply(params)
        end

        it 'should not save if not valid' do
          expect(mapper).to     receive(:valid?).and_return(false)
          expect(mapper).not_to receive(:save)
          mapper.apply(params)
        end

        it 'should save if valid' do
          expect(mapper).to receive(:valid?).and_return(true)
          expect(ActiveRecord::Base).to receive(:transaction).and_yield
          expect(mapper).to receive(:save)
          mapper.apply(params)
        end
      end

      specify '#shallow_save saves target in a save callbacks' do
        expect(mapper).to receive(:run_callbacks).with(:save).and_yield
        expect(mapper).to receive(:save_target)
        mapper.shallow_save
      end
    end
  end
end
