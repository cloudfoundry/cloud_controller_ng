require 'spec_helper'

module VCAP::CloudController
  describe AppsDropletsController do
    let(:logger) { instance_double(Steno::Logger) }
    let(:params) { {} }
    let(:droplet_presenter) { double(:droplet_presenter) }
    let(:membership) { double(:membership) }
    let(:req_body) { '{}' }
    let(:app) { AppModel.make }
    let(:space) { app.space }
    let(:org) { space.organization }
    let(:app_fetcher) { double(:app_fetcher) }
    let(:app_guid) { app.guid }
    let(:space_guid) { space.guid }
    let(:org_guid) { org.guid }

    let(:apps_droplets_controller) do
      AppsDropletsController.new(
        {},
        logger,
        {},
        params.stringify_keys,
        req_body,
        nil,
        {
          droplet_presenter: droplet_presenter,
        },
      )
    end

    before do
      allow(logger).to receive(:debug)
      allow(apps_droplets_controller).to receive(:membership).and_return(membership)
      allow(membership).to receive(:has_any_roles?).and_return(true)
      allow(app_fetcher).to receive(:fetch).and_return([app, space, org])
      allow(AppFetcher).to receive(:new).and_return(app_fetcher)
    end

    describe '#list' do
      let(:page) { 1 }
      let(:per_page) { 2 }
      let(:params) { { 'page' => page, 'per_page' => per_page } }
      let(:expected_response) { 'im a response' }

      before do
        allow(droplet_presenter).to receive(:present_json_list).and_return(expected_response)
        allow(apps_droplets_controller).to receive(:check_read_permissions!)
      end

      context 'query params' do
        context 'invalid param format' do
          let(:params) { { 'order_by' => 'up' } }

          it 'returns 400' do
            expect {
              apps_droplets_controller.list(app_guid)
            }.to raise_error do |error|
              expect(error.name).to eq 'BadQueryParameter'
              expect(error.response_code).to eq 400
              expect(error.message).to match('Invalid type')
            end
          end
        end

        context 'unknown query param' do
          let(:bad_param) { 'foo' }
          let(:params) { { 'bad_param' => bad_param } }

          it 'returns 400' do
            expect {
              apps_droplets_controller.list(app_guid)
            }.to raise_error do |error|
              expect(error.name).to eq 'BadQueryParameter'
              expect(error.response_code).to eq 400
              expect(error.message).to match('Unknown query param')
            end
          end
        end
      end

      context 'when the user is an admin' do
        before do
          allow(membership).to receive(:admin?).and_return(true)
        end

        context 'the app exists' do
          it 'returns all droplets' do
            DropletModel.make(app_guid: app_guid)
            DropletModel.make(app_guid: app_guid)
            DropletModel.make(app_guid: app_guid)

            response_code, response_body = apps_droplets_controller.list(app_guid)

            expect(droplet_presenter).to have_received(:present_json_list).
              with(an_instance_of(PaginatedResult), '/v3/droplets') do |result|
              expect(result.total).to eq(DropletModel.count)
            end
            expect(response_code).to eq(200)
            expect(response_body).to eq(expected_response)
          end
        end

        context 'the app does not exist' do
          before do
            allow(app_fetcher).to receive(:fetch).and_return([nil, nil, nil])
          end

          it 'returns a 404 Resource Not Found' do
            expect { apps_droplets_controller.list(app_guid) }.to raise_error do |error|
              expect(error.name).to eq 'ResourceNotFound'
              expect(error.response_code).to eq 404
            end
          end
        end
      end

      context 'when the user is not an admin' do
        let(:viewable_droplet) { DropletModel.make }
        context 'when the user has space privileges' do
          before do
            allow(membership).to receive(:admin?).and_return(false)
            allow(membership).to receive(:has_any_roles?).and_return(true)
          end

          it 'returns droplets the user has roles to see' do
            DropletModel.make(app_guid: app_guid)
            DropletModel.make

            response_code, response_body = apps_droplets_controller.list(app_guid)

            expect(membership).to have_received(:has_any_roles?).
              with([Membership::SPACE_DEVELOPER,
                    Membership::SPACE_MANAGER,
                    Membership::SPACE_AUDITOR,
                    Membership::ORG_MANAGER], space_guid, org_guid)
            expect(droplet_presenter).to have_received(:present_json_list).
              with(an_instance_of(PaginatedResult), '/v3/droplets') do |result|
              expect(result.total).to eq(1)
            end
            expect(response_code).to eq(200)
            expect(response_body).to eq(expected_response)
          end
        end

        context 'when the user has no space privileges' do
          before do
            allow(membership).to receive(:admin?).and_return(false)
            allow(membership).to receive(:has_any_roles?).and_return(false)
          end

          context 'when the app exists' do
            it 'returns a 404 Resource Not Found error' do
              expect { apps_droplets_controller.list(app_guid) }.to raise_error do |error|
                expect(error.name).to eq 'ResourceNotFound'
                expect(error.response_code).to eq 404
              end
              expect(membership).to have_received(:has_any_roles?).
                with([Membership::SPACE_DEVELOPER,
                      Membership::SPACE_MANAGER,
                      Membership::SPACE_AUDITOR,
                      Membership::ORG_MANAGER], space_guid, org_guid)
            end
          end

          context 'when the app does not exist' do
            before do
              allow(app_fetcher).to receive(:fetch).and_return([nil, nil, nil])
            end

            it 'returns a 404 Resource Not Found error' do
              expect { apps_droplets_controller.list(app_guid) }.to raise_error do |error|
                expect(error.name).to eq 'ResourceNotFound'
                expect(error.response_code).to eq 404
              end
            end
          end
        end
      end

      context 'when the user has incorrect scope' do
        before do
          allow(apps_droplets_controller).to receive(:check_read_permissions!).
              and_raise(VCAP::Errors::ApiError.new_from_details('NotAuthorized'))
        end

        it 'returns a 403 Not Authorized error' do
          expect {
            apps_droplets_controller.list(app_guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'NotAuthorized'
            expect(error.response_code).to eq 403
          end

          expect(apps_droplets_controller).to have_received(:check_read_permissions!)
        end
      end
    end
  end
end
