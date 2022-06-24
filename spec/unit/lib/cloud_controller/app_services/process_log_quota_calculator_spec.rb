require 'spec_helper'

module VCAP::CloudController
  RSpec.describe ProcessLogQuotaCalculator do
    subject { ProcessLogQuotaCalculator.new(process) }
    let(:process_guid) { 'i-do-not-match-the-app-guid' }
    let(:app_model) { AppModel.make }
    let(:process) { ProcessModel.make(guid: process_guid, app: app_model) }
    let(:stopped_state) { 'STOPPED' }
    let(:started_state) { 'STARTED' }

    describe '#additional_log_quota_requested' do
      context 'when the app state is STOPPED' do
        before do
          process.state = stopped_state
          process.save(validate: false)
        end

        it 'returns 0' do
          expect(subject.additional_log_quota_requested).to eq(0)
        end
      end

      context 'when the app state is STARTED' do
        let(:process) { ProcessModel.make(state: started_state, guid: process_guid, app: app_model) }

        context 'and the app is already in the db' do
          it 'raises ApplicationMissing if the app no longer exists in the db' do
            process.delete
            expect { subject.additional_log_quota_requested }.to raise_error(CloudController::Errors::ApplicationMissing)
          end

          context 'and it is changing from STOPPED' do
            before do
              db_app       = ProcessModel.find(guid: process.guid)
              db_app.state = stopped_state
              db_app.save(validate: false)
            end

            it 'returns the total requested log_quota' do
              process.state = started_state
              expect(subject.additional_log_quota_requested).to eq(subject.total_requested_log_quota)
            end
          end

          context 'and the app is already STARTED' do
            before do
              db_app       = ProcessModel.find(guid: process.guid)
              db_app.state = started_state
              db_app.save(validate: false)
            end

            it 'returns only newly requested log_quota' do
              expected = process.log_quota
              process.instances += 1

              expect(subject.additional_log_quota_requested).to eq(expected)
            end
          end
        end

        context 'and the app is new' do
          let(:process) { ProcessModel.new }
          before do
            process.instances = 1
            process.log_quota    = 100
          end

          it 'returns the total requested log_quota' do
            process.state = started_state
            expect(subject.additional_log_quota_requested).to eq(subject.total_requested_log_quota)
          end
        end
      end

      context 'and the app is requesting unlimited log quota' do
        let(:process) { ProcessModel.new }
        before do
          process.instances = 1
          process.log_quota = -1
        end

        it 'returns the fact that it is requesting unlimited quota' do
          process.state = started_state
          expect(subject.additional_log_quota_requested).to eq(-1)
        end
      end
    end

    describe '#total_requested_log_quota' do
      it 'returns requested log_quota * requested instances' do
        expected = process.log_quota * process.instances
        expect(subject.total_requested_log_quota).to eq(expected)
      end
    end

    describe '#currently_used_log_quota' do
      context 'when the app is new' do
        let(:process) { ProcessModel.new }
        it 'returns 0' do
          expect(subject.currently_used_log_quota).to eq(0)
        end
      end

      it 'raises ApplicationMissing if the app no longer exists in the db' do
        process.delete
        expect { subject.currently_used_log_quota }.to raise_error(CloudController::Errors::ApplicationMissing)
      end

      context 'when the app in the db is STOPPED' do
        it 'returns 0' do
          expect(subject.currently_used_log_quota).to eq(0)
        end
      end

      context 'when the app in the db is STARTED' do
        before do
          process.state = started_state
          process.save(validate: false)
        end

        it 'returns the log_quota * instances of the db row' do
          expected = process.instances * process.log_quota
          process.instances += 5
          process.log_quota += 100

          expect(subject.currently_used_log_quota).to eq(expected)
        end
      end
    end
  end
end
