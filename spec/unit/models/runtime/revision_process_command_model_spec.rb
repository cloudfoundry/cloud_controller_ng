require 'spec_helper'

module VCAP::CloudController
  RSpec.describe RevisionProcessCommandModel do
    describe 'revision_process_command_model #around_save' do
      let(:revision) { create(:revision_model) }
      let!(:revision_process_command) { create(:revision_process_command_model, revision_guid: revision.guid, process_type: 'worker') }

      it 'raises validation error on unique constraint violation' do
        expect do
          create(:revision_process_command_model, revision_guid: revision_process_command.revision_guid,
                                                  process_type: revision_process_command.process_type)
        end.to raise_error(Sequel::ValidationFailed) { |error|
          expect(error.message).to include('already exists for given revision')
        }
      end

      it 'raises the original error on other unique constraint violations' do
        expect do
          create(:revision_process_command_model, guid: revision_process_command.guid, revision_guid: revision_process_command.revision_guid, process_type: 'worker')
        end.to raise_error(Sequel::UniqueConstraintViolation)
      end
    end
  end
end
