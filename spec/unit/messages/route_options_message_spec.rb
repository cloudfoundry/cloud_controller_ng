require 'spec_helper'
require 'messages/route_options_message'

module VCAP::CloudController
  RSpec.describe RouteOptionsMessage do
    describe 'validations' do
      context 'with hash algorithm' do
        before do
          VCAP::CloudController::FeatureFlag.make(name: 'hash_based_routing', enabled: true)
        end

        context 'when hash_header is provided' do
          it 'is valid' do
            message = RouteOptionsMessage.new({
                                                loadbalancing: 'hash',
                                                hash_header: 'X-User-ID'
                                              })
            expect(message).to be_valid
          end

          context 'with hash_balance as float' do
            it 'is valid' do
              message = RouteOptionsMessage.new({
                                                  loadbalancing: 'hash',
                                                  hash_header: 'X-User-ID',
                                                  hash_balance: 1.5
                                                })
              expect(message).to be_valid
            end
          end

          context 'with hash_balance as string' do
            it 'is valid and converts to float' do
              message = RouteOptionsMessage.new({
                                                  loadbalancing: 'hash',
                                                  hash_header: 'X-User-ID',
                                                  hash_balance: '1.5'
                                                })
              expect(message).to be_valid
            end
          end

          context 'with hash_balance as integer' do
            it 'is valid and converts to float' do
              message = RouteOptionsMessage.new({
                                                  loadbalancing: 'hash',
                                                  hash_header: 'X-User-ID',
                                                  hash_balance: 1
                                                })
              expect(message).to be_valid
            end
          end

          context 'with hash_balance as zero' do
            it 'is valid' do
              message = RouteOptionsMessage.new({
                                                  loadbalancing: 'hash',
                                                  hash_header: 'X-User-ID',
                                                  hash_balance: 0
                                                })
              expect(message).to be_valid
            end
          end
        end

        context 'when hash_header is not provided' do
          it 'is invalid' do
            message = RouteOptionsMessage.new({
                                                loadbalancing: 'hash'
                                              })
            expect(message).not_to be_valid
            expect(message.errors[:hash_header]).to include('must be present when loadbalancing is set to hash')
          end
        end

        context 'when hash_header is empty string' do
          it 'is invalid' do
            message = RouteOptionsMessage.new({
                                                loadbalancing: 'hash',
                                                hash_header: ''
                                              })
            expect(message).not_to be_valid
            expect(message.errors[:hash_header]).to include('must be present when loadbalancing is set to hash')
          end
        end

        context 'when hash_balance is negative' do
          it 'is invalid' do
            message = RouteOptionsMessage.new({
                                                loadbalancing: 'hash',
                                                hash_header: 'X-User-ID',
                                                hash_balance: -1.0
                                              })
            expect(message).not_to be_valid
            expect(message.errors[:hash_balance]).to include('must be greater than or equal to 0.0')
          end
        end

        context 'when hash_balance is invalid string' do
          it 'is invalid' do
            message = RouteOptionsMessage.new({
                                                loadbalancing: 'hash',
                                                hash_header: 'X-User-ID',
                                                hash_balance: 'not-a-number'
                                              })
            expect(message).not_to be_valid
            expect(message.errors[:hash_balance]).to include('must be a valid number')
          end
        end
      end

      context 'with round-robin algorithm' do
        context 'when hash_header is provided' do
          it 'is invalid' do
            message = RouteOptionsMessage.new({
                                                loadbalancing: 'round-robin',
                                                hash_header: 'X-User-ID'
                                              })
            expect(message).not_to be_valid
            expect(message.errors[:hash_header]).to include('can only be set when loadbalancing is hash')
          end
        end

        context 'when hash_balance is provided' do
          it 'is invalid' do
            message = RouteOptionsMessage.new({
                                                loadbalancing: 'round-robin',
                                                hash_balance: 1.0
                                              })
            expect(message).not_to be_valid
            expect(message.errors[:hash_balance]).to include('can only be set when loadbalancing is hash')
          end
        end

        context 'without hash options' do
          it 'is valid' do
            message = RouteOptionsMessage.new({
                                                loadbalancing: 'round-robin'
                                              })
            expect(message).to be_valid
          end
        end
      end

      context 'with least-connection algorithm' do
        context 'when hash_header is provided' do
          it 'is invalid' do
            message = RouteOptionsMessage.new({
                                                loadbalancing: 'least-connection',
                                                hash_header: 'X-User-ID'
                                              })
            expect(message).not_to be_valid
            expect(message.errors[:hash_header]).to include('can only be set when loadbalancing is hash')
          end
        end

        context 'when hash_balance is provided' do
          it 'is invalid' do
            message = RouteOptionsMessage.new({
                                                loadbalancing: 'least-connection',
                                                hash_balance: 1.0
                                              })
            expect(message).not_to be_valid
            expect(message.errors[:hash_balance]).to include('can only be set when loadbalancing is hash')
          end
        end

        context 'without hash options' do
          it 'is valid' do
            message = RouteOptionsMessage.new({
                                                loadbalancing: 'least-connection'
                                              })
            expect(message).to be_valid
          end
        end
      end

      context 'with invalid loadbalancing algorithm' do
        it 'is invalid without feature flag' do
          message = RouteOptionsMessage.new({
                                              loadbalancing: 'invalid-algorithm'
                                            })
          expect(message).not_to be_valid
          expect(message.errors[:loadbalancing]).to include("must be one of 'round-robin, least-connection' if present")
        end

        context 'when hash_based_routing feature flag is enabled' do
          before do
            VCAP::CloudController::FeatureFlag.make(name: 'hash_based_routing', enabled: true)
          end

          it 'is invalid and includes hash in error message' do
            message = RouteOptionsMessage.new({
                                                loadbalancing: 'invalid-algorithm'
                                              })
            expect(message).not_to be_valid
            expect(message.errors[:loadbalancing]).to include("must be one of 'round-robin, least-connection, hash' if present")
          end
        end
      end
    end
  end
end
