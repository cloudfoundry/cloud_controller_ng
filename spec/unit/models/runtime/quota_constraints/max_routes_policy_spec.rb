require 'spec_helper'

describe MaxRoutesPolicy do
  let(:quota_definition) { double(:quota_definition, total_routes: 4) }
  let(:route_counter) { double(:route_counter, count: 0) }

  subject { MaxRoutesPolicy.new(quota_definition, route_counter) }

  describe '#allow_more_routes?' do
    it 'is false when exceeding the total allowed routes' do
      result = subject.allow_more_routes?(5)
      expect(result).to be_falsy
    end

    it 'is true when equivalent to the total allowed routes' do
      result = subject.allow_more_routes?(4)
      expect(result).to be_truthy
    end

    it 'is true when not exceeding the total allowed routes' do
      result = subject.allow_more_routes?(1)
      expect(result).to be_truthy
    end

    context 'when an unlimited amount of routes are available' do
      let(:quota_definition) { double(:quota_definition, total_routes: -1) }

      it 'is always true' do
        result = subject.allow_more_routes?(100_000_000)
        expect(result).to be_truthy
      end
    end
  end
end
