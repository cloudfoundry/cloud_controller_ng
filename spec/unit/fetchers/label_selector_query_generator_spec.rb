require 'spec_helper'

module VCAP::CloudController
  RSpec.describe LabelSelectorQueryGenerator do
    subject(:label_selector_parser) { LabelSelectorQueryGenerator }

    describe '.add_selector_queries' do
      let!(:app1) { AppModel.make }
      let!(:app1_label) { AppLabelModel.make(resource_guid: app1.guid, key_name: 'foo', value: 'bar') }

      let!(:app2) { AppModel.make }
      let!(:app2_label) { AppLabelModel.make(resource_guid: app2.guid, key_name: 'foo', value: 'funky') }

      let!(:app3) { AppModel.make }
      let!(:app3_label) { AppLabelModel.make(resource_guid: app3.guid, key_name: 'foo', value: 'town') }
      let!(:app3_exclusive_label) { AppLabelModel.make(resource_guid: app3.guid, key_name: 'easter', value: 'bunny') }

      let(:requirements) do
        [VCAP::CloudController::LabelSelectorRequirement.new(key: 'foo', operator: operator, values: values)]
      end

      describe 'in set requirements' do
        let(:operator) { :in }

        context 'with a single value' do
          let(:values) { 'funky' }

          it 'returns the models that satisfy the requirements' do
            dataset = subject.add_selector_queries(
              label_klass: AppLabelModel,
              resource_dataset: AppModel.dataset,
              requirements: requirements,
              resource_klass: AppModel,
            )

            expect(dataset.map(&:guid)).to contain_exactly(app2.guid)
          end
        end

        context 'with multiple values' do
          let(:values) { 'funky,town' }

          it 'returns the models that satisfy the requirements' do
            dataset = subject.add_selector_queries(
              label_klass: AppLabelModel,
              resource_dataset: AppModel.dataset,
              requirements: requirements,
              resource_klass: AppModel,
            )

            expect(dataset.map(&:guid)).to contain_exactly(app2.guid, app3.guid)
          end
        end

        context 'with association in dataset query' do
          let(:values) { 'funky,town' }

          # Currently, we can not rely on Sequel's association-based query generation
          # with the way the LabelSelectorQueryGenerator relies on joins and `qualify`.
          skip 'returns the models that satisfy the requirements' do
            dataset = subject.add_selector_queries(
              label_klass: AppLabelModel,
              resource_dataset: AppModel.dataset.where(space: Space.dataset),
              requirements: requirements,
              resource_klass: AppModel,
            )

            expect(dataset.map(&:guid)).to contain_exactly(app2.guid, app3.guid)
          end
        end

        context 'with foreign key reference in dataset query' do
          let(:requirements) do
            [
              VCAP::CloudController::LabelSelectorRequirement.new(key: 'easter', operator: operator, values: 'bunny'),
              VCAP::CloudController::LabelSelectorRequirement.new(key: 'foo', operator: operator, values: 'town')
            ]
          end

          it 'returns the models that satisfy the requirements' do
            dataset = subject.add_selector_queries(
              label_klass: AppLabelModel,
              resource_dataset: AppModel.dataset.where(space_guid: Space.dataset.map(&:guid)),
              requirements: requirements,
              resource_klass: AppModel,
            )

            expect(dataset.map(&:guid)).to contain_exactly(app3.guid)
          end
        end
      end

      describe 'notin set requirements' do
        let(:operator) { :notin }

        context 'with a single value' do
          let(:values) { 'funky' }

          it 'returns the models that satisfy the requirements' do
            dataset = subject.add_selector_queries(
              label_klass: AppLabelModel,
              resource_dataset: AppModel.dataset,
              requirements: requirements,
              resource_klass: AppModel,
            )

            expect(dataset.map(&:guid)).to contain_exactly(app1.guid, app3.guid)
          end
        end

        context 'with multiple values' do
          let(:values) { 'funky,town' }

          it 'returns the models that satisfy the requirements' do
            dataset = subject.add_selector_queries(
              label_klass: AppLabelModel,
              resource_dataset: AppModel.dataset,
              requirements: requirements,
              resource_klass: AppModel,
            )

            expect(dataset.map(&:guid)).to contain_exactly(app1.guid)
          end
        end

        context 'with association in dataset query' do
          let(:values) { 'funky,town' }

          skip 'returns the models that satisfy the requirements' do
            dataset = subject.add_selector_queries(
              label_klass: AppLabelModel,
              resource_dataset: AppModel.dataset.where(space: Space.dataset),
              requirements: requirements,
              resource_klass: AppModel,
            )

            expect(dataset.map(&:guid)).to contain_exactly(app1.guid)
          end
        end
      end

      describe 'equality requirements' do
        let(:operator) { :equal }
        let(:values) { 'funky' }

        it 'returns the models that satisfy the "=" requirements' do
          dataset = subject.add_selector_queries(
            label_klass: AppLabelModel,
            resource_dataset: AppModel.dataset,
            requirements: requirements,
            resource_klass: AppModel,
          )

          expect(dataset.map(&:guid)).to contain_exactly(app2.guid)
        end

        context 'when it is not_equal' do
          let(:operator) { :not_equal }
          it 'returns the models that satisfy the "!=" requirements' do
            dataset = subject.add_selector_queries(
              label_klass: AppLabelModel,
              resource_dataset: AppModel.dataset,
              requirements: requirements,
              resource_klass: AppModel,
            )

            expect(dataset.map(&:guid)).to contain_exactly(app1.guid, app3.guid)
          end
        end

        context 'with association in dataset query' do
          let(:values) { 'funky' }

          skip 'returns the models that satisfy the requirements' do
            dataset = subject.add_selector_queries(
              label_klass: AppLabelModel,
              resource_dataset: AppModel.dataset.where(space: Space.dataset),
              requirements: requirements,
              resource_klass: AppModel,
            )

            expect(dataset.map(&:guid)).to contain_exactly(app2.guid)
          end
        end
      end

      describe 'existence requirements' do
        it 'returns the models that satisfy the existence requirements' do
          dataset = subject.add_selector_queries(
            label_klass: AppLabelModel,
            resource_dataset: AppModel.dataset.where(space_guid: Space.dataset.select(:guid)),
            requirements: [
              VCAP::CloudController::LabelSelectorRequirement.new(key: 'easter', operator: :exists, values: ''),
              VCAP::CloudController::LabelSelectorRequirement.new(key: 'foo', operator: :exists, values: '')
            ],
            resource_klass: AppModel,
          )

          expect(dataset.map(&:guid)).to contain_exactly(app3.guid)
        end

        it 'returns the models that satisfy the non-existence requirements' do
          dataset = subject.add_selector_queries(
            label_klass: AppLabelModel,
            resource_dataset: AppModel.dataset,
            requirements: [VCAP::CloudController::LabelSelectorRequirement.new(key: 'easter', operator: :not_exists, values: '')],
            resource_klass: AppModel,
          )

          expect(dataset.map(&:guid)).to contain_exactly(app1.guid, app2.guid)
        end

        context 'with association in dataset query' do
          skip 'returns the models that satisfy the requirements' do
            dataset = subject.add_selector_queries(
              label_klass: AppLabelModel,
              resource_dataset: AppModel.dataset.where(space: Space.dataset),
              requirements: [VCAP::CloudController::LabelSelectorRequirement.new(key: 'easter', operator: :exists, values: '')],
              resource_klass: AppModel,
            )

            expect(dataset.map(&:guid)).to contain_exactly(app3.guid)
          end
        end
      end

      context 'with multiple queries' do
        it 'returns the models that satisfy the requirements' do
          dataset = subject.add_selector_queries(
            label_klass: AppLabelModel,
            resource_dataset: AppModel.dataset,
            requirements: [
              VCAP::CloudController::LabelSelectorRequirement.new(key: 'foo', operator: :in, values: 'funky,town'),
              VCAP::CloudController::LabelSelectorRequirement.new(key: 'foo', operator: :notin, values: 'bar')
            ],
            resource_klass: AppModel,
          )

          expect(dataset.map(&:guid)).to contain_exactly(app2.guid, app3.guid)
        end

        it 'returns the models that satisfy the requirements' do
          dataset = subject.add_selector_queries(
            label_klass: AppLabelModel,
            resource_dataset: AppModel.dataset,
            requirements: [
              VCAP::CloudController::LabelSelectorRequirement.new(key: 'foo', operator: :not_equal, values: 'bar'),
              VCAP::CloudController::LabelSelectorRequirement.new(key: 'foo', operator: :not_equal, values: 'town')
            ],
            resource_klass: AppModel,
          )

          expect(dataset.map(&:guid)).to contain_exactly(app2.guid)
        end

        it 'returns an empty list if the combined requirements do not match any labels' do
          dataset = subject.add_selector_queries(
            label_klass: AppLabelModel,
            resource_dataset: AppModel.dataset,
            requirements: [
              VCAP::CloudController::LabelSelectorRequirement.new(key: 'foo', operator: :equal, values: 'bar'),
              VCAP::CloudController::LabelSelectorRequirement.new(key: 'foo', operator: :equal, values: 'town')
            ],
            resource_klass: AppModel,
          )

          expect(dataset.count).to eq(0)
        end
      end

      context 'when resource_dataset is a join table with a guid column' do
        let(:join_table_dataset) do
          AppModel.dataset.select_all(AppModel.table_name).join_table(:inner, Space.table_name, { guid: Sequel[:apps][:space_guid] })
        end

        it 'can still multiple queries correctly' do
          dataset = subject.add_selector_queries(
            label_klass: AppLabelModel,
            resource_dataset: join_table_dataset,
            requirements: [
              VCAP::CloudController::LabelSelectorRequirement.new(key: 'foo', operator: :equal, values: 'town'),
              VCAP::CloudController::LabelSelectorRequirement.new(key: 'easter', operator: :equal, values: 'bunny')
            ],
            resource_klass: AppModel,
          )

          expect(dataset.map(&:guid)).to contain_exactly(app3.guid)
        end
      end
    end
  end
end
