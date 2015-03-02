require 'spec_helper'

module VCAP::CloudController
  describe VCAP::CloudController::BuildpacksController do
    describe 'Query Parameters' do
      it { expect(described_class).to be_queryable_by(:name) }
    end

    describe 'Attributes' do
      it do
        expect(described_class).to have_creatable_attributes({
          name: { type: 'string', required: true },
          position: { type: 'integer', default: 0 },
          enabled: { type: 'bool', default: true },
          locked: { type: 'bool', default: false }
        })
      end

      it do
        expect(described_class).to have_updatable_attributes({
          name: { type: 'string' },
          position: { type: 'integer' },
          enabled: { type: 'bool' },
          locked: { type: 'bool' }
        })
      end
    end

    let(:user) { make_user }
    let(:req_body) { MultiJson.dump({ name: 'dynamic_test_buildpack' }) }

    describe 'create' do
      it 'returns 403 for non admins' do
        post '/v2/buildpacks', req_body, headers_for(user)
        expect(last_response.status).to eq(403)
      end

      it 'returns duplicate name message correctly' do
        Buildpack.make(name: 'dynamic_test_buildpack')
        post '/v2/buildpacks', req_body, admin_headers
        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(290001)
      end

      it 'returns buildpack invalid message correctly' do
        post '/v2/buildpacks', MultiJson.dump({ name: 'invalid_name!' }), admin_headers
        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(290003)
      end
    end

    context 'UPDATE' do
      let!(:buildpack1) do
        should_have_been_1 = 5
        VCAP::CloudController::Buildpack.create({ name: 'first_buildpack', key: 'xyz', filename: 'a', position: should_have_been_1 })
      end

      let!(:buildpack2) do
        should_have_been_2 = 10
        VCAP::CloudController::Buildpack.create({ name: 'second_buildpack', key: 'xyz', filename: 'b', position: should_have_been_2 })
      end

      it 'returns NOT AUTHORIZED (403) for non admins' do
        put "/v2/buildpacks/#{buildpack2.guid}", '{}', headers_for(user)
        expect(last_response.status).to eq(403)
      end
    end

    context 'DELETE' do
      let!(:buildpack1) do
        VCAP::CloudController::Buildpack.create({ name: 'first_buildpack', key: 'xyz', position: 1 })
      end

      before { Delayed::Worker.delay_jobs = false }
      after { Delayed::Worker.delay_jobs = true }

      it 'returns NOT AUTHORIZED (403) for non admins' do
        delete "/v2/buildpacks/#{buildpack1.guid}", '{}', headers_for(user)
        expect(last_response.status).to eq(403)
      end

      context 'create a default buildpack' do
        it 'destroys the buildpack key in the blobstore' do
          buildpack_blobstore = CloudController::DependencyLocator.instance.buildpack_blobstore
          buildpack_blobstore.cp_to_blobstore(Tempfile.new(['FAKE_BUILDPACK', '.zip']), buildpack1.key)

          expect { delete "/v2/buildpacks/#{buildpack1.guid}", {}, admin_headers }.to change {
            buildpack_blobstore.exists?(buildpack1.key)
          }.from(true).to(false)

          expect(last_response.status).to eq(204)

          expect(Buildpack.find(name: buildpack1.name)).to be_nil
        end

        it 'does not fail if no buildpack bits were ever uploaded' do
          buildpack1.update_from_hash(key: nil)
          expect(buildpack1.key).to be_nil

          delete "/v2/buildpacks/#{buildpack1.guid}", {}, admin_headers
          expect(last_response.status).to eql(204)
          expect(Buildpack.find(name: buildpack1.name)).to be_nil
        end
      end
    end

    describe 'audit events' do
      it 'logs audit.buildpack.delete-request when deleting a buildpack' do
        buildpack = Buildpack.make(name: 'my-buildpack')
        buildpack_guid = buildpack.guid
        delete "/v2/buildpacks/#{buildpack_guid}", '', json_headers(admin_headers)

        expect(last_response.status).to eq(204)

        event = Event.find(type: 'audit.buildpack.delete-request', actee: buildpack_guid)
        expect(event).not_to be_nil
        expect(event.actee).to eq(buildpack_guid)
        expect(event.actee_name).to eq(buildpack.name)
        expect(event.actor_name).to eq(SecurityContext.current_user_email)
      end
    end
  end
end
