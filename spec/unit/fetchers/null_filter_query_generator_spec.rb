require 'spec_helper'

module VCAP::CloudController
  RSpec.describe NullFilterQueryGenerator do
    subject(:filter_generator) { NullFilterQueryGenerator }

    describe '.add_filter' do
      let!(:stack1) { create(:stack) }
      let!(:stack2) { create(:stack) }
      let!(:stack3) { create(:stack) }

      let!(:buildpack_with_stack1) { create(:buildpack, stack: stack1.name) }
      let!(:buildpack_with_stack2) { create(:buildpack, stack: stack2.name) }
      let!(:buildpack_with_stack3) { create(:buildpack, stack: stack3.name) }
      let!(:buildpack_with_null_stack) { create(:buildpack, stack: nil) }

      context 'when no empty values included in filter' do
        let(:filter_values) { [stack1.name, stack2.name] }

        it 'returns the resources with the given values' do
          dataset = subject.add_filter(Buildpack.dataset, :stack, filter_values)

          expect(dataset).to contain_exactly(buildpack_with_stack1, buildpack_with_stack2)
        end
      end

      context 'when both empty and non-empty values included in filter' do
        let(:filter_values) { [stack1.name, ''] }

        it 'returns the resources with the given values or null' do
          dataset = subject.add_filter(Buildpack.dataset, :stack, filter_values)

          expect(dataset).to contain_exactly(buildpack_with_stack1, buildpack_with_null_stack)
        end
      end

      context 'when only empty values included in filter' do
        let(:filter_values) { [''] }

        it 'returns the resources with value null' do
          dataset = subject.add_filter(Buildpack.dataset, :stack, filter_values)

          expect(dataset).to contain_exactly(buildpack_with_null_stack)
        end
      end
    end
  end
end
