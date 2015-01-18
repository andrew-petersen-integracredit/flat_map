require 'spec_helper'

module FlatMap
  describe OpenMapper::Factory do
    let(:trait_class) { Class.new(FlatMap::OpenMapper) }
    let(:mapper)      { OpenMapper.build }

    let(:mount_factory) { OpenMapper::Factory.new(:spec_mount, :traits => :used_traits) }
    let(:trait_factory) { OpenMapper::Factory.new(trait_class, :trait_name => :a_trait) }
    let(:open_factory)  { OpenMapper::Factory.new(:some_mount, :open => true) }

    context 'when used for a trait' do
      subject{ trait_factory }

      it{ is_expected.to be_traited }
      its(:name)         { is_expected.to be_nil }
      its(:trait_name)   { is_expected.to eq :a_trait }
      its(:mapper_class) { is_expected.to eq trait_class }
    end

    context 'when used for a mounted mapper' do
      subject{ mount_factory }

      it{ is_expected.not_to be_traited }
      its(:name)       { is_expected.to eq :spec_mount }
      its(:trait_name) { is_expected.to be_nil }
      its(:traits)     { is_expected.to eq [:used_traits] }
    end

    context 'when used for an open mapper' do
      it "should have descendant of OpenMapper as mapper_class" do
        expect(open_factory.mapper_class.ancestors).to include(OpenMapper)
        expect(open_factory.mapper_class.name).to eq 'SomeMountMapper'
      end

      it "should create and instance of OpenMapper with open struct as a target" do
        mounted = open_factory.create(mapper)
        expect(mounted.target).to be_a(OpenStruct)
      end
    end

    describe 'behavior' do
      let(:target)       { mapper.target }
      let(:other_target) { Object.new }

      describe '#mapper_class for mounted mappers' do
        class ::SpecMountMapper < FlatMap::ModelMapper; end
        class OpenMapper::Factory::SpecMountMapper < FlatMap::OpenMapper; end

        it "should be able to fetch class name from name" do
          expect(mount_factory.mapper_class.ancestors).to include(::SpecMountMapper)
        end

        it "should be able to fetch class from mapper_class" do
          factory = OpenMapper::Factory.new(
                      :spec_mount,
                      :mapper_class => FlatMap::OpenMapper::Factory::SpecMountMapper
                    )
          expect(factory.mapper_class.ancestors).
            to include(::FlatMap::OpenMapper::Factory::SpecMountMapper)
        end

        it "should use options if specified" do
          factory = OpenMapper::Factory.new(
                      :spec_mount,
                      :mapper_class_name => 'FlatMap::OpenMapper::Factory::SpecMountMapper'
                    )
          expect(factory.mapper_class.ancestors).
            to include(::FlatMap::OpenMapper::Factory::SpecMountMapper)
        end
      end

      describe '#fetch_target_from' do
        it "should return owner's target for traited factory" do
          expect(trait_factory.fetch_target_from(mapper)).to eq target
        end

        context 'explicit target' do
          it "should use explicitly specified if applicable" do
            factory = OpenMapper::Factory.new(:spec_mount, :target => other_target)
            expect(factory.fetch_target_from(mapper)).to eq other_target
          end

          it "should call Proc and pass owner target to it if Proc is specified as :target" do
            factory = OpenMapper::Factory.new(:spec_mount, :target => lambda{ |obj| obj.foo })
            expect(target).to receive(:foo).and_return(other_target)
            expect(factory.fetch_target_from(mapper)).to eq other_target
          end

          it "should call a method if Symbol is used" do
            factory = OpenMapper::Factory.new(:spec_mount, :target => :foo)
            expect(mapper).to receive(:foo).and_return(other_target)
            expect(factory.fetch_target_from(mapper)).to eq other_target
          end
        end

        context 'target from association' do
          before do
            target.stub(:is_a?).and_call_original
            target.stub(:is_a?).with(ActiveRecord::Base).and_return(true)
          end

          let(:has_one_current_reflection) {
            double('reflection', :macro => :has_one, :options => {:is_current => true})
          }
          let(:has_one_reflection) {
            double('reflection', :macro => :has_one, :options => {})
          }
          let(:belongs_to_reflection) {
            double('reflection', :macro => :belongs_to)
          }
          let(:has_many_reflection) {
            double('reflection', :macro => :has_many, :name => :spec_mounts)
          }

          it "should refer to effective name for has_one_current association" do
            # Note: has_one_current is not part of Rails
            expect(mount_factory).to receive(:reflection_from_target).
                          with(target).
                          and_return(has_one_current_reflection)
            expect(target).to receive(:effective_spec_mount).and_return(other_target)
            expect(mount_factory.fetch_target_from(mapper)).to eq other_target
          end

          it "should refer to existing association object if possible, " \
             "and build it if it is absent for :has_one" do
            expect(mount_factory).to receive(:reflection_from_target).
                          with(target).
                          and_return(has_one_reflection)
            expect(target).to receive(:spec_mount).and_return(nil)
            expect(target).to receive(:build_spec_mount).and_return(other_target)
            expect(mount_factory.fetch_target_from(mapper)).to eq other_target
          end

          it "should refer to existing association object if possible, " \
             "and build it if it is absent for :belongs_to" do
            expect(mount_factory).to receive(:reflection_from_target).
                          with(target).
                          and_return(belongs_to_reflection)
            expect(target).to receive(:spec_mount).and_return(nil)
            expect(target).to receive(:build_spec_mount).and_return(other_target)
            expect(mount_factory.fetch_target_from(mapper)).to eq other_target
          end

          it "should always build a new record for :has_many association" do
            expect(mount_factory).to receive(:reflection_from_target).
                          with(target).
                          and_return(has_many_reflection)
            expect(target).to receive(:association).with(:spec_mounts)
            target.stub_chain(:association, :build).and_return(other_target)
            expect(mount_factory.fetch_target_from(mapper)).to eq other_target
          end

          describe 'reflection_from_target' do
            before{ target.stub(:is_a?).with(ActiveRecord::Base).and_return(true) }

            it 'should first refer to singular association' do
              target.stub_chain(:class, :reflect_on_association).
                     with(:spec_mount).
                     and_return(has_one_reflection)
              expect(mount_factory.reflection_from_target(target)).to eq has_one_reflection
            end

            it 'should use collection association if singular does not exist' do
              target.stub_chain(:class, :reflect_on_association).
                     with(:spec_mount).
                     and_return(nil)
              target.stub_chain(:class, :reflect_on_association).
                     with(:spec_mounts).
                     and_return(has_many_reflection)
              expect(mount_factory.reflection_from_target(target)).to eq has_many_reflection
            end
          end
        end

        context 'target from name' do
          it 'should simply send method to owner target' do
            expect(target).to receive(:spec_mount).and_return(other_target)
            expect(mount_factory.fetch_target_from(mapper)).to eq other_target
          end
        end
      end

      describe '#create' do
        specify 'traited factory should create an owned mapper' do
          new_one = trait_factory.create(mapper)
          expect(new_one.owner).to eq mapper
        end

        context 'mounted mapper' do
          let(:mount_class){ Class.new(Mapper) }
          let(:factory){ mount_factory }

          before do
            factory.stub(:mapper_class).and_return(mount_class)
            factory.stub(:fetch_target_from).and_return(other_target)
          end

          it 'should combine traits' do
            expect(mount_class).to receive(:new).
                        with(other_target, :used_traits, :another_trait).
                        and_call_original
            factory.create(mapper, :another_trait)
          end

          it 'should properly set properties' do
            new_one = factory.create(mapper)
            expect(new_one.host      ).to eq mapper
            expect(new_one.name      ).to eq :spec_mount
            expect(new_one.save_order).to eq :after
            expect(new_one.suffix    ).to be_nil
          end

          context 'when suffix is defined' do
            let(:factory){ OpenMapper::Factory.new(:spec_mount, :suffix => :foo) }

            it "should adjust properties with suffix" do
              new_one = factory.create(mapper)
              expect(new_one.name  ).to eq :spec_mount_foo
              expect(new_one.suffix).to eq :foo
            end
          end

          context 'when extension is present' do
            let(:extension){ Proc.new{} }
            let(:factory){ OpenMapper::Factory.new(:spec_mount, &extension) }

            it "should pass it to mapper initialization" do
              expect(mount_class).to receive(:new).
                          with(other_target, &extension).
                          and_call_original
              new_one = factory.create(mapper)
            end
          end

          describe 'save order' do
            before do
              mapper.stub(:is_a?).and_call_original
              mapper.stub(:is_a?).with(ModelMapper).and_return(true)
            end

            it 'should be :before for belongs_to association' do
              factory.stub(:reflection_from_target).
                      and_return(double('reflection', :macro => :belongs_to))
              expect(factory.fetch_save_order(mapper)).to eq :before
            end

            it 'should be :after for other cases' do
              factory.stub(:reflection_from_target).
                      and_return(double('reflection', :macro => :has_one))
              expect(factory.fetch_save_order(mapper)).to eq :after
            end

            context 'when explicitly set' do
              let(:factory){ OpenMapper::Factory.new(:spec_mount, :save => :before) }

              it 'should fetch from options, if possible' do
                new_one = factory.create(mapper)
                expect(new_one.save_order).to eq :before
              end
            end
          end
        end
      end

      describe '#required_for_any_trait?' do
        let(:mapper_class) do
          Class.new(FlatMap::Mapper) do
            trait(:trait_a) {
              trait(:trait_b) {
                trait(:trait_c) {
            } } }
          end
        end
        let(:factory_for_b){ mapper_class.mountings.first.mapper_class.mountings.first }

        it "should be required for nested trait" do
          expect(factory_for_b.required_for_any_trait?([:trait_c])).to be true
        end

        it "should not be required for top trait" do
          expect(factory_for_b.required_for_any_trait?([:trait_a])).to be false
        end
      end
    end
  end
end
