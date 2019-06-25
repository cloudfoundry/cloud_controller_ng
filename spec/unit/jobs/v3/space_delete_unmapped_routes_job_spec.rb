require 'spec_helper'
require 'jobs/v3/space_delete_unmapped_routes_job'
require 'actions/space_delete_unmapped_routes'

module VCAP::CloudController
  module Jobs::V3
    RSpec.describe SpaceDeleteUnmappedRoutesJob, job_context: :api do
      let!(:space) { Space.make }

      subject(:job) do
        SpaceDeleteUnmappedRoutesJob.new(space)
      end

      describe '#perform' do
        let!(:delete_action) { instance_double(VCAP::CloudController::SpaceDeleteUnmappedRoutes) }

        it 'runs the delete action on the space' do
          expect(VCAP::CloudController::SpaceDeleteUnmappedRoutes).to receive(:new).and_return(delete_action)
          expect(delete_action).to receive(:delete).with(space)

          job.perform
        end
      end
    end
  end
end
