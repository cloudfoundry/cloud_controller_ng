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

      it 'returns NOT AUTHORIZED (403) for non admins' do
        set_current_user(user)

        delete "/v2/buildpacks/#{buildpack1.guid}"
        expect(last_response.status).to eq(403)
      end

      context 'with sufficient permissions' do
        context 'with async false' do
          before do
            buildpack_blobstore = CloudController::DependencyLocator.instance.buildpack_blobstore
            buildpack_blobstore.cp_to_blobstore(Tempfile.new(['FAKE_BUILDPACK', '.zip']), buildpack1.key)
          end

          it 'destroys the buildpack entry and enqueues a job to delete the object from the blobstore' do
            expect(Delayed::Job.first).to be_nil
            delete "/v2/buildpacks/#{buildpack1.guid}"

            expect(last_response.status).to eq(204)
            expect(Buildpack.find(name: buildpack1.name)).to be_nil

            blobstore_delete_job = Delayed::Job.first
            expect(blobstore_delete_job).not_to be_nil
            expect(blobstore_delete_job.payload_object).to be_an_instance_of Jobs::Runtime::BlobstoreDelete
          end

          it 'does not fail if no buildpack bits were ever uploaded' do
            buildpack1.update_from_hash(key: nil)
            expect(buildpack1.key).to be_nil

            delete "/v2/buildpacks/#{buildpack1.guid}"
            expect(last_response.status).to eql(204)
            expect(Buildpack.find(name: buildpack1.name)).to be_nil
          end
        end

        context 'with async true' do
          it 'queues the buildpack deletion as a job' do
            expect(Delayed::Job.first).to be_nil
            delete "/v2/buildpacks/#{buildpack1.guid}?async=true"

            expect(last_response.status).to eq(202), "Expected 202, got #{last_response.status}, body: #{last_response.body}"

            buildpack_delete_job = Delayed::Job.first
            expect(buildpack_delete_job).not_to be_nil
            expect(buildpack_delete_job).to be_a_fully_wrapped_job_of Jobs::Runtime::BuildpackDelete
          end
        end
      end
    end
  end
end
