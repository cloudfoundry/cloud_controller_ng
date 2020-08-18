require 'spec_helper'
require 'fetchers/process_list_fetcher'

module VCAP::CloudController
  RSpec.describe ProcessListFetcher do
    let(:pagination_options) { PaginationOptions.new({}) }
    let(:message) { ProcessesListMessage.from_params(filters) }
    let(:eager_loaded_associations) { [] }
    let(:filters) { {} }

    describe '#fetch_all' do
      subject { ProcessListFetcher.fetch_all(message, eager_loaded_associations: eager_loaded_associations) }

      let!(:web) { ProcessModel.make(type: 'web') }
      let!(:web2) { ProcessModel.make(type: 'web') }
      let!(:worker) { ProcessModel.make(type: 'worker') }

      it 'returns a Sequel::Dataset' do
        expect(subject).to be_a(Sequel::Dataset)
      end

      describe 'eager loading associated resources' do
        let(:eager_loaded_associations) { [:labels] }

        it 'eager loads the specified resources for the processes' do
          results = subject.all

          expect(results.first.associations.key?(:labels)).to be true
          expect(results.first.associations.key?(:annotations)).to be false
        end
      end

      it 'returns all of the processes' do
        results = subject.all
        expect(results).to match_array([web, web2, worker])
      end

      context 'filters' do
        context 'type' do
          let(:filters) { { types: ['web'] } }

          it 'only returns matching processes' do
            results = subject.all
            expect(results).to match_array([web, web2])
          end
        end

        context 'space guids' do
          let(:filters) { { space_guids: [web.space.guid] } }

          it 'only returns matching processes' do
            results = subject.all
            expect(results).to match_array([web])
          end
        end

        context 'organization guids' do
          let(:filters) { { organization_guids: [web.space.organization.guid] } }

          it 'only returns matching processes' do
            results = subject.all
            expect(results).to match_array([web])
          end
        end

        context 'app guids' do
          let!(:desired_process) { ProcessModel.make(app: desired_app) }
          let(:desired_app) { AppModel.make }
          let(:filters) { { app_guids: [desired_app.guid] } }

          it 'only returns matching processes' do
            results = subject.all
            expect(results).to match_array([desired_process])
          end
        end

        context 'guids' do
          let(:filters) { { guids: [web.guid, web2.guid] } }

          it 'returns the matching processes' do
            results = subject.all
            expect(results).to match_array([web, web2])
          end
        end

        context 'label selectors' do
          let(:filters) { { 'label_selector' => 'key=value' } }
          let!(:label) { ProcessLabelModel.make(resource_guid: web2.guid, key_name: 'key', value: 'value') }

          it 'returns the correct set of packages' do
            results = subject.all
            expect(results).to match_array([web2])
          end
        end
      end
    end

    describe '#fetch_for_spaces' do
      let(:app1) { AppModel.make }
      let(:space1) { app1.space }
      let!(:process_in_space1) { ProcessModel.make(app: app1, type: 'a') }
      let!(:process2_in_space1) { ProcessModel.make(app: app1, type: 'b') }
      let(:app2) { AppModel.make }
      let(:space2) { app2.space }
      let!(:process_in_space2) { ProcessModel.make(app: app2) }
      let(:space_guids) { [] }

      subject { ProcessListFetcher.fetch_for_spaces(message, space_guids: space_guids, eager_loaded_associations: eager_loaded_associations) }

      before { ProcessModel.make }

      it 'returns a Sequel::Dataset' do
        expect(subject).to be_a(Sequel::Dataset)
      end

      describe 'eager loading associated resources' do
        let(:space_guids) { [space1.guid, space2.guid] }
        let(:eager_loaded_associations) { [:labels] }

        it 'eager loads the specified resources for the processes' do
          results = subject.all

          expect(results.first.associations.key?(:labels)).to be true
          expect(results.first.associations.key?(:annotations)).to be false
        end
      end

      context 'limited to spaces' do
        let(:space_guids) { [space1.guid, space2.guid] }

        it 'returns only the processes in spaces requested' do
          results = subject.all
          expect(results).to match_array([process_in_space1, process2_in_space1, process_in_space2])
        end
      end

      context 'with a space_guid filter' do
        let(:filters) { { space_guids: [space1.guid] } }
        let(:space_guids) { [space1.guid, space2.guid] }

        it 'only returns matching processes' do
          results = subject.all
          expect(results).to match_array([process_in_space1, process2_in_space1])
        end
      end
    end

    describe '#fetch_for_app' do
      let(:app) { AppModel.make }
      let(:filters) { { app_guid: app.guid } }

      subject { ProcessListFetcher.fetch_for_app(message, eager_loaded_associations: eager_loaded_associations) }

      it 'returns a Sequel::Dataset and the app' do
        returned_app, results = subject
        expect(returned_app.guid).to eq(app.guid)
        expect(results).to be_a(Sequel::Dataset)
      end

      describe 'eager loading associated resources' do
        let(:eager_loaded_associations) { [:labels] }

        it 'eager loads the specified resources for the processes' do
          ProcessModel.make(:process, app: app)

          _, processes_dataset = subject
          results = processes_dataset.all

          expect(results.first.associations.key?(:labels)).to be true
          expect(results.first.associations.key?(:annotations)).to be false
        end
      end

      it 'returns the processes for the app' do
        process1 = ProcessModel.make(:process, app: app)
        process2 = ProcessModel.make(:process, app: app)
        ProcessModel.make(:process)

        _app, results = subject
        expect(results.all).to match_array([process1, process2])
      end

      context 'when the app does not exist' do
        let(:filters) { { app_guid: 'made-up' } }

        it 'returns nil' do
          returned_app, results = subject
          expect(returned_app).to be_nil
          expect(results).to be_nil
        end
      end
    end
  end
end
