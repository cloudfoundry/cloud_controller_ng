require 'spec_helper'

module VCAP::CloudController
  RSpec.describe AppMemoryCalculator do
    subject { described_class.new(process) }
    let(:process) { ProcessModelFactory.make }
    let(:stopped_state) { 'STOPPED' }
    let(:started_state) { 'STARTED' }

    describe '#additional_memory_requested' do
      context 'when the app state is STOPPED' do
        before do
          process.state = stopped_state
          process.save(validate: false)
        end

        it 'returns 0' do
          expect(subject.additional_memory_requested).to eq(0)
        end
      end

      context 'when the app state is STARTED' do
        let(:process) { ProcessModelFactory.make(state: started_state) }

        context 'and the app is already in the db' do
          it 'raises ApplicationMissing if the app no longer exists in the db' do
            process.delete
            expect { subject.additional_memory_requested }.to raise_error(CloudController::Errors::ApplicationMissing)
          end

          context 'and it is changing from STOPPED' do
            before do
              db_app       = ProcessModel.find(guid: process.guid)
              db_app.state = stopped_state
              db_app.save(validate: false)
            end

            it 'returns the total requested memory' do
              process.state = started_state
              expect(subject.additional_memory_requested).to eq(subject.total_requested_memory)
            end
          end

          context 'and the app is already STARTED' do
            before do
              db_app       = ProcessModel.find(guid: process.guid)
              db_app.state = started_state
              db_app.save(validate: false)
            end

            it 'returns only newly requested memory' do
              expected = process.memory
              process.instances += 1

              expect(subject.additional_memory_requested).to eq(expected)
            end
          end
        end

        context 'and the app is new' do
          let(:process) { ProcessModel.new }
          before do
            process.instances = 1
            process.memory    = 100
          end

          it 'returns the total requested memory' do
            process.state = started_state
            expect(subject.additional_memory_requested).to eq(subject.total_requested_memory)
          end
        end
      end
    end

    describe '#total_requested_memory' do
      it 'returns requested memory * requested instances' do
        expected = process.memory * process.instances
        expect(subject.total_requested_memory).to eq(expected)
      end
    end

    describe '#currently_used_memory' do
      context 'when the app is new' do
        let(:process) { ProcessModel.new }
        it 'returns 0' do
          expect(subject.currently_used_memory).to eq(0)
        end
      end

      it 'raises ApplicationMissing if the app no longer exists in the db' do
        process.delete
        expect { subject.currently_used_memory }.to raise_error(CloudController::Errors::ApplicationMissing)
      end

      context 'when the app in the db is STOPPED' do
        it 'returns 0' do
          expect(subject.currently_used_memory).to eq(0)
        end
      end

      context 'when the app in the db is STARTED' do
        before do
          process.state = started_state
          process.save(validate: false)
        end

        it 'returns the memory * instances of the db row' do
          expected = process.instances * process.memory
          process.instances += 5
          process.memory += 100

          expect(subject.currently_used_memory).to eq(expected)
        end
      end
    end
  end
end
