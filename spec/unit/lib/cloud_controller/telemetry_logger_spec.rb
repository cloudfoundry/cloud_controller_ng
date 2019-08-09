require 'digest'
require 'spec_helper'
require 'cloud_controller/telemetry_logger'

module VCAP::CloudController
  RSpec.describe TelemetryLogger do
    let(:file) { Tempfile.new('telemetry.log') }

    before do
      TelemetryLogger.init(file.path)
      allow(VCAP::CloudController::TelemetryLogger).to receive(:emit).and_call_original
    end

    it 'logs job name, timestamp, and event, anonymizing by default' do
      TelemetryLogger.emit(
        'some-event',
        { 'bogus_key' => { 'value' => 'bogus_value' } })

      expect(JSON.parse(file.read)).to match({
        'telemetry-source' => 'cloud_controller_ng',
        'telemetry-time' => rfc3339,
        'some-event' => {
          'bogus_key' => Digest::SHA256.hexdigest('bogus_value')
        }
      })
    end

    it 'does not anonymize raw keys' do
      TelemetryLogger.emit('some-event',
                                 { 'anonymize_key' => { 'value' => 'anonymize_value' },
                                         'safe_key' => { 'value' => 'safe-value', 'raw' => true } })

      expect(JSON.parse(file.read)).to match({
        'telemetry-source' => 'cloud_controller_ng',
        'telemetry-time' => rfc3339,
        'some-event' => {
          'anonymize_key' => Digest::SHA256.hexdigest('anonymize_value'),
          'safe_key' => 'safe-value',
        }
      })
    end
  end
end
