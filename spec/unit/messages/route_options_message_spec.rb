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
