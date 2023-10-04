require 'spec_helper'
require 'messages/droplets_list_message'
require 'fetchers/droplet_list_fetcher'

module VCAP::CloudController
  RSpec.describe DropletListFetcher do
    subject(:fetcher) { DropletListFetcher }
    let(:pagination_options) { PaginationOptions.new({}) }
    let(:message) { DropletsListMessage.from_params(filters) }
    let(:filters) { {} }

    describe '#fetch_all' do
      let(:app1) { AppModel.make }
      let!(:staged_droplet_for_app1) { DropletModel.make(app_guid: app1.guid, state: DropletModel::STAGED_STATE) }
      let!(:failed_droplet_for_app1) { DropletModel.make(app_guid: app1.guid, state: DropletModel::FAILED_STATE) }

      let(:app2) { AppModel.make }
      let!(:staged_droplet_for_app2) { DropletModel.make(app_guid: app2.guid, state: DropletModel::STAGED_STATE) }

      it 'returns a Sequel::Dataset' do
        results = fetcher.fetch_all(message)
        expect(results).to be_a(Sequel::Dataset)
      end

      it 'returns all of the droplets' do
        results = fetcher.fetch_all(message)
        expect(results).to contain_exactly(staged_droplet_for_app1, failed_droplet_for_app1, staged_droplet_for_app2)
      end

      context 'filtering space guids' do
        let(:filters) { { space_guids: [app1.space.guid] } }

        it 'returns all of the droplets with the requested app guids' do
          results = fetcher.fetch_all(message).all
          expect(results.map(&:guid)).to contain_exactly(staged_droplet_for_app1.guid, failed_droplet_for_app1.guid)
        end
      end

      context 'filtering app guids' do
        let(:filters) { { app_guids: [app1.guid] } }

        it 'returns all of the droplets with the requested app guids' do
          results = fetcher.fetch_all(message).all
          expect(results).to contain_exactly(staged_droplet_for_app1, failed_droplet_for_app1)
        end
      end

      context 'filtering states' do
        let(:filters) { { states: [DropletModel::STAGED_STATE, DropletModel::EXPIRED_STATE] } }
        let!(:expired_droplet_for_other_app) { DropletModel.make(state: DropletModel::EXPIRED_STATE) }

        it 'returns all of the droplets with the requested states' do
          results = fetcher.fetch_all(message).all
          expect(results).to contain_exactly(staged_droplet_for_app1, staged_droplet_for_app2, expired_droplet_for_other_app)
        end
      end

      context 'filtering guids' do
        let(:filters) { { guids: [staged_droplet_for_app1.guid, failed_droplet_for_app1.guid] } }

        it 'returns all of the droplets with the requested guids' do
          results = fetcher.fetch_all(message).all
          expect(results).to contain_exactly(staged_droplet_for_app1, failed_droplet_for_app1)
        end
      end

      context 'filtering organization_guids and space guids' do
        context 'when the organization_guids and space_guids are valid' do
          let(:filters) { { organization_guids: [app2.organization.guid], space_guids: [app2.space.guid] } }

          it 'returns all of the droplets with the requested guids' do
            results = fetcher.fetch_all(message).all
            expect(results).to contain_exactly(staged_droplet_for_app2)
          end
        end

        context 'when the organization_guids are invalid' do
          let(:filters) { { organization_guids: ['hi-riz'], space_guids: [app2.space.guid] } }

          it 'returns no droplets' do
            results = fetcher.fetch_all(message).all
            expect(results).to be_empty
          end
        end

        context 'when the space_guids are invalid' do
          let(:filters) { { organization_guids: [app2.organization.guid], space_guids: ['hi-riz'] } }

          it 'returns no droplets' do
            results = fetcher.fetch_all(message).all
            expect(results).to be_empty
          end
        end
      end

      context 'filtering organization_guids' do
        context 'when the organization_guids are valid' do
          let(:filters) { { organization_guids: [app2.organization.guid] } }

          it 'returns all of the droplets with the requested guids' do
            results = fetcher.fetch_all(message).all
            expect(results).to contain_exactly(staged_droplet_for_app2)
          end
        end

        context 'when the organization_guids are invalid' do
          let(:filters) { { organization_guids: ['hi-riz'] } }

          it 'returns no droplets' do
            results = fetcher.fetch_all(message).all
            expect(results).to be_empty
          end
        end
      end

      context 'filtering labels' do
        let(:message) do
          DropletsListMessage.from_params({ 'label_selector' => 'key=value' })
        end
        let!(:droplet1Label) { DropletLabelModel.make(key_name: 'key', value: 'value', droplet: staged_droplet_for_app1) }
        let!(:droplet2Label) { DropletLabelModel.make(key_name: 'key2', value: 'value2', droplet: failed_droplet_for_app1) }

        it 'returns the correct set of droplets' do
          results = fetcher.fetch_all(message)
          expect(results).to contain_exactly(staged_droplet_for_app1)
        end
      end
    end

    describe '#fetch_for_spaces' do
      let(:space1) { app1.space }
      let(:app1) { AppModel.make }
      let!(:staged_droplet_for_app1) { DropletModel.make(app_guid: app1.guid, state: DropletModel::STAGED_STATE) }
      let!(:failed_droplet_for_app1) { DropletModel.make(app_guid: app1.guid, state: DropletModel::FAILED_STATE) }

      let(:app2) { AppModel.make }
      let(:space2) { app2.space }
      let!(:staged_droplet_for_app2) { DropletModel.make(app_guid: app2.guid, state: DropletModel::STAGED_STATE) }

      let(:app3) { AppModel.make }
      let(:space3) { app3.space }
      let!(:expired_droplet_for_app3) { DropletModel.make(app_guid: app3.guid, state: DropletModel::EXPIRED_STATE) }

      let(:space_guids) { [space1.guid, space2.guid] }

      it 'returns a Sequel::Dataset' do
        results = fetcher.fetch_for_spaces(message, space_guids)
        expect(results).to be_a(Sequel::Dataset)
      end

      it 'returns all of the desired droplets in the requested spaces' do
        results = fetcher.fetch_for_spaces(message, space_guids).all
        expect(results.map(&:guid)).to contain_exactly(staged_droplet_for_app1.guid, failed_droplet_for_app1.guid, staged_droplet_for_app2.guid)
      end

      it 'returns no droplets when no spaces are provided' do
        expect(fetcher.fetch_for_spaces(message, []).all).to be_empty
      end

      context 'filtering app guids' do
        let(:filters) { { app_guids: [app2.guid, app3.guid] } }
        let(:space_guids) { [space1.guid, space2.guid, space3.guid] }

        it 'returns all of the desired droplets for the requested app guids' do
          results = fetcher.fetch_for_spaces(message, space_guids).all
          expect(results).to contain_exactly(staged_droplet_for_app2, expired_droplet_for_app3)
        end
      end

      context 'filtering states' do
        let(:filters) { { states: [DropletModel::STAGED_STATE, DropletModel::FAILED_STATE] } }
        let(:space_guids) { [space1.guid, space2.guid, space3.guid] }

        it 'returns all of the desired droplets with the requested droplet states' do
          results = fetcher.fetch_for_spaces(message, space_guids).all
          expect(results).to contain_exactly(failed_droplet_for_app1, staged_droplet_for_app1, staged_droplet_for_app2)
        end
      end

      context 'filtering guids' do
        let(:filters) { { guids: [failed_droplet_for_app1.guid, staged_droplet_for_app2.guid] } }

        it 'returns all of the desired droplets with the requested droplet guids' do
          results = fetcher.fetch_for_spaces(message, space_guids).all
          expect(results).to contain_exactly(failed_droplet_for_app1, staged_droplet_for_app2)
        end
      end

      context 'filtering space guids' do
        let(:filters) { { space_guids: [failed_droplet_for_app1.space.guid] } }

        it 'returns all of the desired droplets with the requested space guids' do
          results = fetcher.fetch_for_spaces(message, space_guids).all
          expect(results.map(&:guid)).to contain_exactly(failed_droplet_for_app1.guid, staged_droplet_for_app1.guid)
        end
      end
    end

    describe '#fetch_for_app' do
      let(:app) { AppModel.make }
      let!(:staged_droplet) { DropletModel.make(app_guid: app.guid, state: DropletModel::STAGED_STATE) }
      let!(:failed_droplet) { DropletModel.make(app_guid: app.guid, state: DropletModel::FAILED_STATE) }
      let(:filters) { { app_guid: app.guid } }

      it 'returns a Sequel::Dataset' do
        _app, results = fetcher.fetch_for_app(message)
        expect(results).to be_a(Sequel::Dataset)
      end

      it 'returns the app' do
        returned_app, _results = fetcher.fetch_for_app(message)
        expect(returned_app.guid).to eq(app.guid)
      end

      it 'returns all of the desired droplets for the requested app' do
        _app, results = fetcher.fetch_for_app(message)
        expect(results.all).to contain_exactly(staged_droplet, failed_droplet)
      end

      context 'when app does not exist' do
        let(:filters) { { app_guid: 'made up guid lol' } }

        it 'returns nil' do
          returned_app, results = fetcher.fetch_for_app(message)
          expect(returned_app).to be_nil
          expect(results).to be_nil
        end
      end

      context 'filtering states' do
        let(:filters) { { states: [DropletModel::FAILED_STATE], app_guid: app.guid } }
        let!(:failed_droplet_not_on_app) { DropletModel.make(state: DropletModel::FAILED_STATE) }

        it 'returns all of the desired droplets with the requested droplet states' do
          _app, results = fetcher.fetch_for_app(message)
          expect(results.all).to contain_exactly(failed_droplet)
        end
      end

      describe 'filtering by current droplet' do
        let(:filters) { { current: 'true', app_guid: app.guid } }

        context 'when there is a current droplet for the app' do
          before do
            app.update(droplet: staged_droplet)
          end

          it 'returns the current droplet' do
            _app, results = fetcher.fetch_for_app(message)
            expect(results.all).to contain_exactly(staged_droplet)
          end
        end

        context 'when there is no current droplet for the app' do
          before do
            app.update(droplet: nil)
          end

          it 'returns an empty list' do
            _app, results = fetcher.fetch_for_app(message)
            expect(results.all).to be_empty
          end
        end
      end
    end

    describe '#fetch_for_package' do
      let(:package) { PackageModel.make }
      let!(:staged_droplet) { DropletModel.make(package_guid: package.guid, state: DropletModel::STAGED_STATE) }
      let!(:failed_droplet) { DropletModel.make(package_guid: package.guid, state: DropletModel::FAILED_STATE) }
      let(:filters) { { package_guid: package.guid } }

      it 'returns a Sequel::Dataset' do
        _package, results = fetcher.fetch_for_package(message)
        expect(results).to be_a(Sequel::Dataset)
      end

      it 'returns the package' do
        returned_package, _results = fetcher.fetch_for_package(message)
        expect(returned_package.guid).to eq(package.guid)
      end

      it 'returns all of the desired droplets for the requested package' do
        _package, results = fetcher.fetch_for_package(message)
        expect(results.all).to contain_exactly(staged_droplet, failed_droplet)
      end

      context 'when package does not exist' do
        let(:filters) { { package_guid: 'made up guid lol' } }

        it 'returns nil' do
          returned_package, results = fetcher.fetch_for_package(message)
          expect(returned_package).to be_nil
          expect(results).to be_nil
        end
      end

      context 'filtering states' do
        let(:filters) { { states: [DropletModel::FAILED_STATE], package_guid: package.guid } }
        let!(:failed_droplet_not_on_package) { DropletModel.make(state: DropletModel::FAILED_STATE) }

        it 'returns all of the desired droplets with the requested droplet states' do
          _package, results = fetcher.fetch_for_package(message)
          expect(results.all).to contain_exactly(failed_droplet)
        end
      end
    end
  end
end
