require 'spec_helper'

describe FlatMap::OpenMapper do
  describe 'initialization' do
    context 'no target passed' do
      it 'raises exception' do
        expect { described_class.new(nil) }.
          to raise_error(FlatMap::OpenMapper::NoTargetError)
      end
    end

    context 'target.present? return false' do
      it 'does not raises' do
        target = double(:empty_association_proxy, :present? => false)
        described_class.new(target)
      end
    end
  end
end
