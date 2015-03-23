require 'spec_helper'

module VCAP::CloudController
  describe AppDiskQuotaCalculator do
    subject { described_class.new(app) }
    let(:app) { AppFactory.make(package_hash: 'made-up-hash') }
    let(:stopped_state) { 'STOPPED' }
    let(:started_state) { 'STARTED' }

    describe '#additional_disk_quota_requested' do
      context 'when the app state is STOPPED' do
        before do
          app.state = stopped_state
          app.save(validate: false)
        end

        it 'returns 0' do
          expect(subject.additional_disk_quota_requested).to eq(0)
        end
      end

      context 'when the app state is STARTED' do
        let(:app) { AppFactory.make(state: started_state, package_hash: 'made-up-hash') }

        context 'and the app is already in the db' do
          it 'raises ApplicationMissing if the app no longer exists in the db' do
            app.delete
            expect { subject.additional_disk_quota_requested }.to raise_error(Errors::ApplicationMissing)
          end

          context 'and it is changing from STOPPED' do
            before do
              db_app       = App.find(guid: app.guid)
              db_app.state = stopped_state
              db_app.save(validate: false)
            end

            it 'returns the total requested disk_quota' do
              app.state = started_state
              expect(subject.additional_disk_quota_requested).to eq(subject.total_requested_disk_quota)
            end
          end

          context 'and it has changed to STARTED' do
            before do
              db_app       = App.find(guid: app.guid)
              db_app.state = started_state
              db_app.save(validate: false)
            end

            it 'returns only newly requested disk_quota' do
              expected      = app.disk_quota
              app.instances += 1

              expect(subject.additional_disk_quota_requested).to eq(expected)
            end
          end
        end

        context 'and the app is new' do
          let(:app) { App.new }
          before do
            app.instances = 1
            app.disk_quota    = 100
          end

          it 'returns the total requested disk_quota
          ' do
            app.state = started_state
            expect(subject.additional_disk_quota_requested).to eq(subject.total_requested_disk_quota)
          end
        end
      end
    end

    describe '#total_requested_disk_quota' do
      it 'returns requested disk_quota * requested instances' do
        expected = app.disk_quota * app.instances
        expect(subject.total_requested_disk_quota).to eq(expected)
      end
    end

    describe '#currently_used_disk_quota' do
      context 'when the app is new' do
        let(:app) { App.new }
        it 'returns 0' do
          expect(subject.currently_used_disk_quota).to eq(0)
        end
      end

      it 'raises ApplicationMissing if the app no longer exists in the db' do
        app.delete
        expect { subject.currently_used_disk_quota }.to raise_error(Errors::ApplicationMissing)
      end

      context 'when the app in the db is STOPPED' do
        it 'returns 0' do
          expect(subject.currently_used_disk_quota).to eq(0)
        end
      end

      context 'when the app in the db is STARTED' do
        before do
          app.state = started_state
          app.save(validate: false)
        end

        it 'returns the disk_quota * instances of the db row' do
          expected      = app.instances * app.disk_quota
          app.instances += 5
          app.disk_quota += 100

          expect(subject.currently_used_disk_quota).to eq(expected)
        end
      end
    end
  end
end
