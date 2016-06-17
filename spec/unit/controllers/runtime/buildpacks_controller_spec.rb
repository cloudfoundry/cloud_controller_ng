require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::BuildpacksController do
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

    before do
      set_current_user_as_admin
    end

    describe 'create' do
      it 'returns 403 for non admins' do
        set_current_user(user)

        post '/v2/buildpacks', req_body
        expect(last_response.status).to eq(403)
      end

      it 'returns duplicate name message correctly' do
        Buildpack.make(name: 'dynamic_test_buildpack')
        post '/v2/buildpacks', req_body
        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(290001)
      end

      it 'returns buildpack invalid message correctly' do
        post '/v2/buildpacks', MultiJson.dump({ name: 'invalid_name!' })
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
        set_current_user(user)

        put "/v2/buildpacks/#{buildpack2.guid}", '{}'
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
        set_current_user(user)

        delete "/v2/buildpacks/#{buildpack1.guid}"
        expect(last_response.status).to eq(403)
      end

      context 'create a default buildpack' do
        it 'destroys the buildpack key in the blobstore' do
          buildpack_blobstore = CloudController::DependencyLocator.instance.buildpack_blobstore
          buildpack_blobstore.cp_to_blobstore(Tempfile.new(['FAKE_BUILDPACK', '.zip']), buildpack1.key)

          expect { delete "/v2/buildpacks/#{buildpack1.guid}" }.to change {
            buildpack_blobstore.exists?(buildpack1.key)
          }.from(true).to(false)

          expect(last_response.status).to eq(204)

          expect(Buildpack.find(name: buildpack1.name)).to be_nil
        end

        it 'does not fail if no buildpack bits were ever uploaded' do
          buildpack1.update_from_hash(key: nil)
          expect(buildpack1.key).to be_nil

          delete "/v2/buildpacks/#{buildpack1.guid}"
          expect(last_response.status).to eql(204)
          expect(Buildpack.find(name: buildpack1.name)).to be_nil
        end
      end
    end
  end
end
