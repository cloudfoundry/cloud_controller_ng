require 'spec_helper'

RSpec.describe 'Service Broker API integration' do
  describe 'v2.11' do
    include VCAP::CloudController::BrokerApiHelper

    let(:catalog) do
      catalog = default_catalog(plan_updateable: true)
      catalog[:services].first[:plans].first[:bindable] = plan_bindable
      catalog[:services].first[:bindable] = service_bindable
      catalog
    end

    before do
      setup_cc
      setup_broker(catalog)
      @broker = VCAP::CloudController::ServiceBroker.find guid: @broker_guid
      provision_service
      create_app
    end

    shared_examples 'a bindable plan' do
      it 'can be bound' do
        bind_service

        expect(a_request(:put, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/[[:alnum:]-]+})).
          to have_been_made.once
      end
    end

    shared_examples 'an unbindable plan' do
      it 'cannot be bound' do
        bind_service

        expect(a_request(:put, %r{/v2/service_instances/#{@service_instance_guid}/service_bindings/[[:alnum:]-]+})).
          to have_not_been_made
      end
    end

    context 'when the service is set as bindable' do
      let(:service_bindable) { true }

      context 'and the plan does not specify whether it is bindable' do
        let(:plan_bindable) { nil }

        it_behaves_like 'a bindable plan'
      end

      context 'and the plan is explicitly set as bindable' do
        let(:plan_bindable) { true }

        it_behaves_like 'a bindable plan'
      end

      context 'and the plan is explicitly set as not bindable' do
        let(:plan_bindable) { false }

        it_behaves_like 'an unbindable plan'
      end
    end

    context 'when the service is set as not bindable' do
      let(:service_bindable) { false }

      context 'and the plan does not specify whether it is bindable' do
        let(:plan_bindable) { nil }

        it_behaves_like 'an unbindable plan'
      end

      context 'and the plan is explicitly set as bindable' do
        let(:plan_bindable) { true }

        it_behaves_like 'a bindable plan'
      end

      context 'and the plan is explicitly set as not bindable' do
        let(:plan_bindable) { false }

        it_behaves_like 'an unbindable plan'
      end
    end
  end
end
