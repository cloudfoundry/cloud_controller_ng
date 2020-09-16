require 'db_spec_helper'
require 'fetchers/service_plan_visibility_fetcher'

module VCAP::CloudController
  RSpec.describe ServicePlanVisibilityFetcher do
    describe '#fetch_orgs' do
      let(:can_read_globally) { false }
      let(:readable_org_guids) { [] }

      let(:permission_querier) {
        double('Permission Querier',
          can_read_globally?: can_read_globally,
          readable_org_guids: readable_org_guids
        )
      }

      let(:fetcher) { ServicePlanVisibilityFetcher.new(permission_querier) }

      let!(:org1) { Organization.make }
      let!(:org2) { Organization.make }

      let!(:plan_1) do
        plan = ServicePlan.make
        ServicePlanVisibility.make(service_plan: plan, organization: org1)
        ServicePlanVisibility.make(service_plan: plan, organization: org2)
        plan
      end

      let!(:plan_2) do
        plan = ServicePlan.make
        ServicePlanVisibility.make(service_plan: plan, organization: org2)
        plan
      end

      describe 'visibility of a single plan' do
        context 'when admin' do
          let(:can_read_globally) { true }

          it 'returns the complete list of orgs' do
            expect(fetcher.fetch_orgs(
                     service_plan_guids: [plan_1.guid]
            )).to contain_exactly(org1, org2)

            expect(fetcher.fetch_orgs(
                     service_plan_guids: [plan_2.guid]
            )).to contain_exactly(org2)
          end
        end

        context 'when both orgs are readable' do
          let(:readable_org_guids) { [org1.guid, org2.guid] }

          it 'returns the complete list of orgs' do
            expect(fetcher.fetch_orgs(
                     service_plan_guids: [plan_1.guid]
            )).to contain_exactly(org1, org2)

            expect(fetcher.fetch_orgs(
                     service_plan_guids: [plan_2.guid]
            )).to contain_exactly(org2)
          end
        end

        context 'when only `org2` is readable' do
          let(:readable_org_guids) { [org2.guid] }

          it 'only returns `org2`' do
            expect(fetcher.fetch_orgs(
                     service_plan_guids: [plan_1.guid]
            )).to contain_exactly(org2)

            expect(fetcher.fetch_orgs(
                     service_plan_guids: [plan_2.guid]
            )).to contain_exactly(org2)
          end
        end

        context 'when only `org1` is readable' do
          let(:readable_org_guids) { [org1.guid] }

          it 'only returns `org1` when visible in org1' do
            expect(fetcher.fetch_orgs(
                     service_plan_guids: [plan_1.guid]
            )).to contain_exactly(org1)
          end

          it 'return empty when the plan is not visible in `org1`' do
            expect(fetcher.fetch_orgs(
                     service_plan_guids: [plan_2.guid]
            )).to be_empty
          end
        end

        context 'when no orgs are readable' do
          it 'returns an empty list' do
            expect(fetcher.fetch_orgs(
                     service_plan_guids: [plan_1.guid]
            )).to be_empty

            expect(fetcher.fetch_orgs(
                     service_plan_guids: [plan_2.guid]
            )).to be_empty
          end
        end
      end

      describe 'variable number of plans' do
        context 'when many plans are specified and only one is visible' do
          let!(:plan_alpha) { ServicePlan.make }
          let!(:plan_beta) { ServicePlan.make }

          context 'when only one org is readable' do
            let(:readable_org_guids) { [org2.guid] }

            it 'returns the visible orgs' do
              expect(fetcher.fetch_orgs(
                       service_plan_guids: [plan_1.guid, plan_alpha.guid, plan_beta.guid]
              )).to contain_exactly(org2)
            end
          end

          context 'when all orgs are readable' do
            let(:readable_org_guids) { [org1.guid, org2.guid] }

            it 'returns all orgs' do
              expect(fetcher.fetch_orgs(
                       service_plan_guids: [plan_1.guid, plan_alpha.guid, plan_beta.guid]
              )).to contain_exactly(org1, org2)
            end
          end

          context 'when user is admin' do
            let(:can_read_globally) { true }

            it 'returns all orgs' do
              expect(fetcher.fetch_orgs(
                       service_plan_guids: [plan_1.guid, plan_alpha.guid, plan_beta.guid]
              )).to contain_exactly(org1, org2)
            end
          end
        end
      end

      context 'when no plans are specified' do
        context 'when user is admin' do
          let(:can_read_globally) { true }
          it 'returns an empty list' do
            expect(fetcher.fetch_orgs(
                     service_plan_guids: []
            )).to be_empty
          end
        end

        context 'when all orgs are readable' do
          let(:readable_org_guids) { [org1.guid, org2.guid] }
          it 'returns an empty list' do
            expect(fetcher.fetch_orgs(
                     service_plan_guids: []
            )).to be_empty
          end
        end
      end
    end
  end
end
