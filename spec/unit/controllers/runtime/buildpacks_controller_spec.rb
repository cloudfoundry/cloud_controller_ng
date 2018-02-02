require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::BuildpacksController do
    def ordered_buildpacks
      Buildpack.order(:position).map { |bp| [bp.name, bp.position] }
    end

    let(:user) { make_user }
    let(:req_body) { MultiJson.dump({ name: 'dynamic_test_buildpack', position: 1 }) }

    before { set_current_user_as_admin }

    describe 'Query Parameters' do
      it { expect(VCAP::CloudController::BuildpacksController).to be_queryable_by(:name) }
    end

    describe 'Attributes' do
      it do
        expect(VCAP::CloudController::BuildpacksController).to have_creatable_attributes({
          name:     { type: 'string', required: true },
          position: { type: 'integer', default: 0 },
          enabled:  { type: 'bool', default: true },
          locked:   { type: 'bool', default: false }
        })
      end

      it do
        expect(VCAP::CloudController::BuildpacksController).to have_updatable_attributes({
          name:     { type: 'string' },
          position: { type: 'integer' },
          enabled:  { type: 'bool' },
          locked:   { type: 'bool' }
        })
      end
    end

    # we are doing a negative test to fix a bug. The rest of the endpoint is tested with meta programming
    describe '#index' do
      before do
        2.times { Buildpack.make }
      end

      it 'does not include order-by in the next_url' do
        get '/v2/buildpacks?results-per-page=1'
        expect(parsed_response['next_url']).not_to match(/order-by=position/)
      end
    end

    describe '#create' do
      it 'can create a buildpack' do
        expect(Buildpack.count).to eq(0)
        post '/v2/buildpacks', req_body
        expect(last_response.status).to eq(201)

        expect(Buildpack.count).to eq(1)
        buildpack = Buildpack.first
        expect(buildpack.name).to eq('dynamic_test_buildpack')
        expect(buildpack.position).to eq(1)
      end

      it 'respects position param' do
        Buildpack.create(name: 'pre-existing-buildpack', position: 1)
        Buildpack.create(name: 'pre-existing-buildpack-2', position: 2)

        expect {
          post '/v2/buildpacks', MultiJson.dump({ name: 'new-buildpack', position: 2 })
        }.to change { ordered_buildpacks }.from(
          [['pre-existing-buildpack', 1], ['pre-existing-buildpack-2', 2]]
        ).to(
          [['pre-existing-buildpack', 1], ['new-buildpack', 2], ['pre-existing-buildpack-2', 3]]
        )
      end

      it 'returns duplicate name message correctly' do
        Buildpack.make(name: 'dynamic_test_buildpack')
        post '/v2/buildpacks', req_body
        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(290001)
        expect(Buildpack.count).to eq(1)
      end

      it 'returns buildpack invalid message correctly' do
        post '/v2/buildpacks', MultiJson.dump({ name: 'invalid_name!' })
        expect(last_response.status).to eq(400)
        expect(decoded_response['code']).to eq(290003)
        expect(Buildpack.count).to eq(0)
      end

      it 'returns 403 for non admins' do
        set_current_user(user)

        post '/v2/buildpacks', req_body
        expect(last_response.status).to eq(403)
        expect(Buildpack.count).to eq(0)
      end
    end

    describe '#update' do
      let!(:buildpack1) { VCAP::CloudController::Buildpack.create({ name: 'first_buildpack', key: 'xyz', filename: 'a', position: 1 }) }
      let!(:buildpack2) { VCAP::CloudController::Buildpack.create({ name: 'second_buildpack', key: 'xyz', filename: 'b', position: 2 }) }

      it 'can update the buildpack name' do
        set_current_user_as_admin

        put "/v2/buildpacks/#{buildpack2.guid}", '{"name": "second_buildpack_renamed"}'
        expect(buildpack2.reload.name).to eq('second_buildpack_renamed')
      end

      it 'can update the buildpack position' do
        set_current_user_as_admin

        put "/v2/buildpacks/#{buildpack2.guid}", '{"position": 1}'
        expect(buildpack2.reload.position).to eq(1)
        expect(ordered_buildpacks).to eq([
          ['second_buildpack', 1],
          ['first_buildpack', 2],
        ])
      end

      it 'returns NOT AUTHORIZED (403) for non admins' do
        set_current_user(user)

        put "/v2/buildpacks/#{buildpack2.guid}", '{}'
        expect(last_response.status).to eq(403)
      end
    end

    describe '#delete' do
      let!(:buildpack1) { VCAP::CloudController::Buildpack.create({ name: 'first_buildpack', key: 'xyz', position: 1 }) }

      it 'returns NOT AUTHORIZED (403) for non admins' do
        set_current_user(user)

        delete "/v2/buildpacks/#{buildpack1.guid}"
        expect(last_response.status).to eq(403)
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

      context 'with async false' do
        before do
          buildpack_blobstore = CloudController::DependencyLocator.instance.buildpack_blobstore
          buildpack_blobstore.cp_to_blobstore(Tempfile.new(['FAKE_BUILDPACK', '.zip']).path, buildpack1.key)
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
    end
  end
end
