require 'db_spec_helper'
require 'fetchers/service_plan_list_fetcher'
require 'messages/service_plans_list_message'

module VCAP::CloudController
  RSpec.describe ServicePlanListFetcher do
    let(:message) { ServicePlansListMessage.from_params({}) }
    let(:fetcher) { described_class }

    describe '#fetch' do
      context 'when there are no plans' do
        it 'is empty' do
          service_plans = fetcher.fetch(message, omniscient: true).all
          expect(service_plans).to be_empty
        end
      end

      context 'when there is a plan' do
        before do
          make_public_plan
        end

        it 'eager loads the specified resources' do
          dataset = fetcher.fetch(message, omniscient: true, eager_loaded_associations: [:labels])

          expect(dataset.all.first.associations.key?(:labels)).to be true
          expect(dataset.all.first.associations.key?(:annotations)).to be false
        end
      end

      describe 'visibility of plans' do
        let!(:public_plan_1) { make_public_plan }
        let!(:public_plan_2) { make_public_plan }

        let!(:private_plan_1) { make_private_plan }
        let!(:private_plan_2) { make_private_plan }

        let(:org_1) { Organization.make }
        let(:org_2) { Organization.make }
        let(:org_3) { Organization.make }
        let!(:org_restricted_plan_1) { make_org_restricted_plan(org_1) }
        let!(:org_restricted_plan_2) { make_org_restricted_plan(org_2) }
        let!(:org_restricted_plan_3) { make_org_restricted_plan(org_3) }
        let!(:org_restricted_plan_4) { make_org_restricted_plan(org_3) }

        let(:space_1) { Space.make(organization: org_1) }
        let(:space_2) { Space.make(organization: org_2) }
        let(:space_3) { Space.make(organization: org_3) }
        let!(:space_scoped_plan_1) { make_space_scoped_plan(space_1) }
        let!(:space_scoped_plan_2) { make_space_scoped_plan(space_2) }
        let!(:space_scoped_plan_3) { make_space_scoped_plan(space_3) }
        let!(:space_scoped_plan_4) { make_space_scoped_plan(space_3) }

        context 'when no authorization is specified' do
          it 'only fetches public plans' do
            service_plans = fetcher.fetch(message).all
            expect(service_plans).to contain_exactly(public_plan_1, public_plan_2)
          end
        end

        context 'when the `omniscient` flag is true' do
          it 'fetches all plans' do
            service_plans = fetcher.fetch(message, omniscient: true).all
            expect(service_plans).to contain_exactly(
              public_plan_1,
              public_plan_2,
              private_plan_1,
              private_plan_2,
              space_scoped_plan_1,
              space_scoped_plan_2,
              space_scoped_plan_3,
              space_scoped_plan_4,
              org_restricted_plan_1,
              org_restricted_plan_2,
              org_restricted_plan_3,
              org_restricted_plan_4,
            )
          end
        end

        context 'when `readable_org_guids` are specified' do
          it 'includes public plans and ones for those orgs' do
            service_plans = fetcher.fetch(
              message,
              readable_org_guids: [org_1.guid, org_3.guid],
              readable_space_guids: [],
            ).all

            expect(service_plans).to contain_exactly(
              public_plan_1,
              public_plan_2,
              org_restricted_plan_1,
              org_restricted_plan_3,
              org_restricted_plan_4,
            )
          end
        end

        context 'when both `readable_space_guids` and `readable_org_guids` are specified' do
          it 'includes public plans, ones for those spaces and ones for those orgs' do
            service_plans = fetcher.fetch(
              message,
              readable_space_guids: [space_3.guid],
              readable_org_guids: [org_3.guid],
            ).all

            expect(service_plans).to contain_exactly(
              public_plan_1,
              public_plan_2,
              space_scoped_plan_3,
              space_scoped_plan_4,
              org_restricted_plan_3,
              org_restricted_plan_4,
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

        let!(:public_plan) { make_public_plan }

        let!(:org_restricted_plan_1) { make_org_restricted_plan(org_1) }
        let!(:org_restricted_plan_2) { make_org_restricted_plan(org_2) }
        let!(:org_restricted_plan_3) { make_org_restricted_plan(org_3) }

        let!(:space_scoped_plan_1) { make_space_scoped_plan(space_1) }
        let!(:space_scoped_plan_2) { make_space_scoped_plan(space_2) }
        let!(:space_scoped_plan_3) { make_space_scoped_plan(space_3) }

        describe 'organization_guids' do
          context 'omniscient' do
            it 'can filter plans by organization guids' do
              message = ServicePlansListMessage.from_params({
                organization_guids: [org_1.guid, org_2.guid].join(',')
              }.with_indifferent_access)

              service_plans = fetcher.fetch(message, omniscient: true).all

              expect(service_plans).to contain_exactly(org_restricted_plan_1, org_restricted_plan_2, public_plan, space_scoped_plan_1, space_scoped_plan_2)
            end

            it 'only shows public plans when there are no matches' do
              message = ServicePlansListMessage.from_params({
                organization_guids: 'non-matching-guid',
              }.with_indifferent_access)

              service_plans = fetcher.fetch(message, omniscient: true).all

              expect(service_plans).to contain_exactly(public_plan)
            end
          end

          context 'only some orgs are readable (ORG_AUDITOR etc)' do
            it 'shows only readable plans' do
              message = ServicePlansListMessage.from_params({
                organization_guids: [org_1.guid, org_2.guid].join(',')
              }.with_indifferent_access)

              service_plans = fetcher.fetch(
                message,
                readable_org_guids: [org_1.guid],
                readable_space_guids: [],
              ).all

              expect(service_plans).to contain_exactly(org_restricted_plan_1, public_plan)
            end
          end

          context 'no orgs are readable' do
            it 'shows only public plans' do
              message = ServicePlansListMessage.from_params({
                organization_guids: [org_1.guid, org_2.guid].join(',')
              }.with_indifferent_access)

              service_plans = fetcher.fetch(
                message,
                readable_org_guids: [],
                readable_space_guids: [],
              ).all

              expect(service_plans).to contain_exactly(public_plan)
            end
          end

          context 'when the user only has access to some spaces in an org' do
            let(:space_1a) { Space.make(organization: org_1) }
            let!(:space_scoped_plan_1a) { make_space_scoped_plan(space_1a) }

            it 'only shows space-scoped plans for the readable spaces' do
              message = ServicePlansListMessage.from_params({
                organization_guids: [org_1.guid].join(',')
              }.with_indifferent_access)

              service_plans = fetcher.fetch(
                message,
                readable_org_guids: [org_1.guid],
                readable_space_guids: [space_1.guid],
              ).all

              expect(service_plans).to contain_exactly(public_plan, org_restricted_plan_1, space_scoped_plan_1)
            end
          end
        end

        describe 'space_guids' do
          context 'omniscient' do
            it 'can filter by space guids' do
              message = ServicePlansListMessage.from_params({
                space_guids: [space_1.guid, space_2.guid].join(',')
              }.with_indifferent_access)
              service_plans = fetcher.fetch(message, omniscient: true).all
              expect(service_plans).to contain_exactly(space_scoped_plan_1, org_restricted_plan_1, space_scoped_plan_2, org_restricted_plan_2, public_plan)
            end

            it 'only shows public plans when there are no matches' do
              message = ServicePlansListMessage.from_params({
                space_guids: 'non-matching-guid'
              }.with_indifferent_access)
              service_plans = fetcher.fetch(message, omniscient: true).all
              expect(service_plans).to contain_exactly(public_plan)
            end
          end

          context 'only some spaces are readable (SPACE_DEVELOPER, SPACE_AUDITOR etc)' do
            it 'shows only plans for readable spaces and orgs' do
              message = ServicePlansListMessage.from_params({
                space_guids: [space_1.guid, space_2.guid].join(',')
              }.with_indifferent_access)
              service_plans = fetcher.fetch(
                message,
                readable_org_guids: [org_1.guid],
                readable_space_guids: [space_1.guid],
              ).all
              expect(service_plans).to contain_exactly(space_scoped_plan_1, org_restricted_plan_1, public_plan)
            end
          end

          context 'when a filter contains a space guid that the user cannot access' do
            it 'ignores the unauthorized space guid' do
              message = ServicePlansListMessage.from_params({
                space_guids: [space_1.guid, space_2.guid].join(',')
              }.with_indifferent_access)
              service_plans = fetcher.fetch(
                message,
                readable_org_guids: [org_1.guid, org_2.guid],
                readable_space_guids: [space_1.guid],
              ).all
              expect(service_plans).to contain_exactly(space_scoped_plan_1, org_restricted_plan_1, public_plan)
            end
          end

          context 'no spaces are readable' do
            it 'shows only public plans' do
              message = ServicePlansListMessage.from_params({
                space_guids: [space_1.guid, space_2.guid].join(',')
              }.with_indifferent_access)

              service_plans = fetcher.fetch(
                message,
                readable_org_guids: [],
                readable_space_guids: [],
              ).all

              expect(service_plans).to contain_exactly(public_plan)
            end
          end
        end

        describe 'organization_guids and space_guids together' do
          context 'omniscient' do
            it 'results in the overlap' do
              message = ServicePlansListMessage.from_params({
                space_guids: [space_1.guid, space_2.guid].join(','),
                organization_guids: [org_2.guid, org_3.guid].join(',')
              }.with_indifferent_access)
              service_plans = fetcher.fetch(message, omniscient: true).all
              expect(service_plans).to contain_exactly(space_scoped_plan_2, org_restricted_plan_2, public_plan)
            end

            it 'only shows public plans when there are no matches' do
              message = ServicePlansListMessage.from_params({
                space_guids: [space_1.guid].join(','),
                organization_guids: [org_3.guid].join(',')
              }.with_indifferent_access)
              service_plans = fetcher.fetch(message, omniscient: true).all
              expect(service_plans).to contain_exactly(public_plan)
            end
          end

          context 'when only some spaces and orgs are visible' do
            it 'excludes plans that do not meet all the filter conditions' do
              message = ServicePlansListMessage.from_params({
                space_guids: [space_1.guid, space_2.guid].join(','),
                organization_guids: [org_2.guid, org_3.guid].join(',')
              }.with_indifferent_access)
              service_plans = fetcher.fetch(
                message,
                readable_org_guids: [org_1.guid, org_2.guid],
                readable_space_guids: [space_1.guid],
              ).all
              expect(service_plans).to contain_exactly(public_plan)
            end
          end
        end
      end

      describe 'other filters' do
        RSpec.shared_examples 'filtered service plans fetcher' do
          let(:message) { ServicePlansListMessage.from_params(params.with_indifferent_access) }

          describe 'available' do
            let!(:available_plan) { ServicePlan.make(public: true, active: true) }
            let!(:unavailable_plan) { ServicePlan.make(public: true, active: false) }
            let(:params) { {} }

            it 'returns both when there is no filter' do
              expect(service_plans).to contain_exactly(available_plan, unavailable_plan)
            end

            context 'when `available=true`' do
              let(:params) { { available: 'true' } }

              it 'can filter on available plans' do
                expect(service_plans).to contain_exactly(available_plan)
              end
            end

            context 'when `available=false`' do
              let(:params) { { available: 'false' } }

              it 'can filter on unavailable plans' do
                expect(service_plans).to contain_exactly(unavailable_plan)
              end
            end
          end

          describe 'service_broker_guids' do
            let(:service_broker) { ServiceBroker.make }
            let(:service_offering) { Service.make(service_broker: service_broker) }
            let!(:plan_1) { ServicePlan.make(service: service_offering) }
            let!(:plan_2) { ServicePlan.make(service: service_offering) }
            let!(:plan_3) { ServicePlan.make }
            let!(:plan_4) { ServicePlan.make }
            let(:params) { { service_broker_guids: [service_broker.guid, plan_4.service.service_broker.guid].join(',') } }

            it 'can filter by service broker guids' do
              expect(service_plans).to contain_exactly(plan_1, plan_2, plan_4)
            end
          end

          describe 'service_broker_names' do
            let(:service_broker) { ServiceBroker.make }
            let(:service_offering) { Service.make(service_broker: service_broker) }
            let!(:plan_1) { ServicePlan.make(service: service_offering) }
            let!(:plan_2) { ServicePlan.make(service: service_offering) }
            let!(:plan_3) { ServicePlan.make }
            let!(:plan_4) { ServicePlan.make }
            let(:params) { { service_broker_names: [service_broker.name, plan_3.service.service_broker.name].join(',') } }

            it 'can filter by service broker names' do
              expect(service_plans).to contain_exactly(plan_1, plan_2, plan_3)
            end
          end

          describe 'service_instance_guids' do
            let!(:plan_1) { ServicePlan.make }
            let!(:plan_2) { ServicePlan.make }
            let!(:plan_3) { ServicePlan.make }
            let!(:plan_4) { ServicePlan.make }

            let!(:instance_1) { ManagedServiceInstance.make(service_plan: plan_1) }
            let!(:instance_2) { ManagedServiceInstance.make(service_plan: plan_2) }
            let!(:instance_3) { ManagedServiceInstance.make(service_plan: plan_3) }
            let!(:instance_4) { ManagedServiceInstance.make(service_plan: plan_1) }

            let(:params) { { service_instance_guids: [instance_1.guid, instance_2.guid].join(',') } }

            it 'can filter by service instance guids' do
              expect(service_plans).to contain_exactly(plan_1, plan_2)
            end
          end

          describe 'service_offering_guids' do
            let(:service_offering) { Service.make }
            let!(:plan_1) { ServicePlan.make(service: service_offering) }
            let!(:plan_2) { ServicePlan.make(service: service_offering) }
            let!(:plan_3) { ServicePlan.make }
            let!(:plan_4) { ServicePlan.make }
            let(:params) { { service_offering_guids: [service_offering.guid, plan_3.service.guid].join(',') } }

            it 'can filter by service offering guids' do
              expect(service_plans).to contain_exactly(plan_1, plan_2, plan_3)
            end
          end

          describe 'service_offering_names' do
            let(:service_offering) { Service.make }
            let!(:plan_1) { ServicePlan.make(service: service_offering) }
            let!(:plan_2) { ServicePlan.make(service: service_offering) }
            let!(:plan_3) { ServicePlan.make }
            let!(:plan_4) { ServicePlan.make }
            let(:params) { { service_offering_names: [service_offering.name, plan_3.service.name].join(',') } }

            it 'can filter by service offering names' do
              expect(service_plans).to contain_exactly(plan_1, plan_2, plan_3)
            end
          end

          describe 'broker_catalog_ids' do
            let(:service_offering) { Service.make }
            let!(:plan_1) { ServicePlan.make(service: service_offering) }
            let!(:plan_2) { ServicePlan.make(service: service_offering) }
            let!(:plan_3) { ServicePlan.make }
            let!(:plan_4) { ServicePlan.make }
            let(:params) { { broker_catalog_ids: [plan_1.unique_id, plan_4.unique_id].join(',') } }

            it 'can filter by service broker guids' do
              expect(service_plans).to contain_exactly(plan_1, plan_4)
            end
          end

          describe 'names' do
            let!(:plan_one) { ServicePlan.make(name: 'one', public: true) }
            let!(:plan_two) { ServicePlan.make(name: 'two', public: true) }
            let!(:plan_three) { ServicePlan.make(name: 'three', public: true) }
            let(:params) { { names: 'one,three' } }

            it 'can filter by names' do
              expect(service_plans).to contain_exactly(plan_one, plan_three)
            end
          end

          describe 'label_selector' do
            let!(:service_plan_1) { VCAP::CloudController::ServicePlan.make(public: true, active: true) }
            let!(:service_plan_2) { VCAP::CloudController::ServicePlan.make(public: true, active: true) }
            let!(:service_plan_3) { VCAP::CloudController::ServicePlan.make(public: true, active: true) }
            let(:message) { ServicePlansListMessage.from_params({ label_selector: 'flavor=orange' }.with_indifferent_access) }

            before do
              VCAP::CloudController::ServicePlanLabelModel.make(resource_guid: service_plan_1.guid, key_name: 'flavor', value: 'orange')
              VCAP::CloudController::ServicePlanLabelModel.make(resource_guid: service_plan_2.guid, key_name: 'flavor', value: 'orange')
              VCAP::CloudController::ServicePlanLabelModel.make(resource_guid: service_plan_3.guid, key_name: 'flavor', value: 'apple')
            end

            it 'filters the matching service plans' do
              expect(service_plans).to contain_exactly(service_plan_1, service_plan_2)
            end
          end
        end

        context 'when omniscient' do
          let(:service_plans) { fetcher.fetch(message, omniscient: true).all }

          it_behaves_like 'filtered service plans fetcher'
        end

        context 'when org user' do
          let(:org_1) { Organization.make }
          let(:space_1) { Space.make(organization: org_1) }
          let(:service_plans) { fetcher.fetch(message, omniscient: false, readable_space_guids: [space_1.guid], readable_org_guids: [org_1.guid]).all }

          it_behaves_like 'filtered service plans fetcher'
        end

        context 'when not logged in' do
          let(:service_plans) { fetcher.fetch(message, omniscient: false).all }

          it_behaves_like 'filtered service plans fetcher'
        end
      end

      def make_public_plan
        ServicePlan.make(public: true, active: true, name: "public-#{Sham.name}")
      end

      def make_private_plan
        ServicePlan.make(public: false, active: true, name: "private-#{Sham.name}")
      end

      def make_space_scoped_plan(space)
        service_broker = ServiceBroker.make(space: space)
        service_offering = Service.make(service_broker: service_broker)
        ServicePlan.make(service: service_offering, name: "space-scoped-#{Sham.name}")
      end

      def make_org_restricted_plan(org)
        service_plan = ServicePlan.make(public: false, name: "org-restricted-#{Sham.name}")
        ServicePlanVisibility.make(organization: org, service_plan: service_plan)
        service_plan
      end
    end
  end
end
