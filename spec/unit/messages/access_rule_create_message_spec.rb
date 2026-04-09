require 'spec_helper'
require 'messages/access_rule_create_message'

module VCAP::CloudController
  RSpec.describe AccessRuleCreateMessage do
    let(:valid_uuid) { '11111111-2222-3333-4444-555555555555' }
    let(:valid_route_relationship) do
      { relationships: { route: { data: { guid: valid_uuid } } } }
    end

    subject { AccessRuleCreateMessage.new(params) }

    describe 'validations' do
      context 'when all valid params are given' do
        let(:params) do
          {
            name: 'allow-frontend',
            selector: "cf:app:#{valid_uuid}",
          }.merge(valid_route_relationship)
        end

        it 'is valid' do
          expect(subject).to be_valid
        end
      end

      context 'when unexpected keys are provided' do
        let(:params) do
          {
            name: 'allow-frontend',
            selector: "cf:app:#{valid_uuid}",
            unexpected: 'field',
          }.merge(valid_route_relationship)
        end

        it 'is not valid' do
          expect(subject).not_to be_valid
          expect(subject.errors.full_messages[0]).to include("Unknown field(s): 'unexpected'")
        end
      end

      describe 'name' do
        context 'when name is missing' do
          let(:params) do
            {
              selector: "cf:app:#{valid_uuid}",
            }.merge(valid_route_relationship)
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:name]).to include("can't be blank")
          end
        end

        context 'when name is not a string' do
          let(:params) do
            {
              name: 42,
              selector: "cf:app:#{valid_uuid}",
            }.merge(valid_route_relationship)
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:name]).to include('must be a string')
          end
        end
      end

      describe 'selector' do
        context 'when selector is missing' do
          let(:params) do
            {
              name: 'allow-frontend',
            }.merge(valid_route_relationship)
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:selector]).to include("can't be blank")
          end
        end

        context 'when selector is not a string' do
          let(:params) do
            {
              name: 'allow-frontend',
              selector: 123,
            }.merge(valid_route_relationship)
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:selector]).to include('must be a string')
          end
        end

        context 'selector format' do
          context 'cf:app:<uuid>' do
            let(:params) do
              {
                name: 'allow-app',
                selector: "cf:app:#{valid_uuid}",
              }.merge(valid_route_relationship)
            end

            it 'is valid' do
              expect(subject).to be_valid
            end
          end

          context 'cf:space:<uuid>' do
            let(:params) do
              {
                name: 'allow-space',
                selector: "cf:space:#{valid_uuid}",
              }.merge(valid_route_relationship)
            end

            it 'is valid' do
              expect(subject).to be_valid
            end
          end

          context 'cf:org:<uuid>' do
            let(:params) do
              {
                name: 'allow-org',
                selector: "cf:org:#{valid_uuid}",
              }.merge(valid_route_relationship)
            end

            it 'is valid' do
              expect(subject).to be_valid
            end
          end

          context 'cf:any' do
            let(:params) do
              {
                name: 'allow-any',
                selector: 'cf:any',
              }.merge(valid_route_relationship)
            end

            it 'is valid' do
              expect(subject).to be_valid
            end
          end

          context 'invalid format' do
            let(:params) do
              {
                name: 'bad-rule',
                selector: 'not-valid',
              }.merge(valid_route_relationship)
            end

            it 'is not valid' do
              expect(subject).not_to be_valid
              expect(subject.errors[:selector]).to include(
                "must be in format 'cf:app:<uuid>', 'cf:space:<uuid>', 'cf:org:<uuid>', or 'cf:any'"
              )
            end
          end

          context 'cf:app: with invalid uuid' do
            let(:params) do
              {
                name: 'bad-rule',
                selector: 'cf:app:not-a-uuid',
              }.merge(valid_route_relationship)
            end

            it 'is not valid' do
              expect(subject).not_to be_valid
              expect(subject.errors[:selector]).to include(
                "must be in format 'cf:app:<uuid>', 'cf:space:<uuid>', 'cf:org:<uuid>', or 'cf:any'"
              )
            end
          end

          context 'cf:unknown type' do
            let(:params) do
              {
                name: 'bad-rule',
                selector: "cf:team:#{valid_uuid}",
              }.merge(valid_route_relationship)
            end

            it 'is not valid' do
              expect(subject).not_to be_valid
              expect(subject.errors[:selector]).to include(
                "must be in format 'cf:app:<uuid>', 'cf:space:<uuid>', 'cf:org:<uuid>', or 'cf:any'"
              )
            end
          end
        end
      end

      describe 'relationships' do
        context 'when relationships is missing' do
          let(:params) do
            {
              name: 'allow-frontend',
              selector: "cf:app:#{valid_uuid}",
            }
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
            expect(subject.errors[:relationships]).to be_present
          end
        end

        context 'when route relationship is missing' do
          let(:params) do
            {
              name: 'allow-frontend',
              selector: "cf:app:#{valid_uuid}",
              relationships: {},
            }
          end

          it 'is not valid' do
            expect(subject).not_to be_valid
          end
        end

        context 'when route guid is provided' do
          let(:params) do
            {
              name: 'allow-frontend',
              selector: "cf:app:#{valid_uuid}",
              relationships: { route: { data: { guid: 'some-route-guid' } } },
            }
          end

          it 'exposes the route_guid' do
            expect(subject).to be_valid
            expect(subject.route_guid).to eq('some-route-guid')
          end
        end
      end
    end
  end
end
