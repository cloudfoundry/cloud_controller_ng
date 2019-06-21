require 'spec_helper'
require 'messages/route_update_destinations_message'

module VCAP::CloudController
  RSpec.describe RouteUpdateDestinationsMessage do
    let(:replace) { false }
    subject(:message) { RouteUpdateDestinationsMessage.new(params, replace: replace) }

    context 'when the body has the correct structure' do
      let(:params) do
        {
          destinations: [
            {
              app: {
                guid: 'some-guid',
                process: {
                  type: 'web'
                }
              }
            }
          ]
        }
      end

      it 'is valid' do
        expect(subject).to be_valid
      end
    end

    context 'when destinations is missing' do
      let(:params) { {} }

      it 'is not valid' do
        expect(subject).to be_invalid
        expect(subject.errors[:base].length).to eq 1
        expect(subject.errors[:base][0]).to eq('Destinations must be an array containing between 1 and 100 destination objects')
      end
    end

    context 'when there are additional keys' do
      let(:params) { { potato: '' } }

      it 'is not valid' do
        expect(subject).to be_invalid
        expect(subject.errors[:base].length).to eq 2
        expect(subject.errors[:base][0]).to eq("Unknown field(s): 'potato'")
        expect(subject.errors[:base][1]).to eq('Destinations must be an array containing between 1 and 100 destination objects')
      end
    end

    context 'when destinations is not an array' do
      let(:params) { { destinations: '' } }

      it 'is not valid' do
        expect(subject).to be_invalid
        expect(subject.errors[:base].length).to eq 1
        expect(subject.errors[:base][0]).to eq('Destinations must be an array containing between 1 and 100 destination objects')
      end
    end

    context 'when destinations doesnt contain hashes' do
      let(:params) { { destinations: [''] } }

      it 'is not valid' do
        expect(subject).to be_invalid
        expect(subject.errors[:base].length).to eq 1
        expect(subject.errors[:base][0]).to eq('Destinations must have the structure "destinations": [{"app": {"guid": "app_guid"}}]')
      end
    end

    context 'when destinations are malformed' do
      context 'when the app key is missing' do
        let(:params) { { destinations: [{ potato: '' }] } }

        it 'is not valid' do
          expect(subject).to be_invalid
          expect(subject.errors[:base].length).to eq 1
          expect(subject.errors[:base][0]).to eq('Destinations must have the structure "destinations": [{"app": {"guid": "app_guid"}}]')
        end
      end

      context 'when app is not a hash' do
        let(:params) { { destinations: [{ app: '' }] } }

        it 'is not valid' do
          expect(subject).to be_invalid
          expect(subject.errors[:base].length).to eq 1
          expect(subject.errors[:base][0]).to eq('Destinations must have the structure "destinations": [{"app": {"guid": "app_guid"}}]')
        end
      end

      context 'when destination apps are malformed' do
        context 'when the guid key is missing' do
          let(:params) { { destinations: [{ app: { process: { type: 'web' } } }] } }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors[:base].length).to eq 1
            expect(subject.errors[:base][0]).to eq('Destinations must have the structure "destinations": [{"app": {"guid": "app_guid"}}]')
          end
        end

        context 'when additional keys are given' do
          let(:params) { { destinations: [{ app: { guid: '', not_allowed: '' } }] } }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors[:base].length).to eq 1
            expect(subject.errors[:base][0]).to eq('Destinations must have the structure "destinations": [{"app": {"guid": "app_guid"}}]')
          end
        end

        context 'when the guid is not a string' do
          let(:params) { { destinations: [{ app: { guid: 123 } }] } }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors[:base].length).to eq 1
            expect(subject.errors[:base][0]).to eq('Destinations must have the structure "destinations": [{"app": {"guid": "app_guid"}}]')
          end
        end

        context 'when there is a process specified' do
          context 'when the process is not a hash' do
            let(:params) { { destinations: [{ app: { guid: 'guid', process: 3 } }] } }

            it 'is not valid' do
              expect(subject).to be_invalid
              expect(subject.errors[:base].length).to eq 1
              expect(subject.errors[:base][0]).to eq('Process must have the structure "process": {"type": "type"}')
            end
          end

          context 'when the type key is missing' do
            let(:params) { { destinations: [{ app: { guid: 'guid', process: { not_type: '' } } }] } }

            it 'is not valid' do
              expect(subject).to be_invalid
              expect(subject.errors[:base].length).to eq 1
              expect(subject.errors[:base][0]).to eq('Process must have the structure "process": {"type": "type"}')
            end
          end

          context 'when type is not a string' do
            let(:params) { { destinations: [{ app: { guid: 'guid', process: { type: 4 } } }] } }

            it 'is not valid' do
              expect(subject).to be_invalid
              expect(subject.errors[:base].length).to eq 1
              expect(subject.errors[:base][0]).to eq('Process must have the structure "process": {"type": "type"}')
            end
          end

          context 'when type is not empty' do
            let(:params) { { destinations: [{ app: { guid: 'guid', process: { type: '' } } }] } }

            it 'is not valid' do
              expect(subject).to be_invalid
              expect(subject.errors[:base].length).to eq 1
              expect(subject.errors[:base][0]).to eq('Process must have the structure "process": {"type": "type"}')
            end
          end
        end
      end
    end

    context 'when destinations is an empty array' do
      let(:params) { { destinations: [] } }

      context 'when replacing destinations' do
        let(:replace) { true }

        it 'is valid' do
          expect(subject).to be_valid
        end
      end

      context 'when inserting destinations' do
        let(:replace) { false }

        it 'is not valid' do
          expect(subject).to be_invalid
          expect(subject.errors[:base].length).to eq 1
          expect(subject.errors[:base][0]).to eq('Destinations must be an array containing between 1 and 100 destination objects')
        end
      end
    end
  end
end
