require 'spec_helper'
require 'decorators/include_route_policy_source_decorator'

module VCAP::CloudController
  RSpec.describe IncludeRoutePolicySourceDecorator do
    subject(:decorator) { IncludeRoutePolicySourceDecorator }

    let(:domain) { create(:shared_domain, name: 'apps.identity', enforce_route_policies: true) }
    let(:space) { create(:space) }
    let(:route) { create(:route, space:, domain:) }

    before do
      allow(Permissions).to receive(:new).and_return(instance_double(Permissions, can_read_globally?: true))
    end

    describe '.match?' do
      it 'matches when include params contain "source"' do
        expect(decorator.match?(['source'])).to be true
      end

      it 'does not match when include params do not contain "source"' do
        expect(decorator.match?(['route'])).to be false
      end

      it 'does not match nil' do
        expect(decorator.match?(nil)).to be false
      end
    end

    describe '.decorate' do
      let(:app1) { create(:app_model, space:) }
      let(:space1) { create(:space) }
      let(:org1) { space1.organization }
      let(:policy_app) { RoutePolicy.create(source: "cf:app:#{app1.guid}", route_id: route.id) }
      let(:policy_space) { RoutePolicy.create(source: "cf:space:#{space1.guid}", route_id: route.id) }
      let(:policy_org) { RoutePolicy.create(source: "cf:org:#{org1.guid}", route_id: route.id) }
      let(:policy_any) { RoutePolicy.create(source: 'cf:any', route_id: route.id) }

      it 'includes apps, spaces, and orgs from policy sources' do
        hash = decorator.decorate({}, [policy_app, policy_space, policy_org])
        expect(hash[:included][:apps].pluck(:guid)).to contain_exactly(app1.guid)
        expect(hash[:included][:spaces].pluck(:guid)).to contain_exactly(space1.guid)
        expect(hash[:included][:organizations].pluck(:guid)).to contain_exactly(org1.guid)
      end

      it 'omits cf:any sources (no resource to include)' do
        hash = decorator.decorate({}, [policy_any])
        expect(hash[:included][:apps]).to be_empty
        expect(hash[:included][:spaces]).to be_empty
        expect(hash[:included][:organizations]).to be_empty
      end

      it 'does not overwrite other included fields' do
        hash = decorator.decorate({ included: { monkeys: ['zach'] } }, [policy_any])
        expect(hash[:included][:monkeys]).to eq(['zach'])
      end

      context 'when the user cannot read certain source resources' do
        let(:other_space) { create(:space) }
        let(:other_org) { other_space.organization }
        let(:other_app) { create(:app_model, space: other_space) }

        let(:policy_readable_app) { RoutePolicy.create(source: "cf:app:#{app1.guid}", route_id: route.id) }
        let(:policy_unreadable_app) { RoutePolicy.create(source: "cf:app:#{other_app.guid}", route_id: route.id) }
        let(:policy_readable_space) { RoutePolicy.create(source: "cf:space:#{space1.guid}", route_id: route.id) }
        let(:policy_unreadable_space) { RoutePolicy.create(source: "cf:space:#{other_space.guid}", route_id: route.id) }
        let(:policy_readable_org) { RoutePolicy.create(source: "cf:org:#{org1.guid}", route_id: route.id) }
        let(:policy_unreadable_org) { RoutePolicy.create(source: "cf:org:#{other_org.guid}", route_id: route.id) }

        let(:permission_queryer) do
          instance_double(
            Permissions,
            can_read_globally?: false,
            readable_space_guids_query: Space.where(id: [space.id, space1.id]).select(:guid),
            readable_org_guids_query: Organization.where(id: org1.id).select(:guid)
          )
        end

        before do
          allow(Permissions).to receive(:new).and_return(permission_queryer)
        end

        it 'excludes apps the user cannot read' do
          hash = decorator.decorate({}, [policy_readable_app, policy_unreadable_app])
          app_guids = hash[:included][:apps].pluck(:guid)
          expect(app_guids).to include(app1.guid)
          expect(app_guids).not_to include(other_app.guid)
        end

        it 'excludes spaces the user cannot read' do
          hash = decorator.decorate({}, [policy_readable_space, policy_unreadable_space])
          space_guids = hash[:included][:spaces].pluck(:guid)
          expect(space_guids).to include(space1.guid)
          expect(space_guids).not_to include(other_space.guid)
        end

        it 'excludes organizations the user cannot read' do
          hash = decorator.decorate({}, [policy_readable_org, policy_unreadable_org])
          org_guids = hash[:included][:organizations].pluck(:guid)
          expect(org_guids).to include(org1.guid)
          expect(org_guids).not_to include(other_org.guid)
        end
      end
    end
  end
end
