require 'spec_helper'

module VCAP::CloudController
  module Jobs
    RSpec.describe AuditEventJob do
      let(:event_repository) { double(:event_repository) }
      let(:event_creation_method) { :record_service_creation_event }
      let(:event_type) { 'audit.service.create' }
      let(:model) { Service.make }
      let(:params) { {} }

      subject(:audit_event_job) do
        AuditEventJob.new(job, event_repository, event_creation_method, event_type, Service, model.guid, params)
      end
      let(:job) { double(:job, perform: 'fake-perform', max_attempts: 1, reschedule_at: Time.now) }

      describe '#reschedule_at' do
        it 'delegates to the handler' do
          time = Time.now
          attempts = 5
          expect(audit_event_job.reschedule_at(time, attempts)).to eq(job.reschedule_at(time, attempts))
        end
      end
    end
  end
end
