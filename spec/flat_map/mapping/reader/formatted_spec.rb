require 'spec_helper'

describe FlatMap::Mapping::Reader::Formatted do
  let(:value){ 'fOoBaR' }
  let(:target){ double('target', :attr => value) }
  let(:mapping){ double('mapping', :target => target, :target_attribute => :attr) }

  context 'generic behavior' do
    let(:reader){ described_class.new(mapping, :spec_format).extend(spec_extension) }
    let(:spec_extension) do
      Module.new do
        def spec_format(value, transformation = :upcase)
          case transformation
          when :upcase then value.upcase
          when :downcase then value.downcase
          else value
          end
        end
      end
    end

    specify "#read should use formatting method for fetching a value" do
      expect(reader.read           ).to eq 'FOOBAR'
      expect(reader.read(:downcase)).to eq 'foobar'
      expect(reader.read(:unknown )).to eq 'fOoBaR'
    end
  end

  context 'default formats' do
    describe "i18n_1" do
      let(:reader){ described_class.new(mapping, :i18n_l) }

      it "should use I18n_l to format value" do
        formatted_value = "le FooBar"
        expect(I18n).to receive(:l).with(value).and_return(formatted_value)

        expect(reader.read).to eq formatted_value
      end
    end

    describe "enum" do
      unless defined? PowerEnum
        module ::PowerEnum; end
        load 'flat_map/mapping/reader/formatted/formats.rb'
      end

      let(:enum){ Object.new }
      let(:target){ double('target', :attr => enum) }
      let(:reader){ described_class.new(mapping, :enum) }

      it "should use the name property of the target object for value" do
        expect(enum).to receive(:name).and_return(value)
        expect(reader.read).to eq value
      end

      it "should be able to use the desired method to get enum's property" do
        expect(enum).to receive(:description).and_return(value)
        expect(reader.read(:description)).to eq value
      end
    end
  end
end
