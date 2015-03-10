require 'spec_helper'

module VCAP::CloudController
  describe VCAP::CloudController::SnapshotsController do
    describe 'Attributes' do
      it do
        expect(described_class).to have_creatable_attributes({
          name: { type: 'string', required: true },
          service_instance_guid: { type: 'string', required: true }
        })
      end

      it do
        expect(described_class).to have_updatable_attributes({
          name: { type: 'string' },
          service_instance_guid: { type: 'string' }
        })
      end
    end

    let(:service_instance) do
      service = Service.make(:v1,
        url: 'http://horsemeat.com',
      )
      ManagedServiceInstance.make(
        service_plan: ServicePlan.make(service: service),
      )
    end

    describe 'POST', '/v2/snapshots' do
      let(:new_name) { 'new name' }
      let(:snapshot_created_at) { Time.now.utc.to_s }
      let(:new_snapshot) { VCAP::Services::Api::SnapshotV2.new(snapshot_id: '1', name: 'foo', state: 'empty', size: 0, created_time: snapshot_created_at) }
      let(:payload) {
        MultiJson.dump(
          service_instance_guid: service_instance.guid,
          name: new_name
        )
      }

      before do
        url = "http://horsemeat.com/gateway/v2/configurations/#{service_instance.gateway_name}/snapshots"
        stub_request(:post, url).to_return(status: 201, body: new_snapshot.encode)
      end

      context 'for an unauthenticated user' do
        it 'requires authentication' do
          post '/v2/snapshots', payload, json_headers({})
          expect(last_response.status).to eq(401)
          expect(a_request(:any, %r{http://horsemeat.com})).not_to have_been_made
        end
      end

      context 'for an admin' do
        it 'should allow them to create a snapshot' do
          post '/v2/snapshots', payload, json_headers(admin_headers)
          expect(last_response.status).to eq(201)
        end
      end

      context 'for a developer not in the space' do
        let(:another_space) { Space.make }
        let(:developer) { make_developer_for_space(another_space) }
        it 'denies access' do
          post '/v2/snapshots', payload, json_headers(headers_for(developer))
          expect(last_response.status).to eq 403
          expect(a_request(:any, %r{http://horsemeat.com})).not_to have_been_made
        end
      end

      context 'once authenticated' do
        let(:developer) { make_developer_for_space(service_instance.space) }

        context 'without service_instance_id' do
          it 'returns a 400 status code' do
            post '/v2/snapshots', '{}', json_headers(headers_for(developer))
            expect(last_response.status).to eq(400)
          end

          it 'does not create a snapshot' do
            expect_any_instance_of(ManagedServiceInstance).not_to receive(:create_snapshot)
            post '/v2/snapshots', '{}', json_headers(headers_for(developer))
            expect(a_request(:any, %r{http://horsemeat.com})).not_to have_been_made
          end
        end

        context 'given nil name' do
          let(:new_name) { nil }

          it 'returns a 400 status code and does not create a snapshot' do
            expect_any_instance_of(ManagedServiceInstance).not_to receive(:create_snapshot)
            post '/v2/snapshots', payload, json_headers(headers_for(developer))
            expect(last_response.status).to eq(400)
            expect(a_request(:any, %r{http://horsemeat.com})).not_to have_been_made
          end
        end

        context 'with a blank name' do
          let(:new_name) { '' }
          it 'returns a 400 status code and does not create a snapshot' do
            post '/v2/snapshots', payload, json_headers(headers_for(developer))
            expect(last_response.status).to eq(400)
            expect(a_request(:any, %r{http://horsemeat.com})).not_to have_been_made
          end
        end

        it 'invokes create_snapshot on the corresponding service instance' do
          expect(ManagedServiceInstance).to receive(:find).
            with(guid: service_instance.guid).
            and_return(service_instance)
          expect(service_instance).to receive(:create_snapshot).
            with(new_name).
            and_return(VCAP::Services::Api::SnapshotV2.new)

          post '/v2/snapshots', payload, json_headers(headers_for(developer))
        end

        context 'when the gateway successfully creates the snapshot' do
          it 'returns the details of the new snapshot' do
            post '/v2/snapshots', payload, json_headers(headers_for(developer))
            expect(last_response.status).to eq(201)
            snapguid = "#{service_instance.guid}_1"
            expect(decoded_response['metadata']).to eq({
              'guid' => snapguid,
              'url' => "/v2/snapshots/#{snapguid}",
              'created_at' => snapshot_created_at,
              'updated_at' => nil
            })
            expect(decoded_response['entity']).to include({ 'state' => 'empty', 'name' => 'foo' })
          end
        end
      end
    end

    describe 'GET /v2/service_instances/:service_id/snapshots' do
      let(:snapshots_url) {  "/v2/service_instances/#{service_instance.guid}/snapshots" }

      it 'requires authentication' do
        get snapshots_url
        expect(last_response.status).to eq(401)
        expect(a_request(:any, %r{http://horsemeat.com})).not_to have_been_made
      end

      context 'once authenticated' do
        let(:developer) { make_developer_for_space(service_instance.space) }
        before do
          allow(ManagedServiceInstance).to receive(:find).
            with(guid: service_instance.guid).
            and_return(service_instance)
        end

        it 'returns an empty list' do
          allow(service_instance).to receive(:enum_snapshots).and_return []
          get snapshots_url, {}, headers_for(developer)
          expect(last_response.status).to eq(200)
          expect(decoded_response['resources']).to eq([])
        end

        it 'returns an list of snapshots' do
          created_time = Time.now.utc.to_s
          expect(service_instance).to receive(:enum_snapshots) do
            [VCAP::Services::Api::SnapshotV2.new(
              'snapshot_id' => '1234',
              'name' => 'something',
              'state' => 'empty',
              'size' => 0,
              'created_time' => created_time)
            ]
          end
          get snapshots_url, {}, headers_for(developer)
          expect(decoded_response).to eq({
            'total_results' => 1,
            'total_pages' => 1,
            'prev_url' => nil,
            'next_url' => nil,
            'resources' => [
              {
                'metadata' => {
                  'guid' => "#{service_instance.guid}_1234",
                  'url' => "/v2/snapshots/#{service_instance.guid}_1234",
                  'created_at' => created_time,
                  'updated_at' => nil
                },
                'entity' => {
                  'snapshot_id' => '1234', 'name' => 'something', 'state' => 'empty', 'size' => 0, 'created_time' => created_time
                }
              }
            ]
          })
          expect(last_response.status).to eq(200)
        end

        it 'checks for permission to read the service' do
          another_developer   =  make_developer_for_space(Space.make)
          get snapshots_url, {}, headers_for(another_developer)
          expect(last_response.status).to eq(403)
        end
      end
    end
  end
end
