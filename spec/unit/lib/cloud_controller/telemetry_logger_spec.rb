require 'spec_helper'
require 'cloud_controller/telemetry_logger'

module VCAP::CloudController
  RSpec.describe TelemetryLogger do
    let(:file) { Tempfile.new('telemetry.log') }

    before do
      TelemetryLogger.init(ActiveSupport::Logger.new(file.path))
    end

    it 'logs job name, timestamp, and event, anonymizing by default' do
      TelemetryLogger.v3_emit(
        'some-event',
        { 'bogus_key' => 'bogus_value' }
      )

      expect(JSON.parse(file.read)).to match({
        'telemetry-source' => 'cloud_controller_ng',
        'telemetry-time' => rfc3339,
        'some-event' => {
          'api-version' => 'v3',
          'bogus_key' => Digest::SHA256.hexdigest('bogus_value')
        }
      })
    end

    it 'does not anonymize raw keys' do
      TelemetryLogger.v3_emit(
        'some-event',
         { 'anonymize_key' => 'anonymize_value' },
         { 'safe_key' => 'safe-value' }
      )

      expect(JSON.parse(file.read)).to match({
        'telemetry-source' => 'cloud_controller_ng',
        'telemetry-time' => rfc3339,
        'some-event' => {
          'api-version' => 'v3',
          'anonymize_key' => Digest::SHA256.hexdigest('anonymize_value'),
          'safe_key' => 'safe-value',
        }
      })
    end

    it 'converts specified raw fields to int' do
      TelemetryLogger.v3_emit(
        'some-event',
        {},
        { 'memory-in-mb' => '1234' }
      )

      expect(JSON.parse(file.read)).to match({
        'telemetry-source' => 'cloud_controller_ng',
        'telemetry-time' => rfc3339,
        'some-event' => {
          'api-version' => 'v3',
          'memory-in-mb' => 1234
        }
      })
    end

    describe 'v2 emit' do
      it 'logs v2 api version' do
        TelemetryLogger.v2_emit(
          'some-event',
          { 'key' => 'value' },
        )

        expect(JSON.parse(file.read)).to match({
          'telemetry-source' => 'cloud_controller_ng',
          'telemetry-time' => rfc3339,
          'some-event' => {
            'key' => Digest::SHA256.hexdigest('value'),
            'api-version' => 'v2',
          }
        })
      end
    end
    describe 'v3 emit' do
      it 'logs v3 api version' do
        TelemetryLogger.v3_emit(
          'some-event',
          { 'key' => 'value' },
        )

        expect(JSON.parse(file.read)).to match({
          'telemetry-source' => 'cloud_controller_ng',
          'telemetry-time' => rfc3339,
          'some-event' => {
            'key' => Digest::SHA256.hexdigest('value'),
            'api-version' => 'v3',
          }
        })
      end
    end
    describe 'internal emit' do
      it 'logs version as internal api' do
        TelemetryLogger.internal_emit(
          'some-event',
          { 'key' => 'value' },
        )

        expect(JSON.parse(file.read)).to match({
          'telemetry-source' => 'cloud_controller_ng',
          'telemetry-time' => rfc3339,
          'some-event' => {
            'key' => Digest::SHA256.hexdigest('value'),
            'api-version' => 'internal',
          }
        })
      end
    end
  end
end
