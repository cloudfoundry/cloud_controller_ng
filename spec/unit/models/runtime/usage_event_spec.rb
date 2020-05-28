require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::UsageEvent, type: :model do
    it { is_expected.to have_timestamp_columns }

    context 'when there are usage events' do
      let!(:app_usage_event) { AppUsageEvent.make }
      let!(:service_usage_event) { ServiceUsageEvent.make }

      it 'contains all the usage events' do
        usage_events = VCAP::CloudController::UsageEvent.all.each_with_object({}) do |role, obj|
          obj[role.type] = role.guid
        end

        expect(usage_events['app']).to eq app_usage_event.guid
        expect(usage_events['service']).to eq service_usage_event.guid
      end
    end
  end
end
