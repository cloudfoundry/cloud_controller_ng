require 'spec_helper'

module VCAP::CloudController
  RSpec.describe LabelSelectorParser do
    subject(:label_selector_parser) { LabelSelectorParser }

    describe '.add_selector_queries' do
      let!(:app1) { AppModel.make }
      let!(:app2) { AppModel.make }
      let!(:app3) { AppModel.make }
      let!(:app1_label) { AppLabelModel.make(app_guid: app1.guid, key_name: 'foo', value: 'bar') }
      let!(:app2_label) { AppLabelModel.make(app_guid: app2.guid, key_name: 'foo', value: 'funky') }
      let!(:app3_label) { AppLabelModel.make(app_guid: app3.guid, key_name: 'foo', value: 'town') }
      describe 'in set requirements' do
        context 'with a single value' do
          it 'returns the models that satisfy the requirements' do
            dataset = subject.add_selector_queries(AppLabelModel, AppModel.dataset, 'foo in (funky)')

            expect(dataset.map(&:guid)).to contain_exactly(app2.guid)
          end
        end

        context 'with multiple values' do
          it 'returns the models that satisfy the requirements' do
            dataset = subject.add_selector_queries(AppLabelModel, AppModel.dataset, 'foo in (funky,town)')

            expect(dataset.map(&:guid)).to contain_exactly(app2.guid, app3.guid)
          end
        end
      end

      describe 'notin set requirements' do
        context 'with a single value' do
          it 'returns the models that satisfy the requirements' do
            dataset = subject.add_selector_queries(AppLabelModel, AppModel.dataset, 'foo notin (funky)')

            expect(dataset.map(&:guid)).to contain_exactly(app1.guid, app3.guid)
          end
        end

        context 'with multiple values' do
          it 'returns the models that satisfy the requirements' do
            dataset = subject.add_selector_queries(AppLabelModel, AppModel.dataset, 'foo notin (funky,town)')

            expect(dataset.map(&:guid)).to contain_exactly(app1.guid)
          end
        end
      end

      context 'with multiple queries' do
        it 'returns the models that satisfy the requirements' do
          dataset = subject.add_selector_queries(AppLabelModel, AppModel.dataset, 'foo in (funky,town),foo notin (bar)')

          expect(dataset.map(&:guid)).to contain_exactly(app2.guid, app3.guid)
        end
      end
    end
  end
end
