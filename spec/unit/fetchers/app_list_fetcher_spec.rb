require 'spec_helper'
require 'messages/apps_list_message'

module VCAP::CloudController
  RSpec.describe AppListFetcher do
    subject { AppListFetcher.fetch_all(message) }
    let!(:stack) { create(:stack) }
    let(:space) { create(:space, guid: 'main-space') }
    let!(:app) { create(:app_model, space: space, name: 'app') }
    let!(:sad_app) { create(:app_model, space: space) }
    let(:org) { space.organization }
    let(:fetcher) { AppListFetcher }
    let(:space_guids) { [space.guid] }
    let(:pagination_options) { PaginationOptions.new({}) }
    let(:filters) { {} }
    let(:message) { AppsListMessage.from_params(filters) }
    let!(:lifecycle_data_for_app) do
      create(:buildpack_lifecycle_data_model,
             app: app,
             stack: stack.name,
             buildpacks: [create(:buildpack).name])
    end
    let!(:lifecycle_data_for_sad_app) do
      create(:buildpack_lifecycle_data_model, app: sad_app, stack: nil)
    end

    describe '#fetch_all' do
      it 'eager loads the specified resources for all apps' do
        results = fetcher.fetch_all(message, eager_loaded_associations: [:labels, { buildpack_lifecycle_data: :buildpack_lifecycle_buildpacks }]).all

        expect(results.first.buildpack_lifecycle_data.associations.key?(:buildpack_lifecycle_buildpacks)).to be true
        expect(results.first.associations.key?(:buildpack_lifecycle_data)).to be true
        expect(results.first.associations.key?(:labels)).to be true
        expect(results.first.associations.key?(:annotations)).to be false
      end

      it 'includes all the apps' do
        app = create(:app_model)
        expect(subject.all).to include(app, sad_app)
      end
    end

    describe '#fetch' do
      let(:apps) { fetcher.fetch(message, space_guids) }

      it 'eager loads the specified resources for all apps' do
        results = fetcher.fetch(message, space_guids, eager_loaded_associations: [:labels, { buildpack_lifecycle_data: :buildpack_lifecycle_buildpacks }]).all

        expect(results.first.buildpack_lifecycle_data.associations.key?(:buildpack_lifecycle_buildpacks)).to be true
        expect(results.first.associations.key?(:buildpack_lifecycle_data)).to be true
        expect(results.first.associations.key?(:labels)).to be true
        expect(results.first.associations.key?(:annotations)).to be false
      end

      context 'when no filters are specified' do
        it 'returns all of the desired apps' do
          expect(apps.all).to contain_exactly(app, sad_app)
        end
      end

      context 'when the app names are provided' do
        let(:filters) { { names: [app.name] } }

        it 'returns all of the desired apps' do
          expect(apps.all).to contain_exactly(app)
        end
      end

      context 'when the app space_guids are provided' do
        let(:filters) { { space_guids: [space.guid] } }
        let(:sad_app) { create(:app_model) }

        it 'returns all of the desired apps' do
          expect(apps.all).to contain_exactly(app)
        end
      end

      context 'when the organization guids are provided' do
        let(:filters) { { organization_guids: [org.guid] } }
        let(:sad_org) { create(:organization) }
        let(:sad_space) { create(:space, organization: sad_org) }
        let(:sad_app) { create(:app_model, space: sad_space) }
        let(:space_guids) { [space.guid, sad_space.guid] }

        it 'returns all of the desired apps' do
          expect(apps.all).to contain_exactly(app)
        end
      end

      context 'when a stack is provided' do
        let(:filters) { { stacks: [lifecycle_data_for_app.stack] } }

        it 'returns all of the desired apps' do
          expect(apps.all).to contain_exactly(app)
        end
      end

      context 'when an empty stack is provided' do
        let(:filters) { { stacks: [''] } }

        it 'returns all of the desired apps' do
          expect(apps.all).to contain_exactly(sad_app)
        end
      end

      context 'when the app guids are provided' do
        let(:filters) { { guids: [app.guid] } }

        it 'returns all of the desired apps' do
          expect(apps.all).to contain_exactly(app)
        end
      end

      context 'when a label_selector is provided' do
        let(:filters) { { 'label_selector' => 'dog in (chihuahua,scooby-doo)' } }
        let!(:app_label) do
          create(:app_label_model, resource_guid: app.guid, key_name: 'dog', value: 'scooby-doo')
        end
        let!(:sad_app_label) do
          create(:app_label_model, resource_guid: sad_app.guid, key_name: 'dog', value: 'poodle')
        end

        it 'returns all of the desired apps' do
          expect(apps.all).to contain_exactly(app)
        end

        context 'and other filters are present' do
          let!(:happiest_app) { create(:app_model, space: space, name: 'bob') }
          let!(:happiest_app_label) do
            create(:app_label_model, resource_guid: happiest_app.guid, key_name: 'dog', value: 'scooby-doo')
          end
          let(:filters) { { 'names' => 'bob', 'label_selector' => 'dog in (chihuahua,scooby-doo)' } }

          it 'returns the desired app' do
            expect(apps.all).to contain_exactly(happiest_app)
          end
        end

        context 'labels and spaces' do
          let!(:happy_space) { create(:space, organization: space.organization, guid: 'happy_space') }
          let!(:space_guids) { [happy_space.guid] }
          let!(:happiest_app) { create(:app_model, space: happy_space, name: 'bob2') }
          let!(:happiest_app_label) do
            create(:app_label_model, resource_guid: happiest_app.guid, key_name: 'dog', value: 'scooby-doo')
          end
          let!(:mildly_happy_app) { create(:app_model, space: happy_space, name: 'bob3') }
          let(:filters) { { space_guids: [happy_space.guid], 'label_selector' => 'dog in (chihuahua,scooby-doo)' } }

          it 'returns the desired app' do
            expect(apps.all).to contain_exactly(happiest_app)
          end

          context 'labels and orgs and spaces' do
            let(:filters) do
              {
                space_guids: [happy_space.guid],
                organization_guids: [happy_space.organization.guid],
                'label_selector' => 'dog in (chihuahua,scooby-doo)'
              }
            end

            it 'returns the desired app' do
              expect(apps.all).to contain_exactly(happiest_app)
            end
          end
        end
      end

      context 'when a lifecycle_type is provided' do
        let!(:docker_app) { create(:app_model, :docker, name: 'docker-app', space: space) }
        let!(:cnb_app) { create(:app_model, :cnb, name: 'cnb-app', space: space) }

        before do
          docker_app.buildpack_lifecycle_data = nil
          docker_app.save
          cnb_app.save
        end

        context 'of type buildpack' do
          let(:filters) { { lifecycle_type: 'buildpack' } }

          it 'returns all of the buildpack apps' do
            expect(apps.all).to contain_exactly(app, sad_app)
          end
        end

        context 'of type cnb' do
          let(:filters) { { lifecycle_type: 'cnb' } }

          it 'returns all of the cnb apps' do
            expect(apps.all).to contain_exactly(cnb_app)
          end
        end

        context 'of type docker' do
          let(:filters) { { lifecycle_type: 'docker' } }

          it 'returns all of the docker apps' do
            expect(apps.all).to contain_exactly(docker_app)
          end
        end
      end

      context 'filtering timestamps' do
        before do
          AppModel.plugin :timestamps, update_on_create: true, allow_manual_update: true
        end

        let!(:resource_1) { create(:app_model, name: '1', created_at: '2020-05-26T18:47:01Z', space: space).tap { |r| r.update(updated_at: '2020-05-26T18:47:01Z') } }
        let!(:resource_2) { create(:app_model, name: '2', created_at: '2020-05-26T18:47:02Z', space: space).tap { |r| r.update(updated_at: '2020-05-26T18:47:02Z') } }
        let!(:resource_3) { create(:app_model, name: '3', created_at: '2020-05-26T18:47:03Z', space: space).tap { |r| r.update(updated_at: '2020-05-26T18:47:03Z') } }
        let!(:resource_4) { create(:app_model, name: '4', created_at: '2020-05-26T18:47:04Z', space: space).tap { |r| r.update(updated_at: '2020-05-26T18:47:04Z') } }

        after do
          AppModel.plugin :timestamps, update_on_create: true, allow_manual_update: false
        end

        context 'filtering on created_at' do
          let(:filters) do
            { created_ats: { lt: resource_3.created_at.iso8601 } }
          end

          it 'delegates filtering to the base class' do
            expect(subject).to contain_exactly(resource_1, resource_2)
          end
        end

        context 'filtering on updated_at' do
          let(:filters) do
            { updated_ats: { lt: resource_3.updated_at.iso8601 } }
          end

          it 'delegates filtering to the base class' do
            expect(subject).to contain_exactly(resource_1, resource_2)
          end
        end
      end
    end
  end
end
