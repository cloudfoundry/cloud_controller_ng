require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'migration to add file-based service binding feature columns to apps table', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20250225132929_add_apps_file_based_service_binding_feature_columns.rb' }
  end

  describe 'apps table' do
    subject(:run_migration) { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }

    describe 'up' do
      describe 'column service_binding_k8s_enabled' do
        it 'adds a column `service_binding_k8s_enabled`' do
          expect(db[:apps].columns).not_to include(:service_binding_k8s_enabled)
          run_migration
          expect(db[:apps].columns).to include(:service_binding_k8s_enabled)
        end

        it 'sets the default value of existing entries to false' do
          db[:apps].insert(guid: 'existing_app_guid')
          run_migration
          expect(db[:apps].first(guid: 'existing_app_guid')[:service_binding_k8s_enabled]).to be(false)
        end

        it 'sets the default value of new entries to false' do
          run_migration
          db[:apps].insert(guid: 'new_app_guid')
          expect(db[:apps].first(guid: 'new_app_guid')[:service_binding_k8s_enabled]).to be(false)
        end

        it 'forbids null values' do
          run_migration
          expect { db[:apps].insert(guid: 'app_guid__nil', service_binding_k8s_enabled: nil) }.to raise_error(Sequel::NotNullConstraintViolation)
        end

        context 'when it already exists' do
          before do
            db.add_column :apps, :service_binding_k8s_enabled, :boolean, default: false, null: false, if_not_exists: true
          end

          it 'does not fail' do
            expect(db[:apps].columns).to include(:service_binding_k8s_enabled)
            expect { run_migration }.not_to raise_error
            expect(db[:apps].columns).to include(:service_binding_k8s_enabled)
            expect(db[:apps].columns).to include(:file_based_vcap_services_enabled)
            expect(check_constraint_exists?(db)).to be(true) if check_constraint_supported?(db)
          end
        end
      end

      describe 'column file_based_vcap_services_enabled' do
        it 'adds a column `file_based_vcap_services_enabled`' do
          expect(db[:apps].columns).not_to include(:file_based_vcap_services_enabled)
          run_migration
          expect(db[:apps].columns).to include(:file_based_vcap_services_enabled)
        end

        it 'sets the default value of existing entries to false' do
          db[:apps].insert(guid: 'existing_app_guid')
          run_migration
          expect(db[:apps].first(guid: 'existing_app_guid')[:file_based_vcap_services_enabled]).to be(false)
        end

        it 'sets the default value of new entries to false' do
          run_migration
          db[:apps].insert(guid: 'new_app_guid')
          expect(db[:apps].first(guid: 'new_app_guid')[:file_based_vcap_services_enabled]).to be(false)
        end

        it 'forbids null values' do
          run_migration
          expect { db[:apps].insert(guid: 'app_guid__nil', file_based_vcap_services_enabled: nil) }.to raise_error(Sequel::NotNullConstraintViolation)
        end

        context 'when it already exists' do
          before do
            db.add_column :apps, :file_based_vcap_services_enabled, :boolean, default: false, null: false, if_not_exists: true
          end

          it 'does not fail' do
            expect(db[:apps].columns).to include(:file_based_vcap_services_enabled)
            expect { run_migration }.not_to raise_error
            expect(db[:apps].columns).to include(:service_binding_k8s_enabled)
            expect(db[:apps].columns).to include(:file_based_vcap_services_enabled)
            expect(check_constraint_exists?(db)).to be(true) if check_constraint_supported?(db)
          end
        end
      end

      describe 'check constraint' do
        context 'when supported' do
          before do
            skip 'check constraint not supported by db' unless check_constraint_supported?(db)
          end

          it 'adds the check constraint' do
            expect(check_constraint_exists?(db)).to be(false)
            run_migration
            expect(check_constraint_exists?(db)).to be(true)
          end

          it 'forbids setting both features to true' do
            run_migration
            expect { db[:apps].insert(guid: 'some_app', file_based_vcap_services_enabled: true, service_binding_k8s_enabled: true) }.to(raise_error do |error|
              expect(error.inspect).to include('only_one_sb_feature_enabled', 'violate')
            end)
          end

          context 'when it already exists' do
            before do
              db.add_column :apps, :service_binding_k8s_enabled, :boolean, default: false, null: false, if_not_exists: true
              db.add_column :apps, :file_based_vcap_services_enabled, :boolean, default: false, null: false, if_not_exists: true
              db.alter_table :apps do
                add_constraint(name: :only_one_sb_feature_enabled) do
                  Sequel.lit('NOT (service_binding_k8s_enabled AND file_based_vcap_services_enabled)')
                end
              end
            end

            it 'does not fail' do
              expect { run_migration }.not_to raise_error
            end
          end
        end

        context 'when not supported' do
          before do
            skip 'check constraint supported by db' if check_constraint_supported?(db)
          end

          it 'does not fail' do
            expect { run_migration }.not_to raise_error
            expect(db[:apps].columns).to include(:service_binding_k8s_enabled)
            expect(db[:apps].columns).to include(:file_based_vcap_services_enabled)
          end
        end
      end
    end

    describe 'down' do
      subject(:run_rollback) { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }

      before do
        run_migration
      end

      describe 'column service_binding_k8s_enabled' do
        it 'removes column `service_binding_k8s_enabled`' do
          expect(db[:apps].columns).to include(:service_binding_k8s_enabled)
          run_rollback
          expect(db[:apps].columns).not_to include(:service_binding_k8s_enabled)
        end

        context 'when it does not exist' do
          before do
            db.alter_table :apps do
              drop_constraint :only_one_sb_feature_enabled
              drop_column :service_binding_k8s_enabled
            end
          end

          it 'does not fail' do
            expect(db[:apps].columns).not_to include(:service_binding_k8s_enabled)
            expect { run_rollback }.not_to raise_error
            expect(db[:apps].columns).not_to include(:service_binding_k8s_enabled)
            expect(db[:apps].columns).not_to include(:file_based_vcap_services_enabled)
            expect(check_constraint_exists?(db)).to be(false)
          end
        end
      end

      describe 'column file_based_vcap_services_enabled' do
        it 'removes column `file_based_vcap_services_enabled`' do
          expect(db[:apps].columns).to include(:file_based_vcap_services_enabled)
          run_rollback
          expect(db[:apps].columns).not_to include(:file_based_vcap_services_enabled)
        end

        context 'when it does not exist' do
          before do
            db.alter_table :apps do
              drop_constraint :only_one_sb_feature_enabled
              drop_column :file_based_vcap_services_enabled
            end
          end

          it 'does not fail' do
            expect(db[:apps].columns).not_to include(:file_based_vcap_services_enabled)
            expect { run_rollback }.not_to raise_error
            expect(db[:apps].columns).not_to include(:service_binding_k8s_enabled)
            expect(db[:apps].columns).not_to include(:file_based_vcap_services_enabled)
            expect(check_constraint_exists?(db)).to be(false)
          end
        end
      end

      describe 'check constraint' do
        context 'when supported' do
          before do
            skip 'check constraint not supported by db' unless check_constraint_supported?(db)
          end

          it 'removes the check constraint' do
            expect(check_constraint_exists?(db)).to be(true)
            run_rollback
            expect(check_constraint_exists?(db)).to be(false)
          end

          context 'when it does not exist' do
            before do
              db.alter_table :apps do
                drop_constraint :only_one_sb_feature_enabled
              end
            end

            it 'does not fail' do
              expect(check_constraint_exists?(db)).to be(false)
              expect { run_rollback }.not_to raise_error
              expect(db[:apps].columns).not_to include(:service_binding_k8s_enabled)
              expect(db[:apps].columns).not_to include(:file_based_vcap_services_enabled)
              expect(check_constraint_exists?(db)).to be(false)
            end
          end
        end

        context 'when not supported' do
          before do
            skip 'check constraint supported by db' if check_constraint_supported?(db)
          end

          it 'does not fail' do
            expect { run_rollback }.not_to raise_error
            expect(db[:apps].columns).not_to include(:service_binding_k8s_enabled)
            expect(db[:apps].columns).not_to include(:file_based_vcap_services_enabled)
          end
        end
      end
    end
  end
end
