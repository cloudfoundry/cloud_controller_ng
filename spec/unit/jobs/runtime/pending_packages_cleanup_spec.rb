require 'spec_helper'

module VCAP::CloudController
  module Jobs::Runtime
    RSpec.describe PendingPackagesCleanup do
      let(:expiration_in_seconds) { 5.minutes }

      subject(:cleanup_job) { PendingPackagesCleanup.new(expiration_in_seconds) }

      it { is_expected.to be_a_valid_job }

      it 'knows its job name' do
        expect(cleanup_job.job_name_in_configuration).to equal(:pending_packages)
      end

      describe '#perform' do
        context 'with packages which have been pending for too long' do
          let!(:app1) { AppFactory.make(package_pending_since: Time.now.utc - expiration_in_seconds - 1.minute) }
          let!(:app2) { AppFactory.make(package_pending_since: Time.now.utc - expiration_in_seconds - 2.minutes) }

          before do
            cleanup_job.perform
            app1.reload
            app2.reload
          end

          it 'marks packages as failed' do
            expect(app1.staging_failed?).to be_truthy
            expect(app2.staging_failed?).to be_truthy
          end

          it 'resets the pending_since timestamps' do
            expect(app1.package_pending_since).to be_nil
            expect(app2.package_pending_since).to be_nil
          end

          it 'sets the staging_failed_reason' do
            expect(app1.staging_failed_reason).to eq('StagingTimeExpired')
            expect(app2.staging_failed_reason).to eq('StagingTimeExpired')
          end
        end

        it "ignores apps that haven't been pending for too long" do
          app1 = AppFactory.make(package_pending_since: Time.now.utc - expiration_in_seconds + 1.minute)
          app2 = AppFactory.make(package_pending_since: Time.now.utc - expiration_in_seconds + 2.minutes)

          cleanup_job.perform
          app1.reload
          app2.reload

          expect(app1.staging_failed?).to be_falsey
          expect(app2.staging_failed?).to be_falsey
        end
      end
    end
  end
end
