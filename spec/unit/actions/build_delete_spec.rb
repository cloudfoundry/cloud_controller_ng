require 'spec_helper'
require 'actions/staging_cancel'
require 'actions/build_delete'

module VCAP::CloudController
  RSpec.describe BuildDelete do
    subject(:build_delete) { BuildDelete.new(cancel_action) }
    let(:cancel_action) { instance_double(StagingCancel, cancel: nil) }

    describe '#delete' do
      let!(:build) { BuildModel.make }

      it 'deletes and cancels the build record' do
        build_delete.delete([build])

        expect(build.exists?).to eq(false), 'Expected build to not exist, but it does'
        expect(cancel_action).to have_received(:cancel).with([build])
      end
    end
  end
end
