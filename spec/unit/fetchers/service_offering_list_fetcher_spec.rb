require 'spec_helper'
require 'fetchers/service_offering_list_fetcher'
require 'messages/service_offerings_list_message'

module VCAP::CloudController
  RSpec.shared_examples 'filtered service offering fetcher' do |current_method|
    describe 'the `available` filter' do
      let!(:service_offering_available) { ServicePlan.make(public: true, active: true).service }
      let!(:service_offering_unavailable) do
        offering = Service.make(active: false)
        ServicePlan.make(public: true, active: true, service: offering)
        offering
      end

      context 'filtering available offerings' do
        let(:message) { ServiceOfferingsListMessage.from_params({ available: 'true' }.with_indifferent_access) }

        it 'filters the available offerings' do
          expect(service_offerings).to contain_exactly(service_offering_available)
        end
      end

      context 'filtering unavailable offerings' do
        let(:message) { ServiceOfferingsListMessage.from_params({ available: 'false' }.with_indifferent_access) }

        it 'filters the available offerings' do
          expect(service_offerings).to contain_exactly(service_offering_unavailable)
        end
      end
    end

    describe 'the `service_broker_guids` filter' do
      let!(:service_broker) { VCAP::CloudController::ServiceBroker.make }
      let!(:service_offering_1) do
        offering = VCAP::CloudController::Service.make(service_broker: service_broker)
        VCAP::CloudController::ServicePlan.make(public: true, service: offering)
        offering
      end
      let!(:service_offering_2) do
        offering = VCAP::CloudController::Service.make(service_broker: service_broker)
        VCAP::CloudController::ServicePlan.make(public: true, service: offering)
        offering
      end
      let!(:service_offering_3) { VCAP::CloudController::ServicePlan.make.service }
      let!(:service_offering_4) { VCAP::CloudController::ServicePlan.make.service }

      let(:service_broker_guids) { [service_broker.guid, service_offering_3.service_broker.guid] }
      let(:message) { ServiceOfferingsListMessage.from_params({ service_broker_guids: service_broker_guids.join(',') }.with_indifferent_access) }

      it 'filters the service offerings with matching service broker GUIDs' do
        expect(service_offerings).to contain_exactly(
          service_offering_1,
          service_offering_2,
          service_offering_3,
        )
      end
    end

    describe 'the `service_broker_names` filter' do
      let!(:service_broker) { VCAP::CloudController::ServiceBroker.make }
      let!(:service_offering_1) do
        offering = VCAP::CloudController::Service.make(service_broker: service_broker)
        VCAP::CloudController::ServicePlan.make(public: true, service: offering)
        offering
      end
      let!(:service_offering_2) do
        offering = VCAP::CloudController::Service.make(service_broker: service_broker)
        VCAP::CloudController::ServicePlan.make(public: true, service: offering)
        offering
      end
      let!(:service_offering_3) { VCAP::CloudController::ServicePlan.make.service }
      let!(:service_offering_4) { VCAP::CloudController::ServicePlan.make.service }

      let(:service_broker_names) { [service_broker.name, service_offering_4.service_broker.name] }
      let(:message) { ServiceOfferingsListMessage.from_params({ service_broker_names: service_broker_names.join(',') }.with_indifferent_access) }

      it 'filters the service offerings with matching service broker names' do
        expect(service_offerings).to contain_exactly(
          service_offering_1,
          service_offering_2,
          service_offering_4,
        )
      end
    end

    describe 'the `names` filter' do
      let!(:service_offering_1) { VCAP::CloudController::ServicePlan.make(public: true).service }
      let!(:service_offering_2) { VCAP::CloudController::ServicePlan.make(public: true).service }
      let!(:service_offering_3) { VCAP::CloudController::ServicePlan.make(public: true).service }
      let!(:service_offering_4) { VCAP::CloudController::ServicePlan.make(public: true).service }

      let(:service_offering_names) { [service_offering_1.name, service_offering_3.name] }
      let(:message) { ServiceOfferingsListMessage.from_params({ names: service_offering_names.join(',') }.with_indifferent_access) }

      it 'filters the service offerings with matching names' do
        expect(service_offerings).to contain_exactly(
          service_offering_1,
          service_offering_3,
        )
      end
    end

    describe 'the `label_selector` filter' do
      let!(:service_offering_1) { VCAP::CloudController::ServicePlan.make(public: true, active: true).service }
      let!(:service_offering_2) { VCAP::CloudController::ServicePlan.make(public: true, active: true).service }
      let!(:service_offering_3) { VCAP::CloudController::ServicePlan.make(public: true, active: true).service }
      let(:message) { ServiceOfferingsListMessage.from_params({ label_selector: 'flavor=orange' }.with_indifferent_access) }

      before do
        VCAP::CloudController::ServiceOfferingLabelModel.make(resource_guid: service_offering_1.guid, key_name: 'flavor', value: 'orange')
        VCAP::CloudController::ServiceOfferingLabelModel.make(resource_guid: service_offering_2.guid, key_name: 'flavor', value: 'orange')
        VCAP::CloudController::ServiceOfferingLabelModel.make(resource_guid: service_offering_3.guid, key_name: 'flavor', value: 'apple')
      end

      it 'filters the matching service offerings' do
        expect(service_offerings).to contain_exactly(service_offering_1, service_offering_2)
      end
    end

    describe 'the `space_guids` filter' do
      let(:space_1) { VCAP::CloudController::Space.make }
      let!(:service_broker_1) { VCAP::CloudController::ServiceBroker.make(space: space_1) }
      let!(:service_offering_1) { VCAP::CloudController::Service.make(service_broker: service_broker_1) }

      let(:space_2) { VCAP::CloudController::Space.make }
      let(:service_broker_2) { VCAP::CloudController::ServiceBroker.make(space: space_2) }
      let!(:service_offering_2) { VCAP::CloudController::Service.make(service_broker: service_broker_2) }

      let(:space_3) { VCAP::CloudController::Space.make }
      let(:service_broker_3) { VCAP::CloudController::ServiceBroker.make(space: space_3) }
      let!(:service_offering_3) { VCAP::CloudController::Service.make(service_broker: service_broker_3) }

      let!(:public_plan) { VCAP::CloudController::ServicePlan.make(public: true) }
      let!(:public_service_offering) { public_plan.service }

      let(:filter_space_guids) { [space_1.guid, space_2.guid] }
      let(:space_guids) { [space_1.guid] }
      let(:message) { ServiceOfferingsListMessage.from_params({ space_guids: filter_space_guids.join(',') }.with_indifferent_access) }

      it 'filters the matching service offerings' do
        case current_method
        when :fetch
          expect(service_offerings).to contain_exactly(service_offering_1, service_offering_2, public_service_offering)
        when :fetch_public
          expect(service_offerings).to contain_exactly(public_service_offering)
        when :fetch_visible
          expect(service_offerings).to contain_exactly(service_offering_1, public_service_offering)
        else
          fail('unexpected method')
        end
      end
    end

    describe 'the `organization_guids` filter' do
      let!(:org_1) { VCAP::CloudController::Organization.make }
      let!(:service_broker_1) { VCAP::CloudController::ServiceBroker.make }
      let!(:service_offering_1) { VCAP::CloudController::Service.make(service_broker: service_broker_1) }
      let!(:service_plan_1) { VCAP::CloudController::ServicePlan.make(public: false, service: service_offering_1) }
      let!(:visibility_1) { VCAP::CloudController::ServicePlanVisibility.make(service_plan: service_plan_1, organization: org_1) }

      let!(:org_2) { VCAP::CloudController::Organization.make }
      let!(:service_broker_2) { VCAP::CloudController::ServiceBroker.make }
      let!(:service_offering_2) { VCAP::CloudController::Service.make(service_broker: service_broker_2) }
      let!(:service_plan_2) { VCAP::CloudController::ServicePlan.make(public: false, service: service_offering_2) }
      let!(:visibility_2) { VCAP::CloudController::ServicePlanVisibility.make(service_plan: service_plan_2, organization: org_2) }

      let(:space_3) { VCAP::CloudController::Space.make }
      let(:service_broker_3) { VCAP::CloudController::ServiceBroker.make(space: space_3) }
      let!(:service_offering_3) { VCAP::CloudController::Service.make(service_broker: service_broker_3) }

      let!(:public_plan) { VCAP::CloudController::ServicePlan.make(public: true) }
      let!(:public_service_offering) { public_plan.service }

      let(:filter_org_guids) { [org_1.guid, org_2.guid] }
      let(:org_guids) { [org_1.guid] }
      let(:message) { ServiceOfferingsListMessage.from_params({ organization_guids: filter_org_guids.join(',') }.with_indifferent_access) }

      it 'filters the matching service offerings' do
        case current_method
        when :fetch
          expect(service_offerings).to contain_exactly(service_offering_1, service_offering_2, public_service_offering)
        when :fetch_public
          expect(service_offerings).to contain_exactly(public_service_offering)
        when :fetch_visible
          expect(service_offerings.size).to eq(2)
          expect(service_offerings).to contain_exactly(service_offering_1, public_service_offering)
        else
          fail('unexpected method')
        end
      end
    end
  end

  RSpec.describe ServiceOfferingListFetcher do
    let(:message) { ServiceOfferingsListMessage.from_params({}) }

    describe '#fetch' do
      context 'when there are no service offerings' do
        it 'is empty' do
          service_offerings = ServiceOfferingListFetcher.new.fetch(message).all

          expect(service_offerings).to be_empty
        end
      end

      context 'when there are public, non-public and space-scoped service offerings' do
        let!(:public_service_offering) { ServicePlan.make(public: true, active: true).service }

        let!(:non_public_service_offering) { Service.make(active: true) }

        let!(:space_scoped_service_broker) { ServiceBroker.make(space: Space.make) }
        let!(:space_scoped_service_offering) { Service.make(service_broker: space_scoped_service_broker) }

        it 'lists them all' do
          service_offerings = ServiceOfferingListFetcher.new.fetch(message).all
          expect(service_offerings).to contain_exactly(public_service_offering, non_public_service_offering, space_scoped_service_offering)
        end
      end

      context 'when filters are provided' do
        let(:service_offerings) { ServiceOfferingListFetcher.new.fetch(message).all }

        it_behaves_like 'filtered service offering fetcher', :fetch
      end
    end

    describe '#fetch_public' do
      context 'when there are no public service offerings' do
        let!(:service_offering_1) { ServicePlan.make(public: false, active: true).service }
        let!(:service_offering_2) { ServicePlan.make(public: false, active: true).service }

        it 'is empty' do
          service_offerings = ServiceOfferingListFetcher.new.fetch_public(message).all

          expect(service_offerings).to be_empty
        end
      end

      context 'when there are public service offerings' do
        let!(:service_offering_1) { ServicePlan.make(public: true, active: true).service }
        let!(:service_offering_2) { ServicePlan.make(public: true, active: true).service }

        it 'lists them all' do
          service_offerings = ServiceOfferingListFetcher.new.fetch_public(message).all

          expect(service_offerings).to contain_exactly(service_offering_1, service_offering_2)
        end
      end

      context 'uniqueness of service offerings' do
        let(:service_offering) { Service.make }

        before do
          2.times { ServicePlan.make(service: service_offering, public: true, active: true) }
        end

        it 'de-duplicates service offerings' do
          service_offerings = ServiceOfferingListFetcher.new.fetch_public(message).all

          expect(service_offerings).to contain_exactly(service_offering)
        end
      end

      context 'when filters are provided' do
        let(:service_offerings) { ServiceOfferingListFetcher.new.fetch_public(message).all }

        it_behaves_like 'filtered service offering fetcher', :fetch_public
      end
    end

    describe '#fetch_visible' do
      context 'when there are no service offerings' do
        it 'is empty' do
          service_offerings = ServiceOfferingListFetcher.new.fetch_visible(message, [], []).all

          expect(service_offerings).to be_empty
        end
      end

      context 'when there are public service offerings' do
        let!(:service_offering_1) { ServicePlan.make(public: true, active: true).service }
        let!(:service_offering_2) { ServicePlan.make(public: true, active: true).service }

        it 'lists them all' do
          service_offerings = ServiceOfferingListFetcher.new.fetch_visible(message, [], []).all

          expect(service_offerings).to contain_exactly(service_offering_1, service_offering_2)
        end
      end

      context 'when there are service offerings that are only visible in certain orgs' do
        let!(:organization_1) { Organization.make }
        let!(:organization_2) { Organization.make }
        let!(:service_plan_1) { ServicePlan.make(public: false, active: true) }
        let!(:service_plan_2) { ServicePlan.make(public: false, active: true) }
        let!(:service_plan_3) { ServicePlan.make(public: false, active: true) }
        let!(:service_plan_4) { ServicePlan.make(public: false, active: true) }
        let!(:service_offering_1) { service_plan_1.service }
        let!(:service_offering_2) { service_plan_2.service }
        let!(:service_offering_3) { service_plan_3.service }
        let!(:service_offering_4) { service_plan_4.service }
        let!(:visibility_2) { ServicePlanVisibility.make(service_plan: service_plan_2, organization: organization_1) }
        let!(:visibility_3) { ServicePlanVisibility.make(service_plan: service_plan_3, organization: organization_2) }
        let!(:visibility_4) { ServicePlanVisibility.make(service_plan: service_plan_4, organization: organization_1) }

        it 'lists the ones that are visible in the specified orgs' do
          service_offerings_1 = ServiceOfferingListFetcher.new.fetch_visible(message, [organization_1.guid], []).all
          expect(service_offerings_1).to contain_exactly(service_offering_2, service_offering_4)

          service_offerings_2 = ServiceOfferingListFetcher.new.fetch_visible(message, [organization_1.guid, organization_2.guid], []).all
          expect(service_offerings_2).to contain_exactly(service_offering_2, service_offering_3, service_offering_4)
        end
      end

      context 'when there are service offerings from a space-scoped broker' do
        let!(:space_1) { Space.make }
        let!(:space_2) { Space.make }

        let!(:service_offering_1) { Service.make(active: true) }
        let!(:service_offering_2) { Service.make(active: true) }
        let!(:service_offering_3) { Service.make(active: true) }
        let!(:service_offering_4) { Service.make(active: true) }

        before do
          service_offering_1.service_broker.space = space_1
          service_offering_1.service_broker.save
          service_offering_2.service_broker.space = space_1
          service_offering_2.service_broker.save
          service_offering_3.service_broker.space = space_2
          service_offering_3.service_broker.save
        end

        it 'lists the ones visible in the specified spaces' do
          service_offerings_1 = ServiceOfferingListFetcher.new.fetch_visible(message, [], [space_1.guid]).all
          expect(service_offerings_1).to contain_exactly(service_offering_1, service_offering_2)

          service_offerings_2 = ServiceOfferingListFetcher.new.fetch_visible(message, [], [space_1.guid, space_2.guid]).all
          expect(service_offerings_2).to contain_exactly(service_offering_1, service_offering_2, service_offering_3)
        end
      end

      context 'when there is a mixture of service offerings' do
        # public - can see
        let!(:service_offering_1) { ServicePlan.make(public: true, active: true).service }

        # non public - cannot see
        let!(:service_offering_2) { ServicePlan.make(public: false, active: true).service }

        # visible in org 1 - can see
        let!(:org_1) { Organization.make }
        let!(:org_2) { Organization.make }
        let!(:service_plan_1) { ServicePlan.make(public: false, active: true) }
        let!(:service_offering_3) { service_plan_1.service }
        let!(:visibility_1) { ServicePlanVisibility.make(service_plan: service_plan_1, organization: org_1) }

        # visbible in org 3 - cannot see
        let!(:org_3) { Organization.make }
        let!(:service_plan_2) { ServicePlan.make(public: false, active: true) }
        let!(:service_offering_4) { service_plan_1.service }
        let!(:visibility_2) { ServicePlanVisibility.make(service_plan: service_plan_2, organization: org_3) }

        let!(:space_1) { Space.make }
        let!(:space_2) { Space.make }
        let!(:space_3) { Space.make }
        let!(:service_offering_5) { ServicePlan.make(public: false, active: true).service }
        let!(:service_offering_6) { ServicePlan.make(public: false, active: true).service }
        before do
          service_offering_5.service_broker.space = space_1 # visible if member of space 1 - can see
          service_offering_5.service_broker.save
          service_offering_6.service_broker.space = space_2 # visible if member of space 2 - cannot see
          service_offering_6.service_broker.save
        end

        it 'lists the visible ones' do
          service_offerings = ServiceOfferingListFetcher.new.fetch_visible(message, [org_1.guid, org_2.guid], [space_1.guid, space_3.guid]).all
          expect(service_offerings).to contain_exactly(service_offering_1, service_offering_3, service_offering_5)
        end
      end

      context 'uniqueness of service offerings' do
        let!(:organization_1) { Organization.make }
        let!(:organization_2) { Organization.make }
        let!(:service_plan) { ServicePlan.make(public: false, active: true) }
        let!(:service_offering) { service_plan.service }
        let!(:visibility_1) { ServicePlanVisibility.make(service_plan: service_plan, organization: organization_1) }
        let!(:visibility_2) { ServicePlanVisibility.make(service_plan: service_plan, organization: organization_2) }

        it 'de-duplicates service offerings' do
          service_offerings = ServiceOfferingListFetcher.new.fetch_visible(message, [organization_1.guid, organization_2.guid], []).all
          expect(service_offerings).to contain_exactly(service_offering)
        end
      end

      context 'when filters are provided' do
        let(:org_guids) { [] }
        let(:space_guids) { [] }
        let(:service_offerings) { ServiceOfferingListFetcher.new.fetch_visible(message, org_guids, space_guids).all }

        it_behaves_like 'filtered service offering fetcher', :fetch_visible
      end
    end
  end
end
