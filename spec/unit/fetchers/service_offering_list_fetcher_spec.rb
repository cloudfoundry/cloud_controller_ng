require 'db_spec_helper'
require 'fetchers/service_offering_list_fetcher'
require 'messages/service_offerings_list_message'

module VCAP::CloudController
  RSpec.describe ServiceOfferingListFetcher do
    let(:message) { ServiceOfferingsListMessage.from_params({}) }
    let(:fetcher) { described_class }

    describe '#fetch' do
      context 'when there are no offerings' do
        it 'is empty' do
          service_offerings = ServiceOfferingListFetcher.fetch(message, omniscient: true).all
          expect(service_offerings).to be_empty
        end
      end

      describe 'visibility of offerings' do
        let!(:public_offering_1) { make_public_offering }
        let!(:public_offering_2) { make_public_offering }

        let!(:private_offering_1) { make_private_offering }
        let!(:private_offering_2) { make_private_offering }

        let(:org_1) { Organization.make }
        let(:org_2) { Organization.make }
        let(:org_3) { Organization.make }
        let!(:org_restricted_offering_1) { make_org_restricted_offering(org_1) }
        let!(:org_restricted_offering_2) { make_org_restricted_offering(org_2) }
        let!(:org_restricted_offering_3) { make_org_restricted_offering(org_3) }
        let!(:org_restricted_offering_4) { make_org_restricted_offering(org_3) }

        let(:space_1) { Space.make(organization: org_1) }
        let(:space_2) { Space.make(organization: org_2) }
        let(:space_3) { Space.make(organization: org_3) }
        let!(:space_scoped_offering_1) { make_space_scoped_offering(space_1) }
        let!(:space_scoped_offering_2) { make_space_scoped_offering(space_2) }
        let!(:space_scoped_offering_3) { make_space_scoped_offering(space_3) }
        let!(:space_scoped_offering_4) { make_space_scoped_offering(space_3) }

        context 'when no authorization is specified' do
          it 'only fetches public plans' do
            service_offerings = fetcher.fetch(message).all
            expect(service_offerings).to contain_exactly(public_offering_1, public_offering_2)
          end
        end

        context 'when the `omniscient` flag is true' do
          it 'fetches all plans' do
            service_offerings = fetcher.fetch(message, omniscient: true).all
            expect(service_offerings).to contain_exactly(
              public_offering_1,
              public_offering_2,
              private_offering_1,
              private_offering_2,
              space_scoped_offering_1,
              space_scoped_offering_2,
              space_scoped_offering_3,
              space_scoped_offering_4,
              org_restricted_offering_1,
              org_restricted_offering_2,
              org_restricted_offering_3,
              org_restricted_offering_4,
            )
          end
        end

        context 'when `readable_org_guids` are specified' do
          it 'includes public plans and ones for those orgs' do
            service_offerings = fetcher.fetch(
              message,
              readable_org_guids: [org_1.guid, org_3.guid],
              readable_space_guids: [],
            ).all

            expect(service_offerings).to contain_exactly(
              public_offering_1,
              public_offering_2,
              org_restricted_offering_1,
              org_restricted_offering_3,
              org_restricted_offering_4,
            )
          end
        end

        context 'when both `readable_space_guids` and `readable_org_guids` are specified' do
          it 'includes public plans, ones for those spaces and ones for those orgs' do
            service_offerings = fetcher.fetch(
              message,
              readable_space_guids: [space_3.guid],
              readable_org_guids: [org_3.guid],
            ).all

            expect(service_offerings).to contain_exactly(
              public_offering_1,
              public_offering_2,
              space_scoped_offering_3,
              space_scoped_offering_4,
              org_restricted_offering_3,
              org_restricted_offering_4,
            )
          end
        end
      end

      describe 'filtering by organization_guids and space_guids' do
        let(:org_1) { Organization.make }
        let(:org_2) { Organization.make }
        let(:org_3) { Organization.make }
        let(:space_1) { Space.make(organization: org_1) }
        let(:space_2) { Space.make(organization: org_2) }
        let(:space_3) { Space.make(organization: org_3) }

        let!(:public_offering) { make_public_offering }

        let!(:org_restricted_offering_1) { make_org_restricted_offering(org_1) }
        let!(:org_restricted_offering_2) { make_org_restricted_offering(org_2) }
        let!(:org_restricted_offering_3) { make_org_restricted_offering(org_3) }

        let!(:space_scoped_offering_1) { make_space_scoped_offering(space_1) }
        let!(:space_scoped_offering_2) { make_space_scoped_offering(space_2) }
        let!(:space_scoped_offering_3) { make_space_scoped_offering(space_3) }

        describe 'organization_guids' do
          context 'omniscient' do
            it 'can filter plans by organization guids' do
              message = ServiceOfferingsListMessage.from_params({
                organization_guids: [org_1.guid, org_2.guid].join(',')
              }.with_indifferent_access)

              service_offerings = ServiceOfferingListFetcher.fetch(message, omniscient: true).all

              expect(service_offerings).to contain_exactly(org_restricted_offering_1, org_restricted_offering_2, public_offering, space_scoped_offering_1, space_scoped_offering_2)
            end

            it 'only shows public plans when there are no matches' do
              message = ServiceOfferingsListMessage.from_params({
                organization_guids: 'non-matching-guid',
              }.with_indifferent_access)

              service_offerings = ServiceOfferingListFetcher.fetch(message, omniscient: true).all

              expect(service_offerings).to contain_exactly(public_offering)
            end
          end

          context 'only some orgs are readable (ORG_AUDITOR etc)' do
            it 'shows only readable plans' do
              message = ServiceOfferingsListMessage.from_params({
                organization_guids: [org_1.guid, org_2.guid].join(',')
              }.with_indifferent_access)

              service_offerings = ServiceOfferingListFetcher.fetch(
                message,
                readable_org_guids: [org_1.guid],
                readable_space_guids: [],
              ).all

              expect(service_offerings).to contain_exactly(org_restricted_offering_1, public_offering)
            end
          end

          context 'no orgs are readable' do
            it 'shows only public plans' do
              message = ServiceOfferingsListMessage.from_params({
                organization_guids: [org_1.guid, org_2.guid].join(',')
              }.with_indifferent_access)

              service_offerings = ServiceOfferingListFetcher.fetch(
                message,
                readable_org_guids: [],
                readable_space_guids: [],
              ).all

              expect(service_offerings).to contain_exactly(public_offering)
            end
          end

          context 'when the user only has access to some spaces in an org' do
            let(:space_1a) { Space.make(organization: org_1) }
            let!(:space_scoped_offering_1a) { make_space_scoped_offering(space_1a) }

            it 'only shows space-scoped plans for the readable spaces' do
              message = ServiceOfferingsListMessage.from_params({
                organization_guids: [org_1.guid].join(',')
              }.with_indifferent_access)

              service_offerings = ServiceOfferingListFetcher.fetch(
                message,
                readable_org_guids: [org_1.guid],
                readable_space_guids: [space_1.guid],
              ).all

              expect(service_offerings).to contain_exactly(public_offering, org_restricted_offering_1, space_scoped_offering_1)
            end
          end
        end

        describe 'space_guids' do
          context 'omniscient' do
            it 'can filter by space guids' do
              message = ServiceOfferingsListMessage.from_params({
                space_guids: [space_1.guid, space_2.guid].join(',')
              }.with_indifferent_access)
              service_offerings = ServiceOfferingListFetcher.fetch(message, omniscient: true).all
              expect(service_offerings).to contain_exactly(space_scoped_offering_1, org_restricted_offering_1, space_scoped_offering_2, org_restricted_offering_2, public_offering)
            end

            it 'only shows public plans when there are no matches' do
              message = ServiceOfferingsListMessage.from_params({
                space_guids: 'non-matching-guid'
              }.with_indifferent_access)
              service_offerings = ServiceOfferingListFetcher.fetch(message, omniscient: true).all
              expect(service_offerings).to contain_exactly(public_offering)
            end
          end

          context 'only some spaces are readable (SPACE_DEVELOPER, SPACE_AUDITOR etc)' do
            it 'shows only plans for readable spaces and orgs' do
              message = ServiceOfferingsListMessage.from_params({
                space_guids: [space_1.guid, space_2.guid].join(',')
              }.with_indifferent_access)
              service_offerings = ServiceOfferingListFetcher.fetch(
                message,
                readable_org_guids: [org_1.guid],
                readable_space_guids: [space_1.guid],
              ).all
              expect(service_offerings).to contain_exactly(space_scoped_offering_1, org_restricted_offering_1, public_offering)
            end
          end

          context 'when a filter contains a space guid that the user cannot access' do
            it 'ignores the unauthorized space guid' do
              message = ServiceOfferingsListMessage.from_params({
                space_guids: [space_1.guid, space_2.guid].join(',')
              }.with_indifferent_access)
              service_offerings = ServiceOfferingListFetcher.fetch(
                message,
                readable_org_guids: [org_1.guid, org_2.guid],
                readable_space_guids: [space_1.guid],
              ).all
              expect(service_offerings).to contain_exactly(space_scoped_offering_1, org_restricted_offering_1, public_offering)
            end
          end

          context 'no spaces are readable' do
            it 'shows only public plans' do
              message = ServiceOfferingsListMessage.from_params({
                space_guids: [space_1.guid, space_2.guid].join(',')
              }.with_indifferent_access)

              service_offerings = ServiceOfferingListFetcher.fetch(
                message,
                readable_org_guids: [],
                readable_space_guids: [],
              ).all

              expect(service_offerings).to contain_exactly(public_offering)
            end
          end
        end

        describe 'organization_guids and space_guids together' do
          context 'omniscient' do
            it 'results in the overlap' do
              message = ServiceOfferingsListMessage.from_params({
                space_guids: [space_1.guid, space_2.guid].join(','),
                organization_guids: [org_2.guid, org_3.guid].join(',')
              }.with_indifferent_access)
              service_offerings = ServiceOfferingListFetcher.fetch(message, omniscient: true).all
              expect(service_offerings).to contain_exactly(space_scoped_offering_2, org_restricted_offering_2, public_offering)
            end

            it 'only shows public plans when there are no matches' do
              message = ServiceOfferingsListMessage.from_params({
                space_guids: [space_1.guid].join(','),
                organization_guids: [org_3.guid].join(',')
              }.with_indifferent_access)
              service_offerings = ServiceOfferingListFetcher.fetch(message, omniscient: true).all
              expect(service_offerings).to contain_exactly(public_offering)
            end
          end

          context 'when only some spaces and orgs are visible' do
            it 'excludes plans that do not meet all the filter conditions' do
              message = ServiceOfferingsListMessage.from_params({
                space_guids: [space_1.guid, space_2.guid].join(','),
                organization_guids: [org_2.guid, org_3.guid].join(',')
              }.with_indifferent_access)
              service_offerings = ServiceOfferingListFetcher.fetch(
                message,
                readable_org_guids: [org_1.guid, org_2.guid],
                readable_space_guids: [space_1.guid],
              ).all
              expect(service_offerings).to contain_exactly(public_offering)
            end
          end
        end
      end

      describe 'other filters' do
        let(:service_offerings) { ServiceOfferingListFetcher.fetch(message, omniscient: true).all }

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
      end

      describe 'eager loading' do
        let!(:offering) { make_public_offering }

        it 'eager loads the specified resources for the processes' do
          dataset = fetcher.fetch(message, eager_loaded_associations: [:labels])

          expect(dataset.all.first.associations.key?(:labels)).to be true
          expect(dataset.all.first.associations.key?(:annotations)).to be false
        end
      end
    end

    def make_public_offering
      service_offering = Service.make(label: "public-#{Sham.name}")
      ServicePlan.make(public: true, active: true, service: service_offering)
      service_offering
    end

    def make_private_offering
      service_offering = Service.make(label: "private-#{Sham.name}")
      ServicePlan.make(public: false, active: true, service: service_offering)
      service_offering
    end

    def make_space_scoped_offering(space)
      service_broker = ServiceBroker.make(space: space)
      Service.make(service_broker: service_broker, label: "space-scoped-#{Sham.name}")
    end

    def make_org_restricted_offering(org)
      service_offering = Service.make(label: "org-restricted-#{Sham.name}")
      service_plan = ServicePlan.make(public: false, service: service_offering)
      ServicePlanVisibility.make(organization: org, service_plan: service_plan)
      service_offering
    end
  end
end
