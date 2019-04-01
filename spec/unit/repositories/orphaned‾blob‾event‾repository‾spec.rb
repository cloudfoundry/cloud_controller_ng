require 'spec_helper'
require 'repositories/orphaned_blob_event_repository'

module VCAP::CloudController
  module Repositories
    RSpec.describe OrphanedBlobEventRepository do
      describe '#record_delete' do
        it 'creates a new blob.remove_orphan event' do
          event = OrphanedBlobEventRepository.record_delete('cc-buildpacks', 'so/me/blobstore-file')
          event.reload

          expect(event.type).to eq('blob.remove_orphan')
          expect(event.actor).to eq('system')
          expect(event.actor_type).to eq('system')
          expect(event.actor_name).to eq('system')
          expect(event.actor_username).to eq('system')
          expect(event.actee).to eq('cc-buildpacks/so/me/blobstore-file')
          expect(event.actee_type).to eq('blob')
          expect(event.actee_name).to eq('')
          expect(event.space_guid).to eq('')
          expect(event.organization_guid).to eq('')
          expect(event.metadata).to eq({})
        end
      end
    end
  end
end
