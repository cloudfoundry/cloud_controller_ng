require 'spec_helper'
require 'messages/route_options_message'

module VCAP::CloudController
  RSpec.describe RouteOptionsMessage do
    describe 'basic validations' do
      it 'successfully validates round-robin load-balancing algorithm' do
        message = RouteOptionsMessage.new({ loadbalancing: 'round-robin' })
        expect(message).to be_valid
      end

      it 'successfully validates least-connection load-balancing algorithm' do
        message = RouteOptionsMessage.new({ loadbalancing: 'least-connection' })
        expect(message).to be_valid
      end

      it 'successfully validates empty options' do
        message = RouteOptionsMessage.new({})
        expect(message).to be_valid
      end

      it 'successfully validates empty load balancer' do
        message = RouteOptionsMessage.new({ loadbalancing: nil })
        expect(message).to be_valid
      end

      it 'adds invalid load balancer error message' do
        message = RouteOptionsMessage.new({ loadbalancing: 'donuts' })
        expect(message).not_to be_valid
        expect(message.errors_on(:loadbalancing)).to include("must be one of 'round-robin, least-connection' if present")
      end

      it 'adds invalid field error message' do
        message = RouteOptionsMessage.new({ cookies: 'round-robin' })
        expect(message).not_to be_valid
        expect(message.errors_on(:base)).to include("Unknown field(s): 'cookies'")
      end
    end

    describe 'allowed_sources validations' do
      context 'when app_to_app_mtls_routing feature flag is disabled' do
        it 'does not allow allowed_sources option' do
          message = RouteOptionsMessage.new({ allowed_sources: { apps: ['app-guid-1'] } })
          expect(message).not_to be_valid
          expect(message.errors_on(:base)).to include("Unknown field(s): 'allowed_sources'")
        end
      end

      context 'when app_to_app_mtls_routing feature flag is enabled' do
        before do
          VCAP::CloudController::FeatureFlag.make(name: 'app_to_app_mtls_routing', enabled: true)
        end

        describe 'structure validation' do
          it 'allows valid allowed_sources with apps' do
            app = AppModel.make
            message = RouteOptionsMessage.new({ allowed_sources: { 'apps' => [app.guid] } })
            expect(message).to be_valid
          end

          it 'allows valid allowed_sources with spaces' do
            space = Space.make
            message = RouteOptionsMessage.new({ allowed_sources: { 'spaces' => [space.guid] } })
            expect(message).to be_valid
          end

          it 'allows valid allowed_sources with orgs' do
            org = Organization.make
            message = RouteOptionsMessage.new({ allowed_sources: { 'orgs' => [org.guid] } })
            expect(message).to be_valid
          end

          it 'allows valid allowed_sources with any: true' do
            message = RouteOptionsMessage.new({ allowed_sources: { 'any' => true } })
            expect(message).to be_valid
          end

          it 'allows valid allowed_sources with any: false' do
            message = RouteOptionsMessage.new({ allowed_sources: { 'any' => false } })
            expect(message).to be_valid
          end

          it 'allows empty allowed_sources object' do
            message = RouteOptionsMessage.new({ allowed_sources: {} })
            expect(message).to be_valid
          end

          it 'does not allow non-object allowed_sources' do
            message = RouteOptionsMessage.new({ allowed_sources: 'invalid' })
            expect(message).not_to be_valid
            expect(message.errors_on(:allowed_sources)).to include('must be an object')
          end

          it 'does not allow array allowed_sources' do
            message = RouteOptionsMessage.new({ allowed_sources: ['app-guid-1'] })
            expect(message).not_to be_valid
            expect(message.errors_on(:allowed_sources)).to include('must be an object')
          end

          it 'does not allow invalid keys in allowed_sources' do
            message = RouteOptionsMessage.new({ allowed_sources: { 'invalid_key' => 'value' } })
            expect(message).not_to be_valid
            expect(message.errors_on(:allowed_sources)).to include('contains invalid keys: invalid_key')
          end

          it 'does not allow non-array apps' do
            message = RouteOptionsMessage.new({ allowed_sources: { 'apps' => 'not-an-array' } })
            expect(message).not_to be_valid
            expect(message.errors_on(:allowed_sources)).to include('apps must be an array of strings')
          end

          it 'does not allow non-string elements in apps array' do
            message = RouteOptionsMessage.new({ allowed_sources: { 'apps' => [123, 456] } })
            expect(message).not_to be_valid
            expect(message.errors_on(:allowed_sources)).to include('apps must be an array of strings')
          end

          it 'does not allow non-array spaces' do
            message = RouteOptionsMessage.new({ allowed_sources: { 'spaces' => 'not-an-array' } })
            expect(message).not_to be_valid
            expect(message.errors_on(:allowed_sources)).to include('spaces must be an array of strings')
          end

          it 'does not allow non-array orgs' do
            message = RouteOptionsMessage.new({ allowed_sources: { 'orgs' => 'not-an-array' } })
            expect(message).not_to be_valid
            expect(message.errors_on(:allowed_sources)).to include('orgs must be an array of strings')
          end

          it 'does not allow non-boolean any' do
            message = RouteOptionsMessage.new({ allowed_sources: { 'any' => 'true' } })
            expect(message).not_to be_valid
            expect(message.errors_on(:allowed_sources)).to include('any must be a boolean')
          end
        end

        describe 'any exclusivity validation' do
          it 'does not allow any: true with apps list' do
            app = AppModel.make
            message = RouteOptionsMessage.new({ allowed_sources: { 'any' => true, 'apps' => [app.guid] } })
            expect(message).not_to be_valid
            expect(message.errors_on(:allowed_sources)).to include('any is mutually exclusive with apps, spaces, and orgs')
          end

          it 'does not allow any: true with spaces list' do
            space = Space.make
            message = RouteOptionsMessage.new({ allowed_sources: { 'any' => true, 'spaces' => [space.guid] } })
            expect(message).not_to be_valid
            expect(message.errors_on(:allowed_sources)).to include('any is mutually exclusive with apps, spaces, and orgs')
          end

          it 'does not allow any: true with orgs list' do
            org = Organization.make
            message = RouteOptionsMessage.new({ allowed_sources: { 'any' => true, 'orgs' => [org.guid] } })
            expect(message).not_to be_valid
            expect(message.errors_on(:allowed_sources)).to include('any is mutually exclusive with apps, spaces, and orgs')
          end

          it 'allows any: false with apps list' do
            app = AppModel.make
            message = RouteOptionsMessage.new({ allowed_sources: { 'any' => false, 'apps' => [app.guid] } })
            expect(message).to be_valid
          end

          it 'allows any: true with empty apps list' do
            message = RouteOptionsMessage.new({ allowed_sources: { 'any' => true, 'apps' => [] } })
            expect(message).to be_valid
          end
        end

        describe 'GUID existence validation' do
          it 'validates that app GUIDs exist' do
            message = RouteOptionsMessage.new({ allowed_sources: { 'apps' => ['non-existent-app-guid'] } })
            expect(message).not_to be_valid
            expect(message.errors_on(:allowed_sources)).to include('apps contains non-existent app GUIDs: non-existent-app-guid')
          end

          it 'validates that space GUIDs exist' do
            message = RouteOptionsMessage.new({ allowed_sources: { 'spaces' => ['non-existent-space-guid'] } })
            expect(message).not_to be_valid
            expect(message.errors_on(:allowed_sources)).to include('spaces contains non-existent space GUIDs: non-existent-space-guid')
          end

          it 'validates that org GUIDs exist' do
            message = RouteOptionsMessage.new({ allowed_sources: { 'orgs' => ['non-existent-org-guid'] } })
            expect(message).not_to be_valid
            expect(message.errors_on(:allowed_sources)).to include('orgs contains non-existent organization GUIDs: non-existent-org-guid')
          end

          it 'reports multiple non-existent app GUIDs' do
            message = RouteOptionsMessage.new({ allowed_sources: { 'apps' => ['guid-1', 'guid-2'] } })
            expect(message).not_to be_valid
            expect(message.errors_on(:allowed_sources)).to include('apps contains non-existent app GUIDs: guid-1, guid-2')
          end

          it 'allows mix of existing apps, spaces, and orgs' do
            app = AppModel.make
            space = Space.make
            org = Organization.make
            message = RouteOptionsMessage.new({
              allowed_sources: {
                'apps' => [app.guid],
                'spaces' => [space.guid],
                'orgs' => [org.guid]
              }
            })
            expect(message).to be_valid
          end

          it 'validates all types of GUIDs when multiple are provided' do
            app = AppModel.make
            message = RouteOptionsMessage.new({
              allowed_sources: {
                'apps' => [app.guid],
                'spaces' => ['non-existent-space'],
                'orgs' => ['non-existent-org']
              }
            })
            expect(message).not_to be_valid
            expect(message.errors_on(:allowed_sources)).to include('spaces contains non-existent space GUIDs: non-existent-space')
            expect(message.errors_on(:allowed_sources)).to include('orgs contains non-existent organization GUIDs: non-existent-org')
          end
        end

        describe 'combined with other options' do
          it 'allows allowed_sources with loadbalancing' do
            app = AppModel.make
            message = RouteOptionsMessage.new({
              loadbalancing: 'round-robin',
              allowed_sources: { 'apps' => [app.guid] }
            })
            expect(message).to be_valid
          end
        end
      end
    end

    describe 'hash-based routing validations' do
      context 'when hash_based_routing feature flag is disabled' do
        it 'does not allow hash_header option' do
          message = RouteOptionsMessage.new({ hash_header: 'X-User-ID' })
          expect(message).not_to be_valid
          expect(message.errors_on(:base)).to include("Unknown field(s): 'hash_header'")
        end

        it 'does not allow hash_balance option' do
          message = RouteOptionsMessage.new({ hash_balance: '1.5' })
          expect(message).not_to be_valid
          expect(message.errors_on(:base)).to include("Unknown field(s): 'hash_balance'")
        end

        it 'reports multiple invalid keys together' do
          message = RouteOptionsMessage.new({ hash_header: 'X-User-ID', hash_balance: '1.5' })
          expect(message).not_to be_valid
          expect(message.errors_on(:base)).to include("Unknown field(s): 'hash_header', 'hash_balance'")
        end

        it 'does not allow hash load-balancing algorithm' do
          message = RouteOptionsMessage.new({ loadbalancing: 'hash' })
          expect(message).not_to be_valid
          expect(message.errors_on(:loadbalancing)).to include("must be one of 'round-robin, least-connection' if present")
        end
      end

      context 'when hash_based_routing feature flag is enabled' do
        before do
          VCAP::CloudController::FeatureFlag.make(name: 'hash_based_routing', enabled: true)
        end

        describe 'loadbalancing algorithm' do
          it 'allows hash loadbalancing option' do
            message = RouteOptionsMessage.new({ loadbalancing: 'hash', hash_header: 'X-User-ID' })
            expect(message).to be_valid
          end

          it 'allows round-robin loadbalancing' do
            message = RouteOptionsMessage.new({ loadbalancing: 'round-robin' })
            expect(message).to be_valid
          end

          it 'allows least-connection loadbalancing' do
            message = RouteOptionsMessage.new({ loadbalancing: 'least-connection' })
            expect(message).to be_valid
          end
        end

        describe 'hash_header validation' do
          it 'allows hash_header option' do
            message = RouteOptionsMessage.new({ hash_header: 'X-User-ID' })
            expect(message).to be_valid
          end

          it 'does not allow hash_header without hash load-balancing' do
            message = RouteOptionsMessage.new({ loadbalancing: 'round-robin', hash_header: 'X-User-ID' })
            expect(message).not_to be_valid
            expect(message.errors_on(:base)).to include('Hash header can only be set when loadbalancing is hash')
          end

          context 'hash_header length validation' do
            it 'does not accept hash_header longer than 128 characters' do
              message = RouteOptionsMessage.new({ loadbalancing: 'hash', hash_header: 'X' * 129 })
              expect(message).not_to be_valid
              expect(message.errors_on(:hash_header)).to include('must be at most 128 characters')
            end

            it 'accepts hash_header exactly 128 characters' do
              message = RouteOptionsMessage.new({ loadbalancing: 'hash', hash_header: 'X' * 128 })
              expect(message).to be_valid
            end
          end
        end

        describe 'hash_balance validation' do
          it 'allows hash_balance option' do
            message = RouteOptionsMessage.new({ hash_balance: '1.5' })
            expect(message).to be_valid
          end

          it 'does not allow hash_balance without hash load-balancing' do
            message = RouteOptionsMessage.new({ loadbalancing: 'round-robin', hash_balance: '1.5' })
            expect(message).not_to be_valid
            expect(message.errors_on(:base)).to include('Hash balance can only be set when loadbalancing is hash')
          end

          context 'numeric validation' do
            it 'does not allow non-numeric hash_balance' do
              message = RouteOptionsMessage.new({ hash_balance: 'not-a-number' })
              expect(message).not_to be_valid
              expect(message.errors.full_messages).to include('Hash balance must be a numeric value')
            end

            it 'allows hash_balance of 0' do
              message = RouteOptionsMessage.new({ hash_balance: 0 })
              expect(message).to be_valid
            end

            it 'allows hash_balance of 1.1' do
              message = RouteOptionsMessage.new({ hash_balance: 1.1 })
              expect(message).to be_valid
            end

            it 'allows hash_balance greater than 1.1' do
              message = RouteOptionsMessage.new({ hash_balance: 2.5 })
              expect(message).to be_valid
            end

            it 'does not allow hash_balance between 0 and 1.1' do
              message = RouteOptionsMessage.new({ hash_balance: 0.5 })
              expect(message).not_to be_valid
              expect(message.errors.full_messages).to include('Hash balance must be either 0 or between 1.1 and 10.0')
            end

            it 'allows numeric string hash_balance' do
              message = RouteOptionsMessage.new({ hash_balance: '2.5' })
              expect(message).to be_valid
            end

            it 'allows integer string hash_balance' do
              message = RouteOptionsMessage.new({ hash_balance: '3' })
              expect(message).to be_valid
            end

            it 'allows float hash_balance' do
              message = RouteOptionsMessage.new({ hash_balance: 1.5 })
              expect(message).to be_valid
            end
          end

          context 'length validation' do
            it 'does not accept hash_balance longer than 16 characters' do
              message = RouteOptionsMessage.new({ loadbalancing: 'hash', hash_header: 'X-User-ID', hash_balance: '12345678901234567' })
              expect(message).not_to be_valid
              expect(message.errors_on(:hash_balance)).to include('must be at most 16 characters')
            end

            it 'accepts hash_balance exactly 16 characters' do
              message = RouteOptionsMessage.new({ loadbalancing: 'hash', hash_header: 'X-User-ID', hash_balance: '9.9' })
              expect(message).to be_valid
            end
          end

          context 'range validation' do
            it 'does not accept hash_balance greater than 10.0' do
              message = RouteOptionsMessage.new({ loadbalancing: 'hash', hash_header: 'X-User-ID', hash_balance: 10.1 })
              expect(message).not_to be_valid
              expect(message.errors_on(:hash_balance)).to include('must be either 0 or between 1.1 and 10.0')
            end

            it 'accepts hash_balance exactly 10.0' do
              message = RouteOptionsMessage.new({ loadbalancing: 'hash', hash_header: 'X-User-ID', hash_balance: 10.0 })
              expect(message).to be_valid
            end
          end
        end

        describe 'combined hash options' do
          it 'allows hash loadbalancing with hash_header and hash_balance' do
            message = RouteOptionsMessage.new({ loadbalancing: 'hash', hash_header: 'X-User-ID', hash_balance: '2.5' })
            expect(message).to be_valid
          end

          it 'allows hash loadbalancing with only hash_header' do
            message = RouteOptionsMessage.new({ loadbalancing: 'hash', hash_header: 'X-User-ID' })
            expect(message).to be_valid
          end
        end
      end
    end
  end
end
