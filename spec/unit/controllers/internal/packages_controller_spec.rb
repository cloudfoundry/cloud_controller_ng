require 'spec_helper'

module VCAP::CloudController
  module Internal
    RSpec.describe PackagesController do
      describe '#update' do
        let!(:package) {
          VCAP::CloudController::PackageModel.make(state: VCAP::CloudController::PackageModel::PENDING_STATE)
        }
        let(:request_body) do
          {
            'state'     => 'READY',
            'checksums' => [
              {
                'type'  => 'sha1',
                'value' => 'potato'
              },
              {
                'type'  => 'sha256',
                'value' => 'potatoest'
              }
            ],
            'error' => 'nothing bad'
          }.to_json
        end

        it 'returns a 204' do
          patch "/internal/v4/packages/#{package.guid}", request_body

          expect(last_response.status).to eq 204
        end

        it 'updates the package' do
          patch "/internal/v4/packages/#{package.guid}", request_body

          package.reload
          expect(package.state).to eq VCAP::CloudController::PackageModel::READY_STATE
          expect(package.package_hash).to eq('potato')
          expect(package.sha256_checksum).to eq('potatoest')
          expect(package.error).to eq('nothing bad')
        end

        context 'when the request is invalid' do
          let(:request_body) do
            {
              'state' => 'READY',
              'error' => 'nothing bad'
            }.to_json
          end

          it 'returns 422' do
            patch "/internal/v4/packages/#{package.guid}", request_body

            expect(last_response.status).to eq(422)
            expect(last_response.body).to include('UnprocessableEntity')
            expect(last_response.body).to include('Checksums required when setting state to READY')
          end
        end

        context 'when InvalidPackage is raised' do
          before do
            allow_any_instance_of(VCAP::CloudController::PackageUpdate).to receive(:update).
              and_raise(VCAP::CloudController::PackageUpdate::InvalidPackage.new('ya done goofed'))
          end

          it 'returns an UnprocessableEntity error' do
            patch "/internal/v4/packages/#{package.guid}", request_body

            expect(last_response.status).to eq 422
            expect(last_response.body).to include 'UnprocessableEntity'
            expect(last_response.body).to include 'ya done goofed'
          end
        end

        context 'when the request body is unparseable as JSON' do
          let(:request_body) { 'asdf' }

          it 'returns a MessageParseError error' do
            patch "/internal/v4/packages/#{package.guid}", request_body

            expect(last_response.status).to eq 400
            expect(last_response.body).to include 'MessageParseError'
            expect(last_response.body).to include 'Request invalid due to parse error'
          end
        end

        context 'when the package does not exist' do
          it 'returns NotFound error' do
            patch '/internal/v4/packages/idontexist', request_body

            expect(last_response.status).to eq(404)
            expect(last_response.body).to include('Package not found')
          end
        end
      end
    end
  end
end
