require 'spec_helper'

module VCAP::CloudController
  describe DropletsController do
    let(:logger) { instance_double(Steno::Logger) }
    let(:user) { User.make }
    let(:params) { {} }
    let(:droplets_handler) { double(:droplets_handler) }
    let(:droplet_presenter) { double(:droplet_presenter) }
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
          droplets_handler: droplets_handler,
          droplet_presenter: droplet_presenter,
        },
      )
    end

    before do
      allow(logger).to receive(:debug)
    end

    describe '#show' do
      context 'when the droplet does not exist' do
        before do
          allow(droplets_handler).to receive(:show).and_return(nil)
        end

        it 'returns a 404 Not Found' do
          expect {
            droplets_controller.show('non-existant')
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the droplet exists' do
        let(:droplet) { DropletModel.make }
        let(:droplet_guid) { droplet.guid }

        context 'when a user can access a droplet' do
          let(:expected_response) { 'im a response' }

          before do
            allow(droplets_handler).to receive(:show).and_return(droplet)
            allow(droplet_presenter).to receive(:present_json).and_return(expected_response)
          end

          it 'returns a 200 OK and the droplet' do
            response_code, response = droplets_controller.show(droplet_guid)
            expect(response_code).to eq 200
            expect(response).to eq(expected_response)
          end
        end

        context 'when the user cannot access the droplet' do
          before do
            allow(droplets_handler).to receive(:show).and_raise(DropletsHandler::Unauthorized)
          end

          it 'returns a 403 NotAuthorized error' do
            expect {
              droplets_controller.show(droplet_guid)
            }.to raise_error do |error|
              expect(error.name).to eq 'NotAuthorized'
              expect(error.response_code).to eq 403
            end
          end
        end
      end
    end

    describe '#delete' do
      context 'when the droplet does not exist' do
        before do
          allow(droplets_handler).to receive(:delete).and_return(nil)
        end

        it 'returns a 404 Not Found' do
          expect {
            droplets_controller.delete('non-existant')
          }.to raise_error do |error|
            expect(error.name).to eq 'ResourceNotFound'
            expect(error.response_code).to eq 404
          end
        end
      end

      context 'when the droplet exists' do
        let(:droplet) { DropletModel.make }
        let(:droplet_guid) { droplet.guid }

        context 'when a user can access a droplet' do
          before do
            allow(droplets_handler).to receive(:delete).and_return(droplet)
          end

          it 'returns a 204 NO CONTENT' do
            response_code, response = droplets_controller.delete(droplet_guid)
            expect(response_code).to eq 204
            expect(response).to eq(nil)
          end
        end

        context 'when the user cannot access the droplet' do
          before do
            allow(droplets_handler).to receive(:delete).and_raise(DropletsHandler::Unauthorized)
          end

          it 'returns a 403 NotAuthorized error' do
            expect {
              droplets_controller.delete(droplet_guid)
            }.to raise_error do |error|
              expect(error.name).to eq 'NotAuthorized'
              expect(error.response_code).to eq 403
            end
          end
        end
      end
    end

    describe '#list' do
      let(:page) { 1 }
      let(:per_page) { 2 }
      let(:params) { { 'page' => page, 'per_page' => per_page } }
      let(:list_response) { 'list_response' }
      let(:expected_response) { 'im a response' }

      before do
        allow(droplet_presenter).to receive(:present_json_list).and_return(expected_response)
        allow(droplets_handler).to receive(:list).and_return(list_response)
      end

      it 'returns 200 and lists the apps' do
        response_code, response_body = droplets_controller.list

        expect(droplets_handler).to have_received(:list)
        expect(droplet_presenter).to have_received(:present_json_list).with(list_response, '/v3/droplets')
        expect(response_code).to eq(200)
        expect(response_body).to eq(expected_response)
      end
    end
  end
end
