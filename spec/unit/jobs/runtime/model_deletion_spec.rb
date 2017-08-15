require 'spec_helper'
require 'jobs/runtime/model_deletion'
require 'models/runtime/process_model'
require 'models/runtime/space'

module VCAP::CloudController
  module Jobs::Runtime
    RSpec.describe ModelDeletion do
      let!(:space) { Space.make }
      subject(:job) { ModelDeletion.new(Space, space.guid) }

      it { is_expected.to be_a_valid_job }

      describe '#perform' do
        context 'deleting a space' do
          it 'can delete the space' do
            expect { job.perform }.to change { Space.count }.by(-1)
          end
        end

        context 'deleting an app' do
          let!(:process) { ProcessModelFactory.make(space: space) }
          subject(:job) { ModelDeletion.new(ProcessModel, process.guid) }

          it 'can delete an app' do
            expect {
              job.perform
            }.to change {
              ProcessModel.count
            }.by(-1)
          end
        end

        context 'when nothing matches the given guid' do
          subject(:job) { ModelDeletion.new(Space, 'not_a_guid_at_all') }

          it 'just returns' do
            expect {
              job.perform
            }.not_to change { Space.count }
          end
        end

        it 'knows its job name' do
          expect(job.job_name_in_configuration).to equal(:model_deletion)
        end
      end
    end
  end
end
