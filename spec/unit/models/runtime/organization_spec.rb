# encoding: utf-8

require 'spec_helper'

require 'isolation_segment_assign'

module VCAP::CloudController
  RSpec.describe Organization, type: :model do
    it { is_expected.to have_timestamp_columns }

    describe 'Associations' do
      it { is_expected.to have_associated :spaces }
      it { is_expected.to have_associated :private_domains, associated_instance: ->(org) { PrivateDomain.make } }
      it { is_expected.to have_associated :service_plan_visibilities }
      it { is_expected.to have_associated :quota_definition }
      it { is_expected.to have_associated :domains, class: SharedDomain }
      it { is_expected.to have_associated :users }
      it { is_expected.to have_associated :managers, class: User }
      it { is_expected.to have_associated :billing_managers, class: User }
      it { is_expected.to have_associated :auditors, class: User }
      it { is_expected.to have_associated :space_quota_definitions, associated_instance: ->(org) { SpaceQuotaDefinition.make(organization: org) } }

      it 'has associated owned_private domains' do
        domain = PrivateDomain.make
        organization = domain.owning_organization
        expect(organization.owned_private_domains).to include(domain)
      end

      it 'has associated apps' do
        process = ProcessModel.make
        organization = process.space.organization
        expect(organization.apps).to include(process.reload)
      end

      it 'does not associate non-web v2 apps' do
        app_model = AppModel.make
        org = app_model.space.organization
        app1 = ProcessModel.make(type: 'web', app: app_model)
        ProcessModel.make(type: 'other', app: app_model)
        expect(org.apps).to match_array([app1])
      end

      it 'has associated app models' do
        app_model = AppModel.make
        organization = app_model.space.organization
        expect(organization.app_models).to include(app_model.reload)
      end

      it 'has associated service_instances' do
        service_instance = ManagedServiceInstance.make
        organization = service_instance.space.organization
        expect(organization.service_instances).to include(service_instance.reload)
      end

      it 'has associated tasks' do
        task = TaskModel.make
        organization = task.space.organization

        expect(organization.tasks).to include(task.reload)
      end

      describe 'isolation_segment_guids' do
        let(:assigner) { IsolationSegmentAssign.new }

        it 'returns a list of all associated isolation segments guids' do
          organization = Organization.make
          iso_seg_1 = IsolationSegmentModel.make
          iso_seg_2 = IsolationSegmentModel.make
          iso_seg_3 = IsolationSegmentModel.make

          assigner.assign(iso_seg_1, [organization])
          assigner.assign(iso_seg_2, [organization])
          assigner.assign(iso_seg_3, [organization])

          expect(organization.isolation_segment_guids).to match_array([
            iso_seg_1.guid, iso_seg_2.guid, iso_seg_3.guid
          ])
        end
      end
    end

    describe 'destroying' do
      context 'when there are isolation segments in the allowed list' do
        let(:org) { Organization.make }
        let(:isolation_segment_model) { IsolationSegmentModel.make }
        let(:isolation_segment_model2) { IsolationSegmentModel.make }
        let(:assigner) { IsolationSegmentAssign.new }

        before do
          assigner.assign(isolation_segment_model, [org])
          assigner.assign(isolation_segment_model2, [org])
          org.update(default_isolation_segment_model: isolation_segment_model)
          org.reload

          expect(org.default_isolation_segment_model).to eq(isolation_segment_model)
          expect(org.isolation_segment_models).to match_array([isolation_segment_model, isolation_segment_model2])
        end

        it 'removes the assignment records' do
          org.destroy
          isolation_segment_model.reload
          expect(isolation_segment_model.organizations).to be_empty
        end
      end
    end

    describe 'Validations' do
      let(:org) { Organization.make }

      it { is_expected.to validate_presence :name }
      it { is_expected.to validate_uniqueness :name }
      it { is_expected.to strip_whitespace :name }

      describe 'name' do
        it 'should allow standard ascii characters' do
          org.name = "A -_- word 2!?()\'\"&+."
          expect {
            org.save
          }.to_not raise_error
        end

        it 'should allow backslash characters' do
          org.name = 'a\\word'
          expect {
            org.save
          }.to_not raise_error
        end

        it 'should allow unicode characters' do
          org.name = '防御力¡'
          expect {
            org.save
          }.to_not raise_error
        end

        it 'should not allow newline characters' do
          org.name = "one\ntwo"
          expect {
            org.save
          }.to raise_error(Sequel::ValidationFailed)
        end

        it 'should not allow escape characters' do
          org.name = "a\e word"
          expect {
            org.save
          }.to raise_error(Sequel::ValidationFailed)
        end
      end

      describe 'isolation_segments' do
        let(:isolation_segment_model) { IsolationSegmentModel.make }
        let(:isolation_segment_model2) { IsolationSegmentModel.make }
        let(:assigner) { IsolationSegmentAssign.new }

        context 'when adding isolation segments to the allowed list' do
          it 'raises an ApiError' do
            expect {
              org.add_isolation_segment_model(isolation_segment_model)
            }.to raise_error(CloudController::Errors::ApiError)
          end
        end

        context 'when removing isolation segments from the allowed list' do
          before do
            assigner.assign(isolation_segment_model, [org])
          end

          it 'removing raises an ApiError' do
            expect {
              org.remove_isolation_segment_model(isolation_segment_model)
            }.to raise_error(CloudController::Errors::ApiError)
          end
        end
      end

      describe 'space_quota_definitions' do
        it 'adds when in this org' do
          quota = SpaceQuotaDefinition.make(organization: org)

          expect { org.add_space_quota_definition(quota) }.to_not raise_error
        end

        it 'does not add when quota is in a different org' do
          quota = SpaceQuotaDefinition.make

          expect { org.add_space_quota_definition(quota) }.to raise_error(Sequel::HookFailed)
        end
      end

      describe 'private_domains' do
        it 'allowed when the organization is not the owner' do
          domain = PrivateDomain.make

          expect { org.add_private_domain(domain) }.to_not raise_error
        end

        it 'does not add when the organization is the owner' do
          domain = PrivateDomain.make(owning_organization: org)

          org.add_private_domain(domain)
          expect(domain.shared_organizations).to eq([])
        end

        it 'lists all private domains owned and shared' do
          owned_domain = PrivateDomain.make(owning_organization: org)
          domain = PrivateDomain.make
          org.add_private_domain(domain)

          expect(org.private_domains).to match_array([owned_domain, domain])
        end

        it 'removes all associated routes when deleted' do
          private_domain = PrivateDomain.make
          space = Space.make
          org = space.organization
          org.add_private_domain(private_domain)
          route = Route.make(space: space, domain: private_domain)

          expect {
            org.remove_private_domain(private_domain)
          }.to change {
            Route[route.id]
          }.from(route).to(nil)
        end
      end

      describe 'status' do
        it "should allow 'active' and 'suspended'" do
          ['active', 'suspended'].each do |status|
            org.status = status
            expect {
              org.save
            }.not_to raise_error
            expect(org.status).to eq(status)
          end
        end

        it 'should not allow arbitrary status values' do
          org.status = 'unknown'
          expect {
            org.save
          }.to raise_error(Sequel::ValidationFailed)
        end

        it 'should not allow a nil status' do
          org.status = nil
          expect {
            org.save
          }.to raise_error(Sequel::ValidationFailed)
        end
      end

      describe 'default_isolation_segment' do
        let(:isolation_segment_model) { IsolationSegmentModel.make }
        let(:assigner) { VCAP::CloudController::IsolationSegmentAssign.new }

        context 'assigning the default isolation segment' do
          context 'and the default is not in the allowed list' do
            it 'raises an InvalidRelation' do
              expect {
                org.update(default_isolation_segment_model: isolation_segment_model)
              }.to raise_error(CloudController::Errors::ApiError, /Could not find Isolation Segment with guid: #{isolation_segment_model.guid}/)

              org.reload
              expect(org.default_isolation_segment_model).to eq(nil)
            end
          end

          context 'and the default is in the allowed list' do
            before do
              assigner.assign(isolation_segment_model, [org])
            end

            it 'sets the default isolation segment' do
              org.update(default_isolation_segment_model: isolation_segment_model)
              org.reload

              expect(org.default_isolation_segment_model).to eq(isolation_segment_model)
            end

            context 'when there are spaces in the org' do
              let!(:space) { Space.make(organization: org) }
              let(:shared_segment) { IsolationSegmentModel.first(guid: IsolationSegmentModel::SHARED_ISOLATION_SEGMENT_GUID) }

              it 'sets the default Isolation Segment' do
                org.update(default_isolation_segment_model: isolation_segment_model)
                org.reload

                expect(org.default_isolation_segment_model).to eq(isolation_segment_model)
              end

              context 'and the org has an assigned default that is not the shared segment' do
                before do
                  org.update(default_isolation_segment_model: isolation_segment_model)
                  org.reload
                end

                context 'and a space has an app' do
                  before do
                    AppModel.make(space: space)
                  end

                  it 'sets the default to the shared segment but does not affect running apps' do
                    expect {
                      assigner.assign(shared_segment, [org])
                      org.update(default_isolation_segment_model: shared_segment)
                    }.to_not raise_error

                    org.reload
                    expect(org.default_isolation_segment_model).to eq(shared_segment)
                  end
                end
              end

              context 'and a space has an app' do
                it 'sets the default but does not affect running apps' do
                  AppModel.make(space: space)
                  expect {
                    org.update(default_isolation_segment_guid: isolation_segment_model.guid)
                  }.to_not raise_error

                  org.reload
                  expect(org.default_isolation_segment_model).to eq(isolation_segment_model)
                end

                it 'sets the default when assigning the shared segment as the default' do
                  AppModel.make(space: space)
                  expect {
                    assigner.assign(shared_segment, [org])
                  }.to_not raise_error

                  org.reload
                  expect(org.default_isolation_segment_model).to eq(shared_segment)
                end

                context 'and the space has an assigned isolation segment' do
                  let(:isolation_segment_model2) { IsolationSegmentModel.make }

                  before do
                    assigner.assign(isolation_segment_model2, [org])
                    space.update(isolation_segment_model: isolation_segment_model2)
                    AppModel.make(space: space)
                  end

                  it 'sets the default Isolation Segment' do
                    org.update(default_isolation_segment_model: isolation_segment_model)
                    org.reload

                    expect(org.default_isolation_segment_model).to eq(isolation_segment_model)
                  end
                end
              end
            end
          end
        end

        context 'unassigning the default isolation segment' do
          before do
            assigner.assign(isolation_segment_model, [org])
            org.update(default_isolation_segment_model: isolation_segment_model)
          end

          context 'and there are no other isolation segments in the allowed list' do
            it 'succeeds' do
              org.update(default_isolation_segment_model: nil)
              org.reload

              expect(org.default_isolation_segment_guid).to be_nil
            end

            context 'and there are spaces in the organization' do
              let!(:space) { Space.make(organization: org) }

              it 'unassigns the default isolation segment' do
                org.update(default_isolation_segment_model: nil)
                org.reload

                expect(org.default_isolation_segment_guid).to be_nil
              end

              context 'and the space has apps' do
                before do
                  AppModel.make(space: space)
                end

                it 'removes the default isolation segment but does not affect running apps' do
                  expect {
                    org.update(default_isolation_segment_model: nil)
                  }.to_not raise_error

                  org.reload
                  expect(org.default_isolation_segment_model).to be_nil
                end
              end
            end
          end
        end
      end
    end

    describe 'Serialization' do
      it { is_expected.to export_attributes :name, :billing_enabled, :quota_definition_guid, :status }
      it { is_expected.to import_attributes :name, :billing_enabled, :user_guids, :manager_guids, :billing_manager_guids,
                                    :auditor_guids, :quota_definition_guid, :status, :default_isolation_segment_guid
      }
    end

    context 'statuses' do
      describe 'when status == active' do
        subject(:org) { Organization.make(status: 'active') }
        it('is active') { expect(org).to be_active }
        it('is not suspended') { expect(org).not_to be_suspended }
      end

      describe 'when status == suspended' do
        subject(:org) { Organization.make(status: 'suspended') }
        it('is not active') { expect(org).not_to be_active }
        it('is suspended') { expect(org).to be_suspended }
      end
    end

    describe 'billing' do
      it 'should not be enabled for billing when first created' do
        expect(Organization.make.billing_enabled).to eq(false)
      end
    end

    context 'memory quota' do
      let(:quota) do
        QuotaDefinition.make(memory_limit: 500)
      end

      it 'should return the memory available when no processes are running' do
        org = Organization.make(quota_definition: quota)
        space = Space.make(organization: org)
        AppFactory.make(space: space, memory: 200, instances: 2)

        expect(org.has_remaining_memory(500)).to eq(true)
        expect(org.has_remaining_memory(501)).to eq(false)
      end

      it 'should return the memory remaining when processes are consuming memory' do
        org = Organization.make(quota_definition: quota)
        space = Space.make(organization: org)

        AppFactory.make(space: space, memory: 200, instances: 2, state: 'STARTED', type: 'worker')
        AppFactory.make(space: space, memory: 50, instances: 1, state: 'STARTED')

        expect(org.has_remaining_memory(50)).to eq(true)
        expect(org.has_remaining_memory(51)).to eq(false)
      end

      it 'includes RUNNING tasks when returning remaining memory' do
        org = Organization.make(quota_definition: quota)
        space = Space.make(organization: org)

        process = AppFactory.make(space: space, memory: 250, instances: 1, state: 'STARTED', type: 'worker')
        TaskModel.make(app: process.app, memory_in_mb: 25, state: TaskModel::RUNNING_STATE)
        TaskModel.make(app: process.app, memory_in_mb: 25, state: TaskModel::RUNNING_STATE)

        expect(org.has_remaining_memory(200)).to eq(true)
        expect(org.has_remaining_memory(201)).to eq(false)
      end

      it 'does NOT include non-RUNNING tasks when returning remaining memory' do
        org = Organization.make(quota_definition: quota)
        space = Space.make(organization: org)

        process = AppFactory.make(space: space, memory: 250, instances: 1, state: 'STARTED', type: 'worker')
        TaskModel.make(app: process.app, memory_in_mb: 25, state: TaskModel::PENDING_STATE)
        TaskModel.make(app: process.app, memory_in_mb: 25, state: TaskModel::SUCCEEDED_STATE)

        expect(org.has_remaining_memory(250)).to eq(true)
        expect(org.has_remaining_memory(251)).to eq(false)
      end
    end

    describe '#instance_memory_limit' do
      let(:quota) { QuotaDefinition.make(instance_memory_limit: 50) }
      let(:org) { Organization.make quota_definition: quota }

      it 'returns the instance memory limit from the quota' do
        expect(org.instance_memory_limit).to eq(50)
      end

      context 'when the space does not have a quota' do
        let(:quota) { nil }

        it 'returns unlimited' do
          expect(org.instance_memory_limit).to eq(QuotaDefinition::UNLIMITED)
        end
      end
    end

    describe '#app_task_limit' do
      let(:quota) { QuotaDefinition.make(app_task_limit: 2) }
      let(:org) { Organization.make quota_definition: quota }

      it 'returns the app task limit from the quota' do
        expect(org.app_task_limit).to eq(2)
      end

      context 'when the space does not have a quota' do
        let(:quota) { nil }

        it 'returns unlimited' do
          expect(org.app_task_limit).to eq(QuotaDefinition::UNLIMITED)
        end
      end
    end

    describe '#meets_max_task_limit?' do
      let(:space) { Space.make }
      let(:org) { space.organization }
      let(:quota) { QuotaDefinition.make(app_task_limit: 2) }
      let(:app_model) { AppModel.make(space_guid: space.guid) }

      before do
        org.quota_definition = quota
      end

      it 'returns false when the app task limit is not exceeded' do
        expect(org.meets_max_task_limit?).to be false
      end

      context 'number of pending and running tasks equals the limit' do
        before do
          TaskModel.make(app: app_model, state: TaskModel::RUNNING_STATE)
          TaskModel.make(app: app_model, state: TaskModel::PENDING_STATE)
        end

        it 'returns true' do
          expect(org.meets_max_task_limit?).to be true
        end
      end
    end

    describe '#destroy' do
      subject(:org) { Organization.make }

      let(:guid_pattern) { '[[:alnum:]-]+' }

      before { org.reload }

      it 'destroys all space quota definitions' do
        sqd = SpaceQuotaDefinition.make(organization: org)
        expect { org.destroy }.to change { SpaceQuotaDefinition[id: sqd.id] }.from(sqd).to(nil)
      end

      context 'when there are spaces in the org' do
        let!(:space) { Space.make(organization: org) }

        it 'raises a ForeignKeyConstraintViolation error' do
          expect { org.destroy }.to raise_error(Sequel::ForeignKeyConstraintViolation)
        end
      end

      context 'when there are service instances in the org' do
        let(:space) { Space.make(organization: org) }

        before do
          service_instance = ManagedServiceInstance.make(:v2, space: space)
          attrs = service_instance.client.attrs
          uri = URI(attrs[:url])
          uri.user = attrs[:auth_username]
          uri.password = attrs[:auth_password]

          plan = service_instance.service_plan
          service = plan.service

          uri = uri.to_s
          uri += "/v2/service_instances/#{service_instance.guid}"
          stub_request(:delete, uri + "?plan_id=#{plan.unique_id}&service_id=#{service.unique_id}").to_return(status: 200, body: '{}')
        end

        it 'raises a ForeignKeyConstraintViolation error' do
          expect { org.destroy }.to raise_error(Sequel::ForeignKeyConstraintViolation)
        end
      end

      it 'destroys all service plan visibilities' do
        service_plan_visibility = ServicePlanVisibility.make(organization: org)
        expect {
          org.destroy
        }.to change {
          ServicePlanVisibility.where(id: service_plan_visibility.id).any?
        }.to(false)
      end

      it 'destroys owned private domains' do
        domain = PrivateDomain.make(owning_organization: org)

        expect {
          org.destroy
        }.to change {
          Domain[id: domain.id]
        }.from(domain).to(nil)
      end

      it 'destroys private domains' do
        domain = PrivateDomain.make
        org.add_private_domain(domain)

        expect {
          org.destroy
        }.to change {
          Domain[id: domain.id].shared_organizations
        }.from([org]).to([])
      end
    end

    describe 'adding domains' do
      it 'does not add domains to the organization if it is a shared domain' do
        shared_domain = SharedDomain.make
        org = Organization.make
        expect { org.add_domain(shared_domain) }.not_to change { org.domains }
      end

      it 'does nothing if it is a private domain that belongs to the org' do
        org = Organization.make
        private_domain = PrivateDomain.make(owning_organization: org)
        expect { org.add_domain(private_domain) }.not_to change { org.domains.collect(&:id) }
      end

      it 'raises error if the private domain does not belongs to the organization' do
        org = Organization.make
        private_domain = PrivateDomain.make(owning_organization: Organization.make)
        expect { org.add_domain(private_domain) }.to raise_error(Domain::UnauthorizedAccessToPrivateDomain)
      end
    end

    describe '#domains (eager loading)' do
      before { SharedDomain.dataset.destroy }

      it 'is able to eager load domains' do
        org = Organization.make
        private_domain1 = PrivateDomain.make(owning_organization: org)
        private_domain2 = PrivateDomain.make(owning_organization: org)
        shared_domain = SharedDomain.make

        expect {
          @eager_loaded_org = Organization.eager(:domains).where(id: org.id).all.first
        }.to have_queried_db_times(/domains/i, 1)

        expect {
          @eager_loaded_domains = @eager_loaded_org.domains.to_a
        }.to have_queried_db_times(//, 0)

        expect(@eager_loaded_org).to eql(org)
        expect(@eager_loaded_domains).to match_array([private_domain1, private_domain2, shared_domain])
        expect(@eager_loaded_domains).to match_array(org.domains)
      end

      it 'has correct domains for each org' do
        org1 = Organization.make
        org2 = Organization.make

        private_domain1 = PrivateDomain.make(owning_organization: org1)
        private_domain2 = PrivateDomain.make(owning_organization: org2)
        shared_domain = SharedDomain.make

        expect {
          @eager_loaded_orgs = Organization.eager(:domains).where(id: [org1.id, org2.id]).order_by(:id).all
        }.to have_queried_db_times(/domains/i, 1)

        expect {
          expect(@eager_loaded_orgs[0].domains).to match_array([private_domain1, shared_domain])
          expect(@eager_loaded_orgs[1].domains).to match_array([private_domain2, shared_domain])
        }.to have_queried_db_times(//, 0)
      end

      it 'passes in dataset to be loaded to eager_block option' do
        org1 = Organization.make

        private_domain1 = PrivateDomain.make(owning_organization: org1)
        PrivateDomain.make(owning_organization: org1)

        eager_block = proc { |ds| ds.where(id: private_domain1.id) }

        expect {
          @eager_loaded_org = Organization.eager(domains: eager_block).where(id: org1.id).all.first
        }.to have_queried_db_times(/domains/i, 1)

        expect(@eager_loaded_org.domains).to eql([private_domain1])
      end

      it 'allow nested eager_load' do
        org = Organization.make
        space = Space.make(organization: org)

        domain1 = PrivateDomain.make(owning_organization: org)
        domain2 = PrivateDomain.make(owning_organization: org)

        route1 = Route.make(domain: domain1, space: space)
        route2 = Route.make(domain: domain2, space: space)

        expect {
          @eager_loaded_org = Organization.eager(domains: :routes).where(id: org.id).all.first
        }.to have_queried_db_times(/domains/i, 1)

        expect {
          expect(@eager_loaded_org.domains[0].routes).to eql([route1])
          expect(@eager_loaded_org.domains[1].routes).to eql([route2])
        }.to have_queried_db_times(//, 0)
      end
    end

    describe 'removing a user' do
      let(:org)     { Organization.make }
      let(:user)    { User.make }
      let(:space_1) { Space.make }
      let(:space_2) { Space.make }

      before do
        org.add_user(user)
        org.add_space(space_1)
      end

      context 'without the recursive flag (#remove_user)' do
        it "should raise an error if the user's developer space is associated with an organization's space" do
          space_1.add_developer(user)
          space_1.refresh
          expect(user.spaces).to include(space_1)
          expect { org.remove_user(user) }.to raise_error(CloudController::Errors::ApiError)
        end

        it "should raise an error if the user's managed space is associated with an organization's space" do
          space_1.add_manager(user)
          space_1.refresh
          expect(user.managed_spaces).to include(space_1)
          expect { org.remove_user(user) }.to raise_error(CloudController::Errors::ApiError)
        end

        it "should raise an error if the user's audited space is associated with an organization's space" do
          space_1.add_auditor(user)
          space_1.refresh
          expect(user.audited_spaces).to include(space_1)
          expect { org.remove_user(user) }.to raise_error(CloudController::Errors::ApiError)
        end

        it "should raise an error if any of the user's spaces are associated with any of the organization's spaces" do
          org.add_space(space_2)
          space_2.add_manager(user)
          space_2.refresh
          expect(user.managed_spaces).to include(space_2)
          expect { org.remove_user(user) }.to raise_error(CloudController::Errors::ApiError)
        end

        it 'should remove the user from an organization if they are not associated with any spaces' do
          expect { org.remove_user(user) }.to change { org.reload.user_guids }.from([user.guid]).to([])
        end
      end

      context 'with the recursive flag (#remove_user_recursive)' do
        before do
          org.add_space(space_2)
          [space_1, space_2].each { |space| space.add_developer(user) }
          [space_1, space_2].each { |space| space.add_manager(user) }
          [space_1, space_2].each { |space| space.add_auditor(user) }
          [space_1, space_2].each(&:refresh)
        end

        it 'should remove the space developer roles from the user' do
          expect { org.remove_user_recursive(user) }.to change { user.spaces.length }.from(2).to(0)
        end

        it 'should remove the space manager roles from the user' do
          expect { org.remove_user_recursive(user) }.to change { user.managed_spaces.length }.from(2).to(0)
        end

        it 'should remove the space audited roles from the user' do
          expect { org.remove_user_recursive(user) }.to change { user.audited_spaces.length }.from(2).to(0)
        end

        it 'should remove the user from each spaces developer role' do
          [space_1, space_2].each { |space| expect(space.developers).to include(user) }
          org.remove_user_recursive(user)
          [space_1, space_2].each(&:refresh)
          [space_1, space_2].each { |space| expect(space.developers).not_to include(user) }
        end

        it 'should remove the user from each spaces manager role' do
          [space_1, space_2].each { |space| expect(space.managers).to include(user) }
          org.remove_user_recursive(user)
          [space_1, space_2].each(&:refresh)
          [space_1, space_2].each { |space| expect(space.managers).not_to include(user) }
        end

        it 'should remove the user from each spaces auditor role' do
          [space_1, space_2].each { |space| expect(space.auditors).to include(user) }
          org.remove_user_recursive(user)
          [space_1, space_2].each(&:refresh)
          [space_1, space_2].each { |space| expect(space.auditors).not_to include(user) }
        end

        context 'when the user also has other org roles' do
          before do
            org.add_manager(user)
            org.add_billing_manager(user)
            org.refresh
          end

          it 'should remove all org roles from the user' do
            expect(org.users).to include(user)
            expect(org.managers).to include(user)
            expect(org.billing_managers).to include(user)

            org.remove_user_recursive(user)

            expect(org.users).to_not include(user)
            expect(org.managers).to_not include(user)
            expect(org.billing_managers).to_not include(user)
            expect(user.reload.organizations).to_not include(org)
          end
        end

        context 'when the user only has non-user org roles' do
          let(:user) { User.make }
          before do
            org.add_manager(user)
            org.add_auditor(user)
          end

          it 'should remove all roles' do
            expect(org.managers).to include(user)
            expect(org.auditors).to include(user)

            org.remove_user_recursive(user)

            expect(org.managers).to_not include(user)
            expect(org.auditors).to_not include(user)
            expect(user.reload.organizations).to_not include(org)
          end
        end

        context 'when the user only has an org-user role' do
          let(:user) { User.make }
          before do
            org.add_user(user)
          end

          it 'should remove that role' do
            expect(org.users).to include(user)

            org.remove_user_recursive(user)

            expect(org.users).to_not include(user)
            expect(user.reload.organizations).to_not include(org)
          end
        end
      end
    end

    describe 'creating an organization' do
      context 'when a quota is not specified' do
        let(:org) { Organization.create_from_hash(name: 'myorg') }

        it 'uses the default' do
          org.save
          expect(org.quota_definition_id).to eq(QuotaDefinition.default.id)
        end

        context 'when the default quota does not exist' do
          before do
            QuotaDefinition.default.organizations.each(&:destroy)
            QuotaDefinition.default.destroy
          end

          it 'raises an exception' do
            expect { org.save }.to raise_error(CloudController::Errors::ApiError, /Quota Definition could not be found: default/)
          end
        end
      end

      context 'when a quota is specified' do
        let(:org) { Organization.make_unsaved(quota_definition: nil, quota_definition_guid: quota_definition_guid) }

        context "and it's valid" do
          let(:my_quota)  { QuotaDefinition.make }
          let(:quota_definition_guid) { my_quota.guid }

          it 'uses what is provided' do
            org.save
            expect(org.quota_definition).to eq(my_quota)
          end
        end

        context "but it's invalid" do
          let(:quota_definition_guid) { 'something-invalid' }

          it 'uses what is provided' do
            expect {
              org.save
            }.to raise_error(CloudController::Errors::ApiError, /Could not find VCAP::CloudController::QuotaDefinition with guid: #{quota_definition_guid}/)
          end
        end
      end
    end
  end
end
