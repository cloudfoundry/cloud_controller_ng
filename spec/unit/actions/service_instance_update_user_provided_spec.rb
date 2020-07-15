require 'spec_helper'
require 'actions/service_instance_update_user_provided'

module VCAP::CloudController
  RSpec.describe ServiceInstanceUpdateUserProvided do
    describe '#update' do
      subject(:action) { described_class.new(event_repository) }
      let(:event_repository) do
        dbl = double(Repositories::ServiceEventRepository::WithUserActor)
        allow(dbl).to receive(:record_user_provided_service_instance_event)
        dbl
      end
      let(:body) do
        {
          name: 'my_service_instance',
          credentials: {
            used_in: 'bindings',
            foo: 'bar',
          },
          syslog_drain_url: 'https://foo2.com',
          route_service_url: 'https://bar2.com',
          tags: %w(accounting couchbase nosql),
          metadata: {
            labels: {
              foo: 'bar',
              'pre.fix/to_delete': nil,
            },
            annotations: {
              alpha: 'beta',
              'pre.fix/to_delete': nil,
            }
          }
        }
      end
      let!(:service_instance) do
        si = VCAP::CloudController::UserProvidedServiceInstance.make(
          name: 'foo',
          credentials: {
            foo: 'bar',
            baz: 'qux'
          },
          syslog_drain_url: 'https://foo.com',
          route_service_url: 'https://bar.com',
          tags: %w(accounting mongodb)
        )
        si.label_ids = [
          VCAP::CloudController::ServiceInstanceLabelModel.make(key_prefix: 'pre.fix', key_name: 'to_delete', value: 'value'),
          VCAP::CloudController::ServiceInstanceLabelModel.make(key_prefix: 'pre.fix', key_name: 'tail', value: 'fluffy')
        ]
        si.annotation_ids = [
          VCAP::CloudController::ServiceInstanceAnnotationModel.make(key_prefix: 'pre.fix', key_name: 'to_delete', value: 'value').id,
          VCAP::CloudController::ServiceInstanceAnnotationModel.make(key_prefix: 'pre.fix', key_name: 'fox', value: 'bushy').id
        ]
        si
      end
      let(:message) { ServiceInstanceUpdateUserProvidedMessage.new(body) }

      it 'updates the values in the service instance in the database' do
        action.update(service_instance, message)

        service_instance.reload

        expect(service_instance.name).to eq('my_service_instance')
        expect(service_instance.credentials).to eq({ used_in: 'bindings', foo: 'bar' }.with_indifferent_access)
        expect(service_instance.syslog_drain_url).to eq('https://foo2.com')
        expect(service_instance.route_service_url).to eq('https://bar2.com')
        expect(service_instance.tags).to eq(%w(accounting couchbase nosql))
        expect(service_instance.labels.map { |l| { prefix: l.key_prefix, key: l.key_name, value: l.value } }).to match_array([
          { prefix: nil, key: 'foo', value: 'bar' },
          { prefix: 'pre.fix', key: 'tail', value: 'fluffy' },
        ])
        expect(service_instance.annotations.map { |a| { prefix: a.key_prefix, key: a.key, value: a.value } }).to match_array([
          { prefix: nil, key: 'alpha', value: 'beta' },
          { prefix: 'pre.fix', key: 'fox', value: 'bushy' },
        ])
      end

      it 'returns the updated service instance' do
        si = action.update(service_instance, message)
        expect(si).to eq(service_instance.reload)
      end

      it 'creates an audit event' do
        action.update(service_instance, message)

        body[:credentials] = '[PRIVATE DATA HIDDEN]'

        expect(event_repository).
          to have_received(:record_user_provided_service_instance_event).with(
            :update,
            instance_of(UserProvidedServiceInstance),
            body.with_indifferent_access
          )
      end

      context 'when the update is empty' do
        let(:body) do
          {}
        end

        it 'succeeds' do
          action.update(service_instance, message)
        end
      end

      context 'when the name is already taken' do
        let!(:other_service_instance) { UserProvidedServiceInstance.make(name: 'already_taken', space: service_instance.space) }
        let(:body) do
          { name: 'already_taken' }
        end

        it 'fails' do
          expect {
            action.update(service_instance, message)
          }.to raise_error(
            ServiceInstanceUpdateUserProvided::UnprocessableUpdate,
            'The service instance name is taken: already_taken',
          )
        end
      end

      context 'SQL validation fails' do
        it 'raises an error' do
          errors = Sequel::Model::Errors.new
          errors.add(:blork, 'is busted')
          expect_any_instance_of(UserProvidedServiceInstance).to receive(:update).
            and_raise(Sequel::ValidationFailed.new(errors))

          expect { action.update(service_instance, message) }.
            to raise_error(ServiceInstanceUpdateUserProvided::UnprocessableUpdate, 'blork is busted')
        end
      end
    end
  end
end
