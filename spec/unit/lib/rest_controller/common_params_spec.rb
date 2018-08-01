require 'spec_helper'

module VCAP::CloudController::RestController
  RSpec.describe CommonParams do
    let(:logger) do
      double('Logger').as_null_object
    end

    subject(:common_params) do
      CommonParams.new(logger)
    end

    describe '#parse' do
      it 'treats inline-relations-depth as an Integer and symbolizes the key' do
        expect(common_params.parse({ 'inline-relations-depth' => '123' })).to eq({ inline_relations_depth: 123 })
      end

      it 'treats orphan-relations as an Integer and symbolizes the key' do
        expect(common_params.parse({ 'orphan-relations' => '1' })).to eq({ orphan_relations: 1 })
      end

      it 'treats exclude-relations as a String Array and symbolizes the key' do
        expect(common_params.parse({ 'exclude-relations' => 'name1,name2' })).to eq({ exclude_relations: ['name1', 'name2'] })
      end

      it 'treats include-relations as a String Array and symbolizes the key' do
        expect(common_params.parse({ 'include-relations' => 'name1,name2' })).to eq({ include_relations: ['name1', 'name2'] })
      end

      it 'treats page as an Integer and symbolizes the key' do
        expect(common_params.parse({ 'page' => '123' })).to eq({ page: 123 })
      end
      it 'treats results-per-page as an Integer and symbolizes the key' do
        expect(common_params.parse({ 'results-per-page' => '123' })).to eq({ results_per_page: 123 })
      end

      it 'treats q as a String and symbolizes the key' do
        expect(common_params.parse({ 'q' => '123' })).to eq({ q: '123' })
      end

      it 'treats order direction as a String and symbolizes the key' do
        expect(common_params.parse({ 'order-direction' => '123' })).to eq({ order_direction: '123' })
      end

      it 'discards other params' do
        expect(common_params.parse({ 'foo' => 'bar' })).to eq({})
      end

      it 'handles multiple q params' do
        expect(common_params.parse({ 'q' => 'a' }, 'q=a&q=b')).to eq({ q: ['a', 'b'] })
      end
    end
  end
end
