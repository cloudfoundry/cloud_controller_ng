require 'spec_helper'
require 'cloud_controller/diego/failure_reason_sanitizer'

module VCAP::CloudController
  module Diego
    RSpec.describe FailureReasonSanitizer do
      describe '#sanitize' do
        context 'when the message is InsufficientResources' do
          it 'returns an InsufficientResources memory error' do
            staging_error = FailureReasonSanitizer.sanitize('insufficient resources: memory')
            expect(staging_error[:id]).to eq(CCMessages::INSUFFICIENT_RESOURCES)
            expect(staging_error[:message]).to eq('insufficient resources: memory')
          end

          it 'returns an InsufficientResources disk error' do
            staging_error = FailureReasonSanitizer.sanitize('insufficient resources: disk')
            expect(staging_error[:id]).to eq(CCMessages::INSUFFICIENT_RESOURCES)
            expect(staging_error[:message]).to eq('insufficient resources: disk')
          end
        end

        context 'when the message is NoCompatibleCell' do
          it 'returns a NoCompatibleCell' do
            staging_error = FailureReasonSanitizer.sanitize(DiegoErrors::CELL_MISMATCH_MESSAGE)
            expect(staging_error[:id]).to eq(CCMessages::NO_COMPATIBLE_CELL)
            expect(staging_error[:message]).to eq(DiegoErrors::CELL_MISMATCH_MESSAGE)
          end
        end

        context 'when the message is NoCompatibleCell Volume Drivers' do
          it 'returns a NoCompatibleCell' do
            staging_error = FailureReasonSanitizer.sanitize('found no compatible cell with volume drivers: [driver1]')
            expect(staging_error[:id]).to eq(CCMessages::NO_COMPATIBLE_CELL)
            expect(staging_error[:message]).to include(DiegoErrors::CELL_MISMATCH_MESSAGE)
          end
        end

        context 'when the message is NoCompatibleCell Placement tags' do
          it 'returns a NoCompatibleCell' do
            staging_error = FailureReasonSanitizer.sanitize('found no compatible cell with placement tags: [tag1, tag2]')
            expect(staging_error[:id]).to eq(CCMessages::NO_COMPATIBLE_CELL)
            expect(staging_error[:message]).to include(DiegoErrors::CELL_MISMATCH_MESSAGE)
          end
        end

        context 'when the message is CellCommunicationError' do
          it 'returns a CellCommunicationError' do
            staging_error = FailureReasonSanitizer.sanitize(DiegoErrors::CELL_COMMUNICATION_ERROR)
            expect(staging_error[:id]).to eq(CCMessages::CELL_COMMUNICATION_ERROR)
            expect(staging_error[:message]).to eq(DiegoErrors::CELL_COMMUNICATION_ERROR)
          end
        end

        context 'when the message is missing docker image URL' do
          it 'returns a StagingError' do
            staging_error = FailureReasonSanitizer.sanitize(DiegoErrors::MISSING_DOCKER_IMAGE_URL)
            expect(staging_error[:id]).to eq(CCMessages::STAGING_ERROR)
            expect(staging_error[:message]).to eq(DiegoErrors::MISSING_DOCKER_IMAGE_URL)
          end
        end

        context 'when the message is missing docker registry' do
          it 'returns a StagingError' do
            staging_error = FailureReasonSanitizer.sanitize(DiegoErrors::MISSING_DOCKER_REGISTRY)
            expect(staging_error[:id]).to eq(CCMessages::STAGING_ERROR)
            expect(staging_error[:message]).to eq(DiegoErrors::MISSING_DOCKER_REGISTRY)
          end
        end

        context 'any other message' do
          it 'returns a StagingError' do
            staging_error = FailureReasonSanitizer.sanitize('some-error')
            expect(staging_error[:id]).to eq(CCMessages::STAGING_ERROR)
            expect(staging_error[:message]).to eq('staging failed')
          end
        end
      end
    end
  end
end
