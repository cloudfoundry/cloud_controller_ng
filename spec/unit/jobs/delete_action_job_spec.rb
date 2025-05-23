require 'spec_helper'

module VCAP::CloudController
  module Jobs
    RSpec.shared_examples 'a delete action handling external deletion' do
      before do
        allow_any_instance_of(resource.class).to receive(:destroy).and_wrap_original do |original_method, *args|
          Sequel::Model.db.run("DELETE FROM #{resource.class.table_name} WHERE id = #{resource.id}") # Simulate external deletion
          original_method.call(*args)
        end
      end

      it 'still attempts to delete the resource even if it was already deleted externally' do
        expect { delete_job.perform }.not_to raise_error
      end
    end

    RSpec.describe DeleteActionJob, job_context: :worker do
      let(:user) { User.make(admin: true) }
      let(:delete_action) { instance_double(SpaceDelete, delete: []) }
      let(:space) { Space.make(name: Sham.guid) }

      subject(:job) { DeleteActionJob.new(Space, space.guid, delete_action) }

      it { is_expected.to be_a_valid_job }

      it 'knows its job name' do
        expect(job.job_name_in_configuration).to equal(:delete_action_job)
      end

      it 'calls the delete action' do
        job.perform

        expect(delete_action).to have_received(:delete).with(Space.where(guid: space.guid))
      end

      describe 'the timeout error to use when the job times out' do
        context 'when the delete action has a timeout error' do
          let(:error) { StandardError.new('foo') }
          let(:delete_action) { instance_double(SpaceDelete, delete: [], timeout_error: error) }

          it 'returns the custom timeout error' do
            expect(job.timeout_error).to eq(error)
          end
        end

        context 'when the delete action does not have a timeout error' do
          let(:delete_action) { instance_double(SpaceDelete, delete: []) }

          it 'returns a generic timeout error' do
            expect(job.timeout_error).to be_a(CloudController::Errors::ApiError)
            expect(job.timeout_error.name).to eq('JobTimeout')
          end
        end
      end

      context 'when the action implements can_return_warnings?' do
        context 'when can_return_warnings? is false' do
          let(:delete_action) { instance_double(ServiceInstanceDelete, delete: [], can_return_warnings?: false) }

          it 'does not expect warnings' do
            expect do
              job.perform
            end.not_to raise_error
          end
        end

        context 'when the delete action returns warnings' do
          let(:delete_action) { instance_double(ServiceInstanceDelete, delete: [[], %w[warning-1 warning-2]], can_return_warnings?: true) }

          it 'returns the warnings' do
            expect(job.perform).to match_array(%w[warning-1 warning-2])
          end
        end
      end

      context 'when the delete action fails' do
        let(:delete_action) { instance_double(SpaceDelete, delete: errors) }
        let(:error) { StandardError.new('oops') }

        context 'with a single error' do
          let(:errors) { [error] }

          it 'raises only that error' do
            expect { job.perform }.to raise_error(error)
          end
        end

        context 'with multiple errors' do
          let(:errors) { [error, StandardError.new('argh')] }

          it 'raises the first error' do
            expect { job.perform }.to raise_error(error)
          end
        end

        context 'raising an error' do
          let(:errors) { nil }

          before do
            allow(delete_action).to receive(:delete).and_raise(error)
          end

          it 'raises the error' do
            expect { job.perform }.to raise_error(error)
          end
        end
      end

      describe '#resource_type' do
        it 'returns a display name for the resource being deleted' do
          expect(job.resource_type).to eq('space')
        end

        context 'when the class contains the word Model' do
          subject(:job) { DeleteActionJob.new(DropletModel, 'unused', nil) }

          it 'returns a display name without the word Model' do
            expect(job.resource_type).to eq('droplet')
          end
        end
      end

      describe '#display_name' do
        it 'returns a display name for this action' do
          expect(job.display_name).to eq('space.delete')
        end

        context 'when the class contains the word Model' do
          subject(:job) { DeleteActionJob.new(DropletModel, 'unused', nil) }

          it 'returns a display name without the word Model' do
            expect(job.display_name).to eq('droplet.delete')
          end
        end
      end

      describe '#resource_guid' do
        it 'returns the given resource guid' do
          expect(job.resource_guid).to eq(space.guid)
        end
      end

      context 'when the resource is deleted externally before destroy' do
        it_behaves_like 'a delete action handling external deletion' do
          let(:resource) { PackageModel.make }
          let(:delete_action) { PackageDelete.new(nil) }
          let(:delete_job) { DeleteActionJob.new(PackageModel, resource.guid, delete_action) }
        end

        it_behaves_like 'a delete action handling external deletion' do
          let(:resource) { Space.make }
          let(:delete_action) { SpaceDelete.new(nil, nil) }
          let(:delete_job) { DeleteActionJob.new(Space, resource.guid, delete_action) }
        end

        it_behaves_like 'a delete action handling external deletion' do
          let(:resource) { Route.make }
          let(:delete_action) { RouteDeleteAction.new(nil) }
          let(:delete_job) { DeleteActionJob.new(Route, resource.guid, delete_action) }
        end

        it_behaves_like 'a delete action handling external deletion' do
          let(:resource) { User.make }
          let(:delete_action) { UserDeleteAction.new }
          let(:delete_job) { DeleteActionJob.new(User, resource.guid, delete_action) }
        end
      end
    end
  end
end
