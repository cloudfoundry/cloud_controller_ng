require 'spec_helper'

module VCAP::CloudController
  describe DropletsController do
    let(:logger) { instance_double(Steno::Logger) }
    let(:params) { {} }
    let(:droplet_presenter) { double(:droplet_presenter) }
    let(:membership) { double(:membership) }
    let(:req_body) { '{}' }

    let(:droplets_controller) do
      DropletsController.new(
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
      allow(droplets_controller).to receive(:membership).and_return(membership)
      allow(membership).to receive(:has_any_roles?).and_return(true)
    end

    describe '#show' do
      let(:droplet) { DropletModel.make }
      let(:space) { droplet.space }
      let(:org) { space.organization }
      let(:expected_response) { 'im a response' }

      before do
        allow(droplet_presenter).to receive(:present_json).and_return(expected_response)
        allow(droplets_controller).to receive(:check_read_permissions!)
      end

      it 'returns a 200 OK and the droplet' do
        response_code, response = droplets_controller.show(droplet.guid)
        expect(response_code).to eq 200
        expect(response).to eq(expected_response)
        expect(droplet_presenter).to have_received(:present_json).with(droplet)
      end

      context 'when the user has the incorrect scope' do
        before do
          allow(droplets_controller).to receive(:check_read_permissions!).
              and_raise(VCAP::Errors::ApiError.new_from_details('NotAuthorized'))
        end

        it 'returns a 403 NotAuthorized error' do
          expect {
            droplets_controller.show(droplet.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'NotAuthorized'
            expect(error.response_code).to eq 403
          end

          expect(droplets_controller).to have_received(:check_read_permissions!)
        end
      end

      context 'when the user has incorrect roles' do
        before do
          allow(membership).to receive(:has_any_roles?).and_raise('incorrect args')
          allow(membership).to receive(:has_any_roles?).with(
              [Membership::SPACE_DEVELOPER,
               Membership::SPACE_MANAGER,
               Membership::SPACE_AUDITOR,
               Membership::ORG_MANAGER], space.guid, org.guid).and_return(false)
        end

        it 'returns a 404 not found' do
          expect {
            droplets_controller.show(droplet.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end

          expect(membership).to have_received(:has_any_roles?).with(
              [Membership::SPACE_DEVELOPER,
               Membership::SPACE_MANAGER,
               Membership::SPACE_AUDITOR,
               Membership::ORG_MANAGER], space.guid, org.guid)
        end
      end

      context 'when the droplet does not exist' do
        it 'returns a 404 Not Found' do
          expect {
            droplets_controller.show('shablam!')
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end
    end

    describe '#delete' do
      let(:space) { Space.make }
      let(:org) { space.organization }
      let(:app_model) { AppModel.make(space_guid: space.guid) }
      let(:droplet) { DropletModel.make(app_guid: app_model.guid) }

      before do
        # stubbing the BaseController methods for now, this should probably be
        # injected into the droplets controller
        allow(droplets_controller).to receive(:check_write_permissions!)
      end

      it 'checks for write permissions' do
        droplets_controller.delete(droplet.guid)
        expect(droplets_controller).to have_received(:check_write_permissions!)
      end

      it 'returns a 204 NO CONTENT' do
        response_code, response = droplets_controller.delete(droplet.guid)
        expect(response_code).to eq 204
        expect(response).to be_nil
      end

      it 'checks for the proper roles' do
        droplets_controller.delete(droplet.guid)

        expect(membership).to have_received(:has_any_roles?).at_least(1).times
        expect(membership).to have_received(:has_any_roles?).exactly(1).times.
          with([Membership::SPACE_DEVELOPER], space.guid)
      end

      context 'when the droplet does not exist' do
        it 'returns a 404 Not Found' do
          expect {
            droplets_controller.delete('non-existant')
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the user cannot read the droplet' do
        before do
          allow(membership).to receive(:has_any_roles?).and_raise('incorrect args')
          allow(membership).to receive(:has_any_roles?).with(
            [Membership::SPACE_DEVELOPER,
             Membership::SPACE_MANAGER,
             Membership::SPACE_AUDITOR,
             Membership::ORG_MANAGER], space.guid, org.guid).and_return(false)
        end

        it 'returns a 404 ResourceNotFound error' do
          expect {
            droplets_controller.delete(droplet.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the user can read but cannot write to the droplet' do
        before do
          allow(membership).to receive(:has_any_roles?).and_raise('incorrect args')
          allow(membership).to receive(:has_any_roles?).with(
            [Membership::SPACE_DEVELOPER,
             Membership::SPACE_MANAGER,
             Membership::SPACE_AUDITOR,
             Membership::ORG_MANAGER], space.guid, org.guid).
            and_return(true)
          allow(membership).to receive(:has_any_roles?).with([Membership::SPACE_DEVELOPER], space.guid).
            and_return(false)
        end

        it 'raises ApiError NotAuthorized' do
          expect {
            droplets_controller.delete(droplet.guid)
          }.to raise_error do |error|
            expect(error.name).to eq 'NotAuthorized'
            expect(error.response_code).to eq 403
          end
        end
      end
    end

    describe '#list' do
      let(:page) { 1 }
      let(:per_page) { 2 }
      let(:params) { { 'page' => page, 'per_page' => per_page } }
      let(:expected_response) { 'im a response' }

      before do
        allow(droplet_presenter).to receive(:present_json_list).and_return(expected_response)
        allow(droplets_controller).to receive(:check_read_permissions!)
      end

      context 'when the user is an admin' do
        before do
          allow(membership).to receive(:admin?).and_return(true)
        end

        it 'returns all droplets' do
          DropletModel.make
          DropletModel.make
          DropletModel.make

          response_code, response_body = droplets_controller.list

          expect(droplet_presenter).to have_received(:present_json_list).
            with(an_instance_of(PaginatedResult), '/v3/droplets') do |result|
              expect(result.total).to eq(DropletModel.count)
            end
          expect(response_code).to eq(200)
          expect(response_body).to eq(expected_response)
        end
      end

      context 'when the user is not an admin' do
        let(:viewable_droplet) { DropletModel.make }

        before do
          allow(membership).to receive(:admin?).and_return(false)
          allow(membership).to receive(:space_guids_for_roles).and_return([viewable_droplet.space.guid])
        end

        it 'returns packages the user has roles to see' do
          DropletModel.make
          DropletModel.make

          response_code, response_body = droplets_controller.list

          expect(droplet_presenter).to have_received(:present_json_list).
            with(an_instance_of(PaginatedResult), '/v3/droplets') do |result|
              expect(result.total).to be < DropletModel.count
              expect(result.total).to eq(1)
            end
          expect(response_code).to eq(200)
          expect(response_body).to eq(expected_response)
          expect(membership).to have_received(:space_guids_for_roles).
              with([Membership::SPACE_DEVELOPER,
                    Membership::SPACE_MANAGER,
                    Membership::SPACE_AUDITOR,
                    Membership::ORG_MANAGER])
        end
      end

      context 'when the user has incorrect scope' do
        before do
          allow(droplets_controller).to receive(:check_read_permissions!).
              and_raise(VCAP::Errors::ApiError.new_from_details('NotAuthorized'))
        end

        it 'returns a 403 Not Authorized error' do
          expect {
            droplets_controller.list
          }.to raise_error do |error|
            expect(error.name).to eq 'NotAuthorized'
            expect(error.response_code).to eq 403
          end

          expect(droplets_controller).to have_received(:check_read_permissions!)
        end
      end

      context 'when parameters are invalid' do
        context 'because there are unknown parameters' do
          let(:params) { { 'invalid' => 'thing', 'bad' => 'stuff' } }

          it 'returns an 400 Bad Request' do
            expect {
              droplets_controller.list
            }.to raise_error do |error|
              expect(error.name).to eq 'BadQueryParameter'
              expect(error.response_code).to eq 400
              expect(error.message).to include("Unknown query param(s) 'invalid', 'bad'")
            end
          end
        end

        context 'because there are invalid values in parameters' do
          let(:params) { { 'per_page' => 'foo' } }

          it 'returns an 400 Bad Request' do
            expect {
              droplets_controller.list
            }.to raise_error do |error|
              expect(error.name).to eq 'BadQueryParameter'
              expect(error.response_code).to eq 400
              expect(error.message).to include('Per page must be between 1 and 5000')
            end
          end
        end
      end
    end
  end
end
