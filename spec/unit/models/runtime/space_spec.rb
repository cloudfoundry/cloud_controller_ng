require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::Space, type: :model do
    it { is_expected.to have_timestamp_columns }

    describe 'uniqueness' do
      it 'enforces uniqueness of name within an organization' do
        existing_space = create(:space)
        expect do
          Space.create(name: existing_space.name, organization: existing_space.organization)
        end.to raise_error(Sequel::ValidationFailed, /unique/)
      end
    end

    describe 'Validations' do
      it { is_expected.to validate_presence :name }
      it { is_expected.to validate_presence :organization }
      it { is_expected.to strip_whitespace :name }

      context 'name' do
        subject(:space) { create(:space) }

        it 'allows standard ascii character' do
          space.name = "A -_- word 2!?()'\"&+."
          expect do
            space.save
          end.not_to raise_error
        end

        describe 'database errors' do
          it 'translates database uniqueness errors into Sequel Validation Errors' do
            dup_space = Space.new(organization_guid: space.organization.guid, name: space.name)
            expect do
              dup_space.save(validate: false)
            end.to raise_error(Sequel::ValidationFailed)
          end

          it 'does not translate db errors not about name uniqueness' do
            invalid_space = Space.new
            expect do
              invalid_space.save(validate: false)
            end.to raise_error(Sequel::DatabaseError)
          end
        end

        it 'allows backslash character' do
          space.name = 'a\\word'
          expect do
            space.save
          end.not_to raise_error
        end

        it 'allows unicode characters' do
          space.name = '防御力¡'
          expect do
            space.save
          end.not_to raise_error
        end

        it 'does not allow newline character' do
          space.name = "a \n word"
          expect do
            space.save
          end.to raise_error(Sequel::ValidationFailed)
        end

        it 'does not allow escape character' do
          space.name = "a \e word"
          expect do
            space.save
          end.to raise_error(Sequel::ValidationFailed)
        end
      end

      context 'organization' do
        it 'fails when changing' do
          expect { create(:space).organization = create(:organization) }.to raise_error(CloudController::Errors::ApiError, /Cannot change organization/)
        end
      end
    end

    describe 'Associations' do
      it { is_expected.to have_associated :organization, associated_instance: ->(space) { space.organization } }
      it { is_expected.to have_associated :events }
      it { is_expected.to have_associated :service_instances, class: UserProvidedServiceInstance }
      it { is_expected.to have_associated :managed_service_instances }
      it { is_expected.to have_associated :routes, associated_instance: ->(space) { create(:route, space:) } }
      it { is_expected.to have_associated :security_groups }
      it { is_expected.to have_associated :default_users, class: User }
      it { is_expected.to have_associated :domains, class: SharedDomain }
      it { is_expected.to have_associated :space_quota_definition, associated_instance: ->(space) { create(:space_quota_definition, organization: space.organization) } }

      it {
        expect(subject).to have_associated :service_instances_shared_from_other_spaces, associated_instance: lambda { |_space|
          create(:managed_service_instance, space: create(:space))
        }
      }

      describe 'space_quota_definition' do
        subject(:space) { create(:space) }

        it 'fails when the space quota is from another organization' do
          new_quota = create(:space_quota_definition)
          space.space_quota_definition = new_quota
          expect { space.save }.to raise_error(Sequel::ValidationFailed)
        end

        it 'allows nil' do
          expect { space.space_quota_definition = nil }.not_to raise_error
        end
      end

      describe 'service_instances_shared_from_other_spaces' do
        subject(:space) { create(:space) }

        it 'is empty by default' do
          expect(space.service_instances_shared_from_other_spaces).to be_empty
        end

        it 'includes the services shared from other spaces' do
          foreign_space = create(:space)
          foreign_service = create(:managed_service_instance, space: foreign_space)

          space.add_service_instances_shared_from_other_space(foreign_service)

          expect(space.service_instances_shared_from_other_spaces).to contain_exactly(foreign_service)
        end
      end

      describe 'dataset managed_service_instances' do
        let(:space)        { create(:space) }
        let(:other_space)  { create(:space) }

        it 'includes only managed instances from the same space' do
          mine   = create(:managed_service_instance, space:)
          other  = create(:managed_service_instance, space: other_space)
          upsi   = create(:user_provided_service_instance, space:)

          expect(space.managed_service_instances).to include(mine)
          expect(space.managed_service_instances).not_to include(other)
          expect(space.managed_service_instances).not_to include(upsi)
        end
      end

      describe 'domains' do
        subject(:space) { create(:space, organization:) }
        let(:organization) { create(:organization) }

        context 'listing domains' do
          before do
            create(:private_domain, owning_organization: space.organization)
          end

          it "lists the owning organization's domains and shared domains" do
            expect(space.domains).to match_array(organization.domains)
          end
        end

        context 'adding domains' do
          it 'does not add the domain to the space if it is a shared domain' do
            shared_domain = create(:shared_domain)
            expect { space.add_domain(shared_domain) }.not_to(change(space, :domains))
          end

          it "does nothing if the private domain already belongs to the space's org" do
            org = create(:organization)
            private_domain = create(:private_domain, owning_organization: org)
            space = create(:space, organization: org)
            expect { space.add_domain(private_domain) }.not_to(change { space.domains })
          end

          it 'reports an error if the private domain belongs to another org' do
            space_org = create(:organization)
            space = create(:space, organization: space_org)

            domain_org = create(:organization)
            private_domain = create(:private_domain, owning_organization: domain_org)
            expect { space.add_domain(private_domain) }.to raise_error(Domain::UnauthorizedAccessToPrivateDomain)
          end
        end
      end

      describe '#domains (eager loading)' do
        before { SharedDomain.dataset.destroy }

        it 'is able to eager load domains' do
          space = create(:space)
          org = space.organization

          private_domain1 = create(:private_domain, owning_organization: org)
          private_domain2 = create(:private_domain, owning_organization: org)
          shared_domain = create(:shared_domain)

          expect do
            @eager_loaded_space = Space.eager(:domains).where(id: space.id).all.first
          end.to have_queried_db_times(/domains/i, 1)

          expect do
            @eager_loaded_domains = @eager_loaded_space.domains.to_a
          end.to have_queried_db_times(//, 0)

          expect(@eager_loaded_space).to eql(space)
          expect(@eager_loaded_domains).to contain_exactly(private_domain1, private_domain2, shared_domain)
          expect(@eager_loaded_domains).to eql(org.domains)
        end

        it 'has correct domains for each space' do
          space1 = create(:space)
          space2 = create(:space)

          org1 = space1.organization
          org2 = space2.organization

          private_domain1 = create(:private_domain, owning_organization: org1)
          private_domain2 = create(:private_domain, owning_organization: org2)

          shared_domain = create(:shared_domain)

          expect do
            @eager_loaded_spaces = Space.eager(:domains).where(id: [space1.id, space2.id]).limit(2).all
          end.to have_queried_db_times(/domains/i, 1)

          expected_domains = [private_domain1, shared_domain, private_domain2, shared_domain]

          expect do
            expect(@eager_loaded_spaces).to have(2).items
            actual_domains = @eager_loaded_spaces[0].domains + @eager_loaded_spaces[1].domains
            expect(actual_domains).to match_array(expected_domains)
          end.to have_queried_db_times(//, 0)
        end

        it 'passes in dataset to be loaded to eager_block option' do
          space = create(:space)
          org = space.organization

          private_domain1 = create(:private_domain, owning_organization: org)
          create(:private_domain, owning_organization: org)

          eager_block = proc { |ds| ds.where(id: private_domain1.id) }

          expect do
            @eager_loaded_space = Space.eager(domains: eager_block).where(id: space.id).all.first
          end.to have_queried_db_times(/domains/i, 1)

          expect(@eager_loaded_space.domains).to eql([private_domain1])
        end

        it 'allow nested eager_load' do
          space = create(:space)
          org = space.organization

          domain1 = create(:private_domain, owning_organization: org)
          domain2 = create(:private_domain, owning_organization: org)

          route1 = create(:route, domain: domain1, space: space)
          route2 = create(:route, domain: domain2, space: space)

          expect do
            @eager_loaded_space = Space.eager(domains: :routes).where(id: space.id).all.first
          end.to have_queried_db_times(/domains/i, 1)

          expect do
            expect(@eager_loaded_space.domains[0].routes).to eql([route1])
            expect(@eager_loaded_space.domains[1].routes).to eql([route2])
          end.to have_queried_db_times(//, 0)
        end
      end

      describe 'security_groups' do
        let!(:associated_sg) { create(:security_group) }
        let!(:unassociated_sg) { create(:security_group) }
        let!(:default_sg) { create(:security_group, running_default: true) }
        let!(:another_default_sg) { create(:security_group, running_default: true) }
        let!(:space) { create(:space, security_group_guids: [associated_sg.guid, default_sg.guid]) }

        it 'returns security groups associated with the space, and the defaults' do
          expect(space.security_groups).to contain_exactly(associated_sg, default_sg, another_default_sg)
        end

        it 'works when eager loading' do
          eager_space = Space.eager(:security_groups).all.first
          expect(eager_space.associations).to include(:security_groups)
          expect(eager_space.security_groups).to contain_exactly(associated_sg, default_sg, another_default_sg)
        end

        it 'can be deleted when associated' do
          expect { space.destroy }.not_to raise_error
        end

        context 'when there are multiple spaces' do
          let!(:another_space) { create(:space, security_group_guids: [associated_sg.guid, default_sg.guid]) }
          let!(:yet_another_space) { create(:space, security_group_guids: [associated_sg.guid, another_default_sg.guid]) }

          it 'returns booleans for the running_default property' do
            expect(space.security_groups.first.running_default).to be_in [true, false]
          end

          it 'only returns the groups for the given space and the global defaults' do
            expect(space.security_groups).to eq [associated_sg, default_sg, another_default_sg]
          end
        end
      end

      describe 'staging_security_groups' do
        let!(:associated_sg) { create(:security_group) }
        let!(:unassociated_sg) { create(:security_group) }
        let!(:default_sg) { create(:security_group, staging_default: true) }
        let!(:another_default_sg) { create(:security_group, staging_default: true) }
        let!(:space) { create(:space, staging_security_group_guids: [associated_sg.guid, default_sg.guid]) }

        it 'returns security groups associated with the space, and the defaults' do
          expect(space.staging_security_groups).to contain_exactly(associated_sg, default_sg, another_default_sg)
        end

        it 'works when eager loading' do
          eager_space = Space.eager(:staging_security_groups).all.first
          expect(eager_space.associations).to include(:staging_security_groups)
          expect(eager_space.staging_security_groups).to contain_exactly(associated_sg, default_sg, another_default_sg)
        end

        it 'can be deleted when associated' do
          expect { space.destroy }.not_to raise_error
        end

        context 'when there are multiple spaces' do
          let!(:another_space) { create(:space, staging_security_group_guids: [associated_sg.guid, default_sg.guid]) }
          let!(:yet_another_space) { create(:space, staging_security_group_guids: [associated_sg.guid, another_default_sg.guid]) }

          it 'returns booleans for the staging_default property' do
            expect(space.staging_security_groups.first.staging_default).to be_in [true, false]
          end

          it 'only returns the groups for the given space and the global defaults' do
            expect(space.staging_security_groups).to eq [associated_sg, default_sg, another_default_sg]
          end
        end
      end

      describe 'isolation_segment_models' do
        let(:assigner) { VCAP::CloudController::IsolationSegmentAssign.new }
        let(:space) { create(:space) }
        let(:isolation_segment_model) { create(:isolation_segment_model) }

        context 'adding an isolation segment' do
          context "and the Space's org does not have the isolation segment" do
            it 'raises UnableToPerform' do
              expect do
                space.update(isolation_segment_model:)
              end.to raise_error(CloudController::Errors::ApiError, /Only Isolation Segments in the Organization's allowed list can be used./)
              space.reload

              expect(space.isolation_segment_model).to be_nil
            end
          end

          context "and the Space's org has the Isolation Segment" do
            before do
              assigner.assign(isolation_segment_model, [space.organization])
            end

            it 'adds the isolation segment' do
              space.update(isolation_segment_guid: isolation_segment_model.guid)
              space.reload

              expect(space.isolation_segment_model).to eq(isolation_segment_model)
            end

            context 'and the space has apps' do
              before do
                create(:app_model, space:)
              end

              it 'adds the isolation segment but does not affect the running app' do
                expect do
                  space.update(isolation_segment_guid: isolation_segment_model.guid)
                end.not_to raise_error
                space.reload

                expect(space.isolation_segment_model).to eq(isolation_segment_model)
              end
            end
          end
        end

        context 'removing an isolation segment' do
          before do
            assigner.assign(isolation_segment_model, [space.organization])
            space.update(isolation_segment_model:)
          end

          it 'removes the isolation segment' do
            space.update(isolation_segment_model: nil)
            space.reload

            expect(space.isolation_segment_model).to be_nil
          end
        end
      end

      context 'bad relationships' do
        subject(:space) { create(:space) }

        shared_examples 'bad app space permission' do |perm|
          context perm do
            it "does not get associated with a #{perm.singularize} that isn't a member of the org" do
              exception = Space.const_get("Invalid#{perm.camelize}Relation")
              wrong_org = create(:organization)
              user = make_user_for_org(wrong_org)

              expect do
                space.send("add_#{perm.singularize}", user)
              end.to raise_error exception
            end
          end
        end

        %w[developer manager auditor supporter].each do |perm|
          include_examples 'bad app space permission', perm
        end
      end

      describe 'apps which is the process relationship' do
        it 'has apps' do
          space = create(:space)
          process1 = ProcessModelFactory.make(space:)
          process2 = ProcessModelFactory.make(space:)
          expect(space.apps).to contain_exactly(process1, process2)
        end

        it 'does not associate non-web v2 apps' do
          space = create(:space)
          process1 = ProcessModelFactory.make(type: 'web', space: space)
          ProcessModelFactory.make(type: 'other', space: space)
          expect(space.apps).to contain_exactly(process1)
        end

        context 'when there are multiple web processes for an app' do
          let(:space) { create(:space) }
          let(:app_one) { create(:app_model, space:) }
          let(:app_two) { create(:app_model, space:) }
          let!(:web_process_app_one) do
            create(:process_model, app: app_one,
                                   command: 'old command!',
                                   instances: 3,
                                   type: VCAP::CloudController::ProcessTypes::WEB,
                                   created_at: Time.now - 24.hours)
          end
          let!(:newer_web_process_app_one) do
            create(:process_model, app: app_one,
                                   command: 'new command!',
                                   instances: 4,
                                   type: VCAP::CloudController::ProcessTypes::WEB,
                                   created_at: Time.now - 23.hours)
          end
          let!(:web_process_app_two) do
            create(:process_model, app: app_two,
                                   command: 'old command!',
                                   instances: 3,
                                   type: VCAP::CloudController::ProcessTypes::WEB,
                                   created_at: Time.now - 24.hours)
          end
          let!(:newer_web_process_app_two) do
            create(:process_model, app: app_two,
                                   command: 'new command!',
                                   instances: 4,
                                   type: VCAP::CloudController::ProcessTypes::WEB,
                                   created_at: Time.now - 23.hours)
          end

          it 'returns the newest web processes for each app' do
            expect(space.apps).to contain_exactly(newer_web_process_app_one, newer_web_process_app_two)
          end
        end

        describe 'eager loading' do
          it 'loads only web processes' do
            # rubocop:disable Lint/UselessAssignment
            space1 = create(:space)
            space2 = create(:space)
            space3 = create(:space)
            space4 = create(:space)

            process1_space1 = ProcessModelFactory.make(space: space1)
            process2_space1 = ProcessModelFactory.make(space: space1)
            process3_space1 = ProcessModelFactory.make(space: space1)
            non_web_process_space1 = ProcessModelFactory.make(space: space1, type: 'other')

            process1_space2 = ProcessModelFactory.make(space: space2)
            process2_space2 = ProcessModelFactory.make(space: space2)
            process3_space2 = ProcessModelFactory.make(space: space2)
            non_web_process_space2 = ProcessModelFactory.make(space: space2, type: 'other')

            process1_space3 = ProcessModelFactory.make(space: space3)
            process2_space3 = ProcessModelFactory.make(space: space3)
            process3_space3 = ProcessModelFactory.make(space: space3)
            non_web_process_space3 = ProcessModelFactory.make(space: space3, type: 'other')

            process1_space4 = ProcessModelFactory.make(space: space4)
            process2_space4 = ProcessModelFactory.make(space: space4)
            process3_space4 = ProcessModelFactory.make(space: space4)
            non_web_app_space4 = ProcessModelFactory.make(space: space4, type: 'other')

            spaces = Space.where(id: [space1.id, space3.id]).eager(:apps).all

            expect(spaces).to contain_exactly(space1, space3)
            queried_space_1 = spaces.select { |s| s.guid == space1.guid }.first
            queried_space_3 = spaces.select { |s| s.guid == space3.guid }.first
            expect(queried_space_1.associations[:apps]).to contain_exactly(process1_space1, process2_space1, process3_space1)
            expect(queried_space_3.associations[:apps]).to contain_exactly(process1_space3, process2_space3, process3_space3)
            # rubocop:enable Lint/UselessAssignment
          end

          it 'respects when an eager block is passed in' do
            # rubocop:disable Lint/UselessAssignment
            space1 = create(:space)
            space2 = create(:space)
            space3 = create(:space)
            space4 = create(:space)

            process1_space1 = ProcessModelFactory.make(space: space1)
            process2_space1 = ProcessModelFactory.make(space: space1)
            process3_space1 = ProcessModelFactory.make(space: space1)
            non_web_process_space1 = ProcessModelFactory.make(space: space1, type: 'other')
            scaled_process_space1 = ProcessModelFactory.make(space: space1, instances: 5)

            process1_space2 = ProcessModelFactory.make(space: space2)
            process2_space2 = ProcessModelFactory.make(space: space2)
            process3_space2 = ProcessModelFactory.make(space: space2)
            non_web_process_space2 = ProcessModelFactory.make(space: space2, type: 'other')
            scaled_process_space2 = ProcessModelFactory.make(space: space2, instances: 5)

            process1_space3 = ProcessModelFactory.make(space: space3)
            process2_space3 = ProcessModelFactory.make(space: space3)
            process3_space3 = ProcessModelFactory.make(space: space3)
            non_web_process_space3 = ProcessModelFactory.make(space: space3, type: 'other')
            scaled_process_space3 = ProcessModelFactory.make(space: space3, instances: 5)

            process1_space4 = ProcessModelFactory.make(space: space4)
            process2_space4 = ProcessModelFactory.make(space: space4)
            process3_space4 = ProcessModelFactory.make(space: space4)
            non_web_process_space4 = ProcessModelFactory.make(space: space4, type: 'other')
            scaled_process_space4 = ProcessModelFactory.make(space: space4, instances: 5)

            spaces = Space.where(id: [space1.id, space3.id]).eager(apps: proc { |ds| ds.where(instances: 5) }).all

            expect(spaces).to contain_exactly(space1, space3)
            queried_space_1 = spaces.select { |s| s.guid == space1.guid }.first
            queried_space_3 = spaces.select { |s| s.guid == space3.guid }.first
            expect(queried_space_1.associations[:apps]).to contain_exactly(scaled_process_space1)
            expect(queried_space_3.associations[:apps]).to contain_exactly(scaled_process_space3)
            # rubocop:enable Lint/UselessAssignment
          end
        end
      end
    end

    describe 'Serialization' do
      it { is_expected.to export_attributes :name, :organization_guid, :space_quota_definition_guid, :allow_ssh }

      it {
        expect(subject).to import_attributes :name, :organization_guid, :developer_guids, :manager_guids, :isolation_segment_guid,
                                             :auditor_guids, :supporter_guids, :security_group_guids, :space_quota_definition_guid, :allow_ssh
      }
    end

    describe '#in_suspended_or_deleting_org?' do
      let(:org) { create(:organization) }

      subject(:space) { Space.new(organization: org) }

      context 'when in a suspended organization' do
        before { allow(org).to receive(:suspended_or_deleting?).and_return(true) }

        it 'is true' do
          expect(space).to be_in_suspended_or_deleting_org
        end
      end

      context 'when in an unsuspended organization' do
        before { allow(org).to receive(:suspended_or_deleting?).and_return(false) }

        it 'is false' do
          expect(space).not_to be_in_suspended_or_deleting_org
        end
      end
    end

    describe 'status' do
      let(:space) { create(:space) }

      it "allows 'active', 'suspended', and 'deleting'" do
        %w[active suspended deleting].each do |status|
          space.status = status
          expect { space.save }.not_to raise_error
          expect(space.status).to eq(status)
        end
      end

      it 'does not allow arbitrary status values' do
        space.status = 'unknown'
        expect { space.save }.to raise_error(Sequel::ValidationFailed)
      end

      it 'defaults to active' do
        expect(create(:space).status).to eq('active')
      end

      describe 'when status == active' do
        subject(:space) { create(:space, status: 'active') }
        it('is active') { expect(space).to be_active }
        it('is not suspended') { expect(space).not_to be_suspended }
        it('is not deleting') { expect(space).not_to be_deleting }
      end

      describe 'when status == suspended' do
        subject(:space) { create(:space, status: 'suspended') }
        it('is not active') { expect(space).not_to be_active }
        it('is suspended') { expect(space).to be_suspended }
        it('is not deleting') { expect(space).not_to be_deleting }
      end

      describe 'when status == deleting' do
        subject(:space) { create(:space, status: 'deleting') }
        it('is not active') { expect(space).not_to be_active }
        it('is not suspended') { expect(space).not_to be_suspended }
        it('is deleting') { expect(space).to be_deleting }
      end
    end

    describe '#destroy' do
      subject(:space) { create(:space) }

      let(:guid_pattern) { '[[:alnum:]-]+' }

      before do
        TestConfig.override(kubernetes: {})
      end

      context 'when there are service instances' do
        before do
          create(:managed_service_instance, space:)
        end

        it 'raises a ForeignKeyConstraintViolation error' do
          expect { space.destroy }.to raise_error(Sequel::ForeignKeyConstraintViolation)
        end
      end

      it 'destroys all routes' do
        route = create(:route, space:)
        expect do
          subject.destroy
        end.to change {
          Route.where(id: route.id).count
        }.by(-1)
      end

      it "doesn't do anything to domains" do
        create(:private_domain, owning_organization: space.organization)
        expect do
          subject.destroy
        end.not_to(change do
          space.organization.domains
        end)
      end

      it 'nullifies any default_users' do
        user = create(:user)
        space.add_default_user(user)
        space.save
        expect { subject.destroy }.to change { user.reload.default_space }.from(space).to(nil)
      end

      it 'does not destroy any events related to the space' do
        event = create(:event, space:)

        expect do
          subject.destroy
        end.not_to(change do
          Event.where(id: [event.id]).count
        end)

        event = Event.find(id: event.id)
        expect(event).to be
        expect(event.space).to be_nil
      end
    end

    describe '#has_remaining_memory' do
      let(:space_quota) { create(:space_quota_definition, memory_limit: 500) }
      let(:space) { create(:space, space_quota_definition: space_quota, organization: space_quota.organization) }

      it 'returns true if there is enough memory remaining when no processes are running' do
        ProcessModelFactory.make(space: space, memory: 50, instances: 1)

        expect(space.has_remaining_memory(500)).to be(true)
        expect(space.has_remaining_memory(501)).to be(false)
      end

      it 'returns true if there is enough memory remaining when processes are consuming memory' do
        ProcessModelFactory.make(space: space, memory: 200, instances: 2, state: ProcessModel::STARTED, type: 'other')
        ProcessModelFactory.make(space: space, memory: 50, instances: 1, state: ProcessModel::STARTED)

        expect(space.has_remaining_memory(50)).to be(true)
        expect(space.has_remaining_memory(51)).to be(false)
      end

      it 'includes RUNNING tasks when determining available memory' do
        process = ProcessModelFactory.make(space: space, memory: 200, instances: 2, state: ProcessModel::STARTED)
        create(:task_model, app: process.app, memory_in_mb: 50, state: TaskModel::RUNNING_STATE)

        expect(space.has_remaining_memory(50)).to be(true)
        expect(space.has_remaining_memory(51)).to be(false)
      end

      it 'includes PENDING tasks when determining available memory' do
        process = ProcessModelFactory.make(space: space, memory: 200, instances: 2, state: ProcessModel::STARTED)
        create(:task_model, app: process.app, memory_in_mb: 50, state: TaskModel::PENDING_STATE)

        expect(space.has_remaining_memory(50)).to be(true)
        expect(space.has_remaining_memory(51)).to be(false)
      end

      it 'does not include non-RUNNING tasks when determining available memory' do
        process = ProcessModelFactory.make(space: space, memory: 200, instances: 2, state: ProcessModel::STARTED)
        create(:task_model, app: process.app, memory_in_mb: 50, state: TaskModel::SUCCEEDED_STATE)
        create(:task_model, app: process.app, memory_in_mb: 51, state: TaskModel::FAILED_STATE)
        create(:task_model, app: process.app, memory_in_mb: 52, state: TaskModel::CANCELING_STATE)

        expect(space.has_remaining_memory(100)).to be(true)
        expect(space.has_remaining_memory(101)).to be(false)
      end

      context 'when the instance_memory is unlimited' do
        let(:space_quota) { create(:space_quota_definition, memory_limit: SpaceQuotaDefinition::UNLIMITED) }
        let(:space) { create(:space, space_quota_definition: space_quota, organization: space_quota.organization) }

        it 'there is always more remaining memory' do
          expect(space.has_remaining_memory(1_234_567_890)).to be(true)
        end
      end
    end

    describe '#has_remaining_log_rate_limit' do
      let(:log_rate_limit) { 10 }
      let(:quota) { create(:space_quota_definition, log_rate_limit: log_rate_limit, organization: org) }
      let(:org) { create(:organization) }
      let(:space) { create(:space, organization: org, space_quota_definition: quota) }
      let(:space2) { create(:space, organization: org, space_quota_definition: quota) }
      let!(:app_model) { create(:app_model, space:) }

      context 'when the quota is unlimited' do
        let(:log_rate_limit) { QuotaDefinition::UNLIMITED }

        it 'handles large log quotas' do
          expect(space.has_remaining_log_rate_limit(10_000_000)).to be_truthy
        end
      end

      context 'when nothing is running' do
        it 'uses the log_rate_limit' do
          expect(space.has_remaining_log_rate_limit(10)).to be_truthy
          expect(space.has_remaining_log_rate_limit(11)).to be_falsey
        end
      end

      context 'when something else is running' do
        it 'takes all things in the space into account' do
          ProcessModelFactory.make(space: space, log_rate_limit: 5, state: ProcessModel::STARTED)
          expect(space.has_remaining_log_rate_limit(5)).to be_truthy
          expect(space.has_remaining_log_rate_limit(6)).to be_falsey

          ProcessModelFactory.make(space: space, log_rate_limit: 1, state: ProcessModel::STARTED)
          expect(space.has_remaining_log_rate_limit(4)).to be_truthy
          expect(space.has_remaining_log_rate_limit(5)).to be_falsey

          create(:task_model, app: app_model, log_rate_limit: 1, state: TaskModel::RUNNING_STATE)
          expect(space.has_remaining_log_rate_limit(3)).to be_truthy
          expect(space.has_remaining_log_rate_limit(4)).to be_falsey
        end

        it 'considers tasks in state PENDING' do
          create(:task_model, app: app_model, log_rate_limit: 2, state: TaskModel::PENDING_STATE)
          expect(space.has_remaining_log_rate_limit(8)).to be_truthy
          expect(space.has_remaining_log_rate_limit(9)).to be_falsey
        end

        it 'does not consider tasks in other states' do
          create(:task_model, app: app_model, log_rate_limit: 2, state: TaskModel::SUCCEEDED_STATE)
          create(:task_model, app: app_model, log_rate_limit: 2, state: TaskModel::FAILED_STATE)
          create(:task_model, app: app_model, log_rate_limit: 2, state: TaskModel::CANCELING_STATE)
          expect(space.has_remaining_log_rate_limit(10)).to be_truthy
        end

        context 'when processes are running in another space' do
          it 'only accounts for processes running in the owning space' do
            ProcessModelFactory.make(space: space2, log_rate_limit: 1, instances: 2, state: ProcessModel::STARTED)

            expect(space.has_remaining_log_rate_limit(10)).to be_truthy
            expect(space.has_remaining_log_rate_limit(11)).to be_falsey
            expect(space2.has_remaining_log_rate_limit(8)).to be_truthy
            expect(space2.has_remaining_log_rate_limit(9)).to be_falsey
          end
        end
      end
    end

    describe '#instance_memory_limit' do
      let(:org) { create(:organization) }
      let(:space_quota) { create(:space_quota_definition, instance_memory_limit: 50, organization: org) }
      let(:space) { create(:space, space_quota_definition: space_quota, organization: org) }

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
      let(:org) { create(:organization) }
      let(:space_quota) { create(:space_quota_definition, app_task_limit: 1, organization: org) }
      let(:space) { create(:space, space_quota_definition: space_quota, organization: org) }

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
      let(:org) { create(:organization) }
      let(:space_quota) { create(:space_quota_definition, app_task_limit: 1, organization: org) }
      let(:space) { create(:space, organization: org) }
      let(:app_model) { create(:app_model, space_guid: space.guid) }

      before do
        space.space_quota_definition = space_quota
      end

      it 'returns false when the app task limit is not exceeded' do
        expect(space.meets_max_task_limit?).to be false
      end

      context 'number of pending and running tasks equals the limit' do
        before do
          create(:task_model, app: app_model, state: TaskModel::RUNNING_STATE)
        end

        it 'returns true' do
          expect(space.meets_max_task_limit?).to be true
        end
      end

      context 'number of pending and running tasks exceeds the limit' do
        before do
          create(:task_model, app: app_model, state: TaskModel::RUNNING_STATE)
          create(:task_model, app: app_model, state: TaskModel::PENDING_STATE)
          create(:task_model, app: app_model, state: TaskModel::PENDING_STATE)
        end

        it 'returns true' do
          expect(space.meets_max_task_limit?).to be true
        end
      end
    end

    describe '.having_developers' do
      it 'returns only spaces with developers containing the specified user' do
        space1 = create(:space)
        user = make_developer_for_space(space1)

        space2 = create(:space)
        spaces = Space.having_developers(user).all

        expect(spaces).to include(space1)
        expect(spaces).not_to include(space2)
      end
    end

    describe 'space_quota_definition=' do
      let(:space) { create(:space) }

      context 'when the space quota defitinion exists' do
        let(:space_quota_definition) { create(:space_quota_definition) }
        let(:space_quota_definition_guid) { space_quota_definition.guid }

        it 'updates the association' do
          space.space_quota_definition_guid = space_quota_definition_guid
          expect(space.space_quota_definition).to eq space_quota_definition
        end
      end

      context 'when the space quota defitinion does not exist' do
        let(:space_quota_definition_guid) { 'something-that-doesnt-exist' }

        it 'raises an error' do
          expect do
            space.space_quota_definition_guid = space_quota_definition_guid
            space.save
          end.to raise_error(CloudController::Errors::ApiError,
                             /Could not find SpaceQuotaDefinition with guid: #{space_quota_definition_guid}/)
        end
      end
    end

    describe '#has_developer?' do
      subject(:space) { create(:space) }
      let(:user) { create(:user) }
      let(:other_developer) { create(:user) }

      before do
        space.organization.add_user(user)
        space.organization.add_user(other_developer)
        space.add_developer(other_developer)
      end

      it 'returns true if the given user is a space developer' do
        space.add_developer(user)
        expect(space.has_developer?(user)).to be true
      end

      it 'returns false if the given user is not a space developer' do
        expect(space.has_developer?(user)).to be false
      end

      it 'returns false if the given user is nil' do
        expect(space.has_developer?(nil)).to be false
      end
    end

    describe '#has_member?' do
      subject(:space) { create(:space) }
      let(:user) { create(:user) }
      let(:other_user) { create(:user) }

      before do
        space.organization.add_user(user)
        space.organization.add_user(other_user)
        space.add_developer(other_user)
      end

      it 'returns true if the given user is a space developer' do
        space.add_developer(user)
        expect(space.has_member?(user)).to be true
      end

      it 'returns true if the given user is a space auditor' do
        space.add_auditor(user)
        expect(space.has_member?(user)).to be true
      end

      it 'returns true if the given user is a space manager' do
        space.add_manager(user)
        expect(space.has_member?(user)).to be true
      end

      it 'returns false if the given user is a space supporter' do
        space.add_supporter(user)
        expect(space.has_member?(user)).to be false
      end

      it 'returns false if the given user is not a manager, auditor, or developer' do
        expect(space.has_member?(user)).to be false
      end

      it 'returns false if the given user is nil' do
        expect(space.has_member?(nil)).to be false
      end
    end

    describe '#has_supporter?' do
      subject(:space) { create(:space) }
      let(:user) { create(:user) }
      let(:other_user) { create(:user) }

      before do
        space.organization.add_user(user)
        space.organization.add_user(other_user)
        space.add_developer(other_user)
      end

      it 'returns true if the given user is a space supporter' do
        space.add_supporter(user)
        expect(space.has_supporter?(user)).to be true
      end

      it 'returns false if the given user is a space developer' do
        space.add_developer(user)
        expect(space.has_supporter?(user)).to be false
      end

      it 'returns false if the given user is a space auditor' do
        space.add_auditor(user)
        expect(space.has_supporter?(user)).to be false
      end

      it 'returns false if the given user is a space manager' do
        space.add_manager(user)
        expect(space.has_supporter?(user)).to be false
      end

      it 'returns false if the given user is nil' do
        expect(space.has_supporter?(nil)).to be false
      end
    end

    describe '#in_organization?' do
      subject(:space) { create(:space) }
      let(:user) { create(:user) }

      it "returns true if the given user is in the space's organization" do
        space.organization.add_user(user)
        expect(space.in_organization?(user)).to be true
      end

      it "returns false if the given user is not in the space's organization" do
        expect(space.in_organization?(user)).to be false
      end
    end
  end
end
