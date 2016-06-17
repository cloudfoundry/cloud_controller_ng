# encoding: utf-8
require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::Space, type: :model do
    it { is_expected.to have_timestamp_columns }

    describe 'Validations' do
      it { is_expected.to validate_presence :name }
      it { is_expected.to validate_presence :organization }
      it { is_expected.to validate_uniqueness [:organization_id, :name] }
      it { is_expected.to strip_whitespace :name }

      context 'name' do
        subject(:space) { Space.make }

        it 'should allow standard ascii character' do
          space.name = "A -_- word 2!?()\'\"&+."
          expect {
            space.save
          }.to_not raise_error
        end

        it 'should allow backslash character' do
          space.name = 'a\\word'
          expect {
            space.save
          }.to_not raise_error
        end

        it 'should allow unicode characters' do
          space.name = '防御力¡'
          expect {
            space.save
          }.to_not raise_error
        end

        it 'should not allow newline character' do
          space.name = "a \n word"
          expect {
            space.save
          }.to raise_error(Sequel::ValidationFailed)
        end

        it 'should not allow escape character' do
          space.name = "a \e word"
          expect {
            space.save
          }.to raise_error(Sequel::ValidationFailed)
        end
      end

      context 'organization' do
        it 'fails when changing' do
          expect { Space.make.organization = Organization.make }.to raise_error Space::OrganizationAlreadySet
        end
      end
    end

    describe 'Associations' do
      it { is_expected.to have_associated :organization, associated_instance: ->(space) { space.organization } }
      it { is_expected.to have_associated :apps }
      it { is_expected.to have_associated :events }
      it { is_expected.to have_associated :service_instances, class: UserProvidedServiceInstance }
      it { is_expected.to have_associated :managed_service_instances }
      it { is_expected.to have_associated :routes, associated_instance: ->(space) { Route.make(space: space) } }
      it { is_expected.to have_associated :security_groups }
      it { is_expected.to have_associated :default_users, class: User }
      it { is_expected.to have_associated :domains, class: SharedDomain }
      it { is_expected.to have_associated :space_quota_definition, associated_instance: ->(space) { SpaceQuotaDefinition.make(organization: space.organization) } }

      describe 'space_quota_definition' do
        subject(:space) { Space.make }

        it 'fails when the space quota is from another organization' do
          new_quota = SpaceQuotaDefinition.make
          space.space_quota_definition = new_quota
          expect { space.save }.to raise_error(Sequel::ValidationFailed)
        end

        it 'allows nil' do
          expect { space.space_quota_definition = nil }.not_to raise_error
        end
      end

      describe 'domains' do
        subject(:space) { Space.make(organization: organization) }
        let(:organization) { Organization.make }

        context 'listing domains' do
          before do
            PrivateDomain.make(owning_organization: space.organization)
          end

          it "should list the owning organization's domains and shared domains" do
            expect(space.domains).to match_array(organization.domains)
          end
        end

        context 'adding domains' do
          it 'does not add the domain to the space if it is a shared domain' do
            shared_domain = SharedDomain.make
            expect { space.add_domain(shared_domain) }.not_to change { space.domains }
          end

          it "does nothing if the private domain already belongs to the space's org" do
            org = Organization.make
            private_domain = PrivateDomain.make(owning_organization: org)
            space = Space.make(organization: org)
            expect { space.add_domain(private_domain) }.not_to change { space.domains }
          end

          it 'reports an error if the private domain belongs to another org' do
            space_org = Organization.make
            space = Space.make(organization: space_org)

            domain_org = Organization.make
            private_domain = PrivateDomain.make(owning_organization: domain_org)
            expect { space.add_domain(private_domain) }.to raise_error(Domain::UnauthorizedAccessToPrivateDomain)
          end
        end
      end

      describe '#domains (eager loading)' do
        before { SharedDomain.dataset.destroy }

        it 'is able to eager load domains' do
          space = Space.make
          org = space.organization

          private_domain1 = PrivateDomain.make(owning_organization: org)
          private_domain2 = PrivateDomain.make(owning_organization: org)
          shared_domain = SharedDomain.make

          expect {
            @eager_loaded_space = Space.eager(:domains).where(id: space.id).all.first
          }.to have_queried_db_times(/domains/i, 1)

          expect {
            @eager_loaded_domains = @eager_loaded_space.domains.to_a
          }.to have_queried_db_times(//, 0)

          expect(@eager_loaded_space).to eql(space)
          expect(@eager_loaded_domains).to eql([private_domain1, private_domain2, shared_domain])
          expect(@eager_loaded_domains).to eql(org.domains)
        end

        it 'has correct domains for each space' do
          space1 = Space.make
          space2 = Space.make

          org1 = space1.organization
          org2 = space2.organization

          private_domain1 = PrivateDomain.make(owning_organization: org1)
          private_domain2 = PrivateDomain.make(owning_organization: org2)

          shared_domain = SharedDomain.make

          expect {
            @eager_loaded_spaces = Space.eager(:domains).where(id: [space1.id, space2.id]).limit(2).all
          }.to have_queried_db_times(/domains/i, 1)

          expected_domains = [private_domain1, shared_domain, private_domain2, shared_domain]

          expect {
            expect(@eager_loaded_spaces).to have(2).items
            actual_domains = @eager_loaded_spaces[0].domains + @eager_loaded_spaces[1].domains
            expect(actual_domains).to match_array(expected_domains)
          }.to have_queried_db_times(//, 0)
        end

        it 'passes in dataset to be loaded to eager_block option' do
          space = Space.make
          org = space.organization

          private_domain1 = PrivateDomain.make(owning_organization: org)
          PrivateDomain.make(owning_organization: org)

          eager_block = proc { |ds| ds.where(id: private_domain1.id) }

          expect {
            @eager_loaded_space = Space.eager(domains: eager_block).where(id: space.id).all.first
          }.to have_queried_db_times(/domains/i, 1)

          expect(@eager_loaded_space.domains).to eql([private_domain1])
        end

        it 'allow nested eager_load' do
          space = Space.make
          org = space.organization

          domain1 = PrivateDomain.make(owning_organization: org)
          domain2 = PrivateDomain.make(owning_organization: org)

          route1 = Route.make(domain: domain1, space: space)
          route2 = Route.make(domain: domain2, space: space)

          expect {
            @eager_loaded_space = Space.eager(domains: :routes).where(id: space.id).all.first
          }.to have_queried_db_times(/domains/i, 1)

          expect {
            expect(@eager_loaded_space.domains[0].routes).to eql([route1])
            expect(@eager_loaded_space.domains[1].routes).to eql([route2])
          }.to have_queried_db_times(//, 0)
        end
      end

      describe 'security_groups' do
        let!(:associated_sg) { SecurityGroup.make }
        let!(:unassociated_sg) { SecurityGroup.make }
        let!(:default_sg) { SecurityGroup.make(running_default: true) }
        let!(:another_default_sg) { SecurityGroup.make(running_default: true) }
        let!(:space) { Space.make(security_group_guids: [associated_sg.guid, default_sg.guid]) }

        it 'returns security groups associated with the space, and the defaults' do
          expect(space.security_groups).to match_array [associated_sg, default_sg, another_default_sg]
        end

        it 'works when eager loading' do
          eager_space = Space.eager(:security_groups).all.first
          expect(eager_space.security_groups).to match_array [associated_sg, default_sg, another_default_sg]
        end
      end

      context 'bad relationships' do
        subject(:space) { Space.make }

        shared_examples 'bad app space permission' do |perm|
          context perm do
            it "should not get associated with a #{perm.singularize} that isn't a member of the org" do
              exception = Space.const_get("Invalid#{perm.camelize}Relation")
              wrong_org = Organization.make
              user = make_user_for_org(wrong_org)

              expect {
                space.send("add_#{perm.singularize}", user)
              }.to raise_error exception
            end
          end
        end

        %w(developer manager auditor).each do |perm|
          include_examples 'bad app space permission', perm
        end
      end
    end

    describe 'Serialization' do
      it { is_expected.to export_attributes :name, :organization_guid, :space_quota_definition_guid, :allow_ssh }
      it { is_expected.to import_attributes :name, :organization_guid, :developer_guids, :manager_guids,
        :auditor_guids, :security_group_guids, :space_quota_definition_guid, :allow_ssh
      }
    end

    describe '#in_suspended_org?' do
      let(:org) { Organization.make }
      subject(:space) { Space.new(organization: org) }

      context 'when in a suspended organization' do
        before { allow(org).to receive(:suspended?).and_return(true) }
        it 'is true' do
          expect(space).to be_in_suspended_org
        end
      end

      context 'when in an unsuspended organization' do
        before { allow(org).to receive(:suspended?).and_return(false) }
        it 'is false' do
          expect(space).not_to be_in_suspended_org
        end
      end
    end

    describe '#destroy' do
      subject(:space) { Space.make }

      let(:guid_pattern) { '[[:alnum:]-]+' }

      it 'creates an AppUsageEvent for each app in the STARTED state' do
        app = AppFactory.make(space: space)
        app.update(state: 'STARTED')
        expect {
          subject.destroy
        }.to change {
          AppUsageEvent.count
        }.by(1)
        event = AppUsageEvent.last
        expect(event.app_guid).to eql(app.guid)
        expect(event.state).to eql('STOPPED')
        expect(event.space_name).to eql(space.name)
      end

      context 'when there are service instances' do
        before do
          ManagedServiceInstance.make(space: space)
        end

        it 'raises a ForeignKeyConstraintViolation error' do
          expect { space.destroy }.to raise_error(Sequel::ForeignKeyConstraintViolation)
        end
      end

      it 'destroys all routes' do
        route = Route.make(space: space)
        expect {
          subject.destroy
        }.to change {
          Route.where(id: route.id).count
        }.by(-1)
      end

      it "doesn't do anything to domains" do
        PrivateDomain.make(owning_organization: space.organization)
        expect {
          subject.destroy
        }.not_to change {
          space.organization.domains
        }
      end

      it 'nullifies any default_users' do
        user = User.make
        space.add_default_user(user)
        space.save
        expect { subject.destroy }.to change { user.reload.default_space }.from(space).to(nil)
      end

      it 'does not destroy any events related to the space' do
        event = Event.make(space: space)

        expect {
          subject.destroy
        }.to_not change {
          Event.where(id: [event.id]).count
        }

        event = Event.find(id: event.id)
        expect(event).to be
        expect(event.space).to be_nil
      end
    end

    describe '#has_remaining_memory' do
      let(:space_quota) { SpaceQuotaDefinition.make(memory_limit: 500) }
      let(:space) { Space.make(space_quota_definition: space_quota, organization: space_quota.organization) }

      it 'returns true if there is enough memory remaining when no apps are running' do
        AppFactory.make(space: space, memory: 50, instances: 1)

        expect(space.has_remaining_memory(500)).to eq(true)
        expect(space.has_remaining_memory(501)).to eq(false)
      end

      it 'returns true if there is enough memory remaining when apps are consuming memory' do
        AppFactory.make(space: space, memory: 200, instances: 2, state: 'STARTED')
        AppFactory.make(space: space, memory: 50, instances: 1, state: 'STARTED')

        expect(space.has_remaining_memory(50)).to eq(true)
        expect(space.has_remaining_memory(51)).to eq(false)
      end

      it 'includes RUNNING tasks when determining available memory' do
        app = AppModel.make(space_guid: space.guid)
        AppFactory.make(space: space, memory: 200, instances: 2, state: 'STARTED')
        TaskModel.make(app: app, memory_in_mb: 50, state: 'RUNNING')

        expect(space.has_remaining_memory(50)).to eq(true)
        expect(space.has_remaining_memory(51)).to eq(false)
      end

      it 'does not include non-RUNNING tasks when determining available memory' do
        app = AppModel.make(space_guid: space.guid)
        AppFactory.make(space: space, memory: 200, instances: 2, state: 'STARTED')
        TaskModel.make(app: app, memory_in_mb: 50, state: 'SUCCEEDED')

        expect(space.has_remaining_memory(51)).to eq(true)
      end
    end

    describe '#instance_memory_limit' do
      let(:org) { Organization.make }
      let(:space_quota) { SpaceQuotaDefinition.make(instance_memory_limit: 50, organization: org) }
      let(:space) { Space.make(space_quota_definition: space_quota, organization: org) }

      it 'returns the instance memory limit from the quota' do
        expect(space.instance_memory_limit).to eq(50)
      end

      context 'when the space does not have a quota' do
        let(:space_quota) { nil }

        it 'returns unlimited' do
          expect(space.instance_memory_limit).to eq(SpaceQuotaDefinition::UNLIMITED)
        end
      end
    end

    describe '#app_task_limit' do
      let(:org) { Organization.make }
      let(:space_quota) { SpaceQuotaDefinition.make(app_task_limit: 1, organization: org) }
      let(:space) { Space.make(space_quota_definition: space_quota, organization: org) }

      it 'returns the app task limit from the quota' do
        expect(space.app_task_limit).to eq(1)
      end

      context 'when the space does not have a quota' do
        let(:space_quota) { nil }

        it 'returns unlimited' do
          expect(space.app_task_limit).to eq(SpaceQuotaDefinition::UNLIMITED)
        end
      end
    end

    describe '#meets_max_task_limit?' do
      let(:org) { Organization.make }
      let(:space_quota) { SpaceQuotaDefinition.make(app_task_limit: 1, organization: org) }
      let(:space) { Space.make(space_quota_definition: space_quota, organization: org) }
      let(:app_model) { AppModel.make(space_guid: space.guid) }

      it 'returns false when the app task limit is not exceeded' do
        expect(space.meets_max_task_limit?).to be false
      end

      context 'number of pending and running tasks equals the limit' do
        before do
          TaskModel.make(app: app_model, state: TaskModel::RUNNING_STATE)
        end

        it 'returns true' do
          expect(space.meets_max_task_limit?).to be true
        end
      end
    end

    describe '.having_developers' do
      it 'returns only spaces with developers containing the specified user' do
        space1 = Space.make
        user = make_developer_for_space(space1)

        space2 = Space.make
        spaces = Space.having_developers(user).all

        expect(spaces).to include(space1)
        expect(spaces).to_not include(space2)
      end
    end

    describe 'space_quota_definition=' do
      let(:space) { Space.make }

      context 'when the space quota defitinion exists' do
        let(:space_quota_definition) { SpaceQuotaDefinition.make }
        let(:space_quota_definition_guid) { space_quota_definition.guid }

        it 'updates the association' do
          space.space_quota_definition_guid = space_quota_definition_guid
          expect(space.space_quota_definition).to eq space_quota_definition
        end
      end

      context 'when the space quota defitinion does not exist' do
        let(:space_quota_definition_guid) { 'something-that-doesnt-exist' }

        it 'raises an error' do
          expect {
            space.space_quota_definition_guid = space_quota_definition_guid
            space.save
          }.to raise_error(CloudController::Errors::ApiError,
            /Invalid relation: Could not find VCAP::CloudController::SpaceQuotaDefinition with guid: #{space_quota_definition_guid}/)
        end
      end
    end

    describe '#has_developer?' do
      subject(:space) { Space.make }
      let(:user) { User.make }

      it 'returns true if the given user is a space developer' do
        space.organization.add_user user
        space.add_developer user
        expect(space.has_developer?(user)).to be_truthy
      end

      it 'returns false if the given user is not a space developer' do
        expect(space.has_developer?(user)).to be_falsey
      end
    end

    describe '#has_member?' do
      subject(:space) { Space.make }
      let(:user) { User.make }

      it 'returns true if the given user is a space developer' do
        space.organization.add_user user
        space.add_developer user
        expect(space.has_member?(user)).to be_truthy
      end

      it 'returns true if the given user is a space auditor' do
        space.organization.add_user user
        space.add_auditor user
        expect(space.has_member?(user)).to be_truthy
      end

      it 'returns true if the given user is a space manager' do
        space.organization.add_user user
        space.add_manager user
        expect(space.has_member?(user)).to be_truthy
      end

      it 'returns false if the given user is not a manager, auditor, or developer' do
        expect(space.has_member?(user)).to be_falsey
      end
    end
  end
end
