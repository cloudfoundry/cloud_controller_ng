require 'spec_helper'

module VCAP::CloudController
  RSpec.describe LabelSelectorParser do
    subject(:label_selector_parser) { LabelSelectorParser }

    describe '.add_selector_queries' do
      let!(:app1) { AppModel.make }
      let!(:app1_label) { AppLabelModel.make(resource_guid: app1.guid, key_name: 'foo', value: 'bar') }

      let!(:app2) { AppModel.make }
      let!(:app2_label) { AppLabelModel.make(resource_guid: app2.guid, key_name: 'foo', value: 'funky') }

      let!(:app3) { AppModel.make }
      let!(:app3_label) { AppLabelModel.make(resource_guid: app3.guid, key_name: 'foo', value: 'town') }
      let!(:app3_exclusive_label) { AppLabelModel.make(resource_guid: app3.guid, key_name: 'easter', value: 'bunny') }

      describe 'in set requirements' do
        context 'with a single value' do
          it 'returns the models that satisfy the requirements' do
            dataset = subject.add_selector_queries(
              label_klass: AppLabelModel,
              resource_dataset: AppModel.dataset,
              label_selector: 'foo in (funky)'
            )

            expect(dataset.map(&:guid)).to contain_exactly(app2.guid)
          end
        end

        context 'with multiple values' do
          it 'returns the models that satisfy the requirements' do
            dataset = subject.add_selector_queries(
              label_klass: AppLabelModel,
              resource_dataset: AppModel.dataset,
              label_selector: 'foo in (funky,town)'
            )

            expect(dataset.map(&:guid)).to contain_exactly(app2.guid, app3.guid)
          end
        end
      end

      describe 'notin set requirements' do
        context 'with a single value' do
          it 'returns the models that satisfy the requirements' do
            dataset = subject.add_selector_queries(
              label_klass: AppLabelModel,
              resource_dataset: AppModel.dataset,
              label_selector: 'foo notin (funky)'
            )

            expect(dataset.map(&:guid)).to contain_exactly(app1.guid, app3.guid)
          end
        end

        context 'with multiple values' do
          it 'returns the models that satisfy the requirements' do
            dataset = subject.add_selector_queries(
              label_klass: AppLabelModel,
              resource_dataset: AppModel.dataset,
              label_selector: 'foo notin (funky,town)'
            )

            expect(dataset.map(&:guid)).to contain_exactly(app1.guid)
          end
        end
      end

      describe 'equality requirements' do
        it 'returns the models that satisfy the "=" requirements' do
          dataset = subject.add_selector_queries(
            label_klass: AppLabelModel,
            resource_dataset: AppModel.dataset,
            label_selector: 'foo=funky'
          )

          expect(dataset.map(&:guid)).to contain_exactly(app2.guid)
        end

        it 'returns the models that satisfy the "==" requirements' do
          dataset = subject.add_selector_queries(
            label_klass: AppLabelModel,
            resource_dataset: AppModel.dataset,
            label_selector: 'foo==funky'
          )

          expect(dataset.map(&:guid)).to contain_exactly(app2.guid)
        end

        it 'returns the models that satisfy the "!=" requirements' do
          dataset = subject.add_selector_queries(
            label_klass: AppLabelModel,
            resource_dataset: AppModel.dataset,
            label_selector: 'foo!=funky'
          )

          expect(dataset.map(&:guid)).to contain_exactly(app1.guid, app3.guid)
        end
      end

      describe 'existence requirements' do
        it 'returns the models that satisfy the existence requirements' do
          dataset = subject.add_selector_queries(
            label_klass: AppLabelModel,
            resource_dataset: AppModel.dataset,
            label_selector: 'easter'
          )

          expect(dataset.map(&:guid)).to contain_exactly(app3.guid)
        end

        it 'returns the models that satisfy the non-existence requirements' do
          dataset = subject.add_selector_queries(
            label_klass: AppLabelModel,
            resource_dataset: AppModel.dataset,
            label_selector: '!easter'
          )

          expect(dataset.map(&:guid)).to contain_exactly(app1.guid, app2.guid)
        end
      end

      context 'with multiple queries' do
        it 'returns the models that satisfy the requirements' do
          dataset = subject.add_selector_queries(
            label_klass: AppLabelModel,
            resource_dataset: AppModel.dataset,
            label_selector: 'foo in (funky,town),foo notin (bar)'
          )

          expect(dataset.map(&:guid)).to contain_exactly(app2.guid, app3.guid)
        end

        it 'returns the models that satisfy the requirements' do
          dataset = subject.add_selector_queries(
            label_klass: AppLabelModel,
            resource_dataset: AppModel.dataset,
            label_selector: 'foo!=bar,foo!=town'
          )

          expect(dataset.map(&:guid)).to contain_exactly(app2.guid)
        end

        it 'returns an empty list if the combined requirements do not match any labels' do
          dataset = subject.add_selector_queries(
            label_klass: AppLabelModel,
            resource_dataset: AppModel.dataset,
            label_selector: 'foo==bar,foo=town'
          )

          expect(dataset.count).to eq(0)
        end
      end
    end
  end
end
