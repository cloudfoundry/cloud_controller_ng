require 'spec_helper'

module VCAP::CloudController
  RSpec.describe SpaceAccess, type: :access do
    subject(:access) { SpaceAccess.new(Security::AccessContext.new) }
    let(:org) { VCAP::CloudController::Organization.make }
    let(:user) { VCAP::CloudController::User.make }
    let(:scopes) { nil }

    let(:object) { VCAP::CloudController::Space.make(organization: org) }
    let(:space) { object }

    describe 'when the parent organization is suspended' do
      before(:each) do
        org.status = VCAP::CloudController::Organization::SUSPENDED
        org.save
      end

      index_table = {
        unauthenticated: true,
        reader_and_writer: true,
        reader: true,
        writer: true,

        admin: true,
        admin_read_only: true,
        global_auditor: true,

        space_developer: true,
        space_manager: true,
        space_auditor: true,
        org_user: true,
        org_manager: true,
        org_auditor: true,
        org_billing_manager: true,
      }

      read_table = {
        unauthenticated: false,
        reader_and_writer: false,
        reader: false,
        writer: false,

        admin: true,
        admin_read_only: true,
        global_auditor: true,

        space_developer: true,
        space_manager: true,
        space_auditor: true,
        org_user: false,
        org_manager: true,
        org_auditor: false,
        org_billing_manager: false,
      }

      write_table = {
        unauthenticated: false,
        reader_and_writer: false,
        reader: false,
        writer: false,

        admin: true,
        admin_read_only: false,
        global_auditor: false,

        space_developer: false,
        space_manager: false,
        space_auditor: false,
        org_user: false,
        org_manager: false,
        org_auditor: false,
        org_billing_manager: false,
      }

      it_behaves_like('an access control', :create, write_table)
      it_behaves_like('an access control', :delete, write_table)
      it_behaves_like('an access control', :index, index_table)
      it_behaves_like('an access control', :read, read_table)
      it_behaves_like('an access control', :read_for_update, write_table)
      it_behaves_like('an access control', :update, write_table)

      describe '#can_remove_related_object?' do
        let(:op_params) { { relation: relation, related_guid: related_guid } }

        describe "when the user's guid matches the related guid" do
          let(:related_guid) { user.guid }

          [:auditors, :developers, :managers].each do |r|
            describe "when the relation is '#{r}'" do
              let(:relation) { r }

              can_remove_related_object_table = {
                reader_and_writer: false,
                reader: false,
                writer: false,

                admin: true,
                admin_read_only: false,
                global_auditor: false,

                space_developer: true,
                space_manager: true,
                space_auditor: true,
                org_user: true,
                org_manager: true,
                org_auditor: true,
                org_billing_manager: true,
              }

              it_behaves_like('an access control', :can_remove_related_object, can_remove_related_object_table)
            end
          end

          describe 'when the relation is something else' do
            let(:relation) { :apps }

            can_remove_related_object_table = {
              reader_and_writer: false,
              reader: false,
              writer: false,

              admin: true,
              admin_read_only: false,
              global_auditor: false,

              space_developer: false,
              space_manager: false,
              space_auditor: false,
              org_user: false,
              org_manager: false,
              org_auditor: false,
              org_billing_manager: false,
            }

            it_behaves_like('an access control', :can_remove_related_object, can_remove_related_object_table)
          end
        end

        describe "when the user's guid does not match the related guid" do
          let(:related_guid) { 'abc' }

          [:auditors, :developers, :managers, :something_else].each do |r|
            describe "when the relation is '#{r}'" do
              let(:relation) { r }

              can_remove_related_object_table = {
                reader_and_writer: false,
                reader: false,
                writer: false,

                admin: true,
                admin_read_only: false,
                global_auditor: false,

                space_developer: false,
                space_manager: false,
                space_auditor: false,
                org_user: false,
                org_manager: false,
                org_auditor: false,
                org_billing_manager: false,
              }

              it_behaves_like('an access control', :can_remove_related_object, can_remove_related_object_table)
            end
          end
        end
      end
    end

    describe 'when the parent organization is not suspended' do
      index_table = {
        unauthenticated: true,
        reader_and_writer: true,
        reader: true,
        writer: true,

        admin: true,
        admin_read_only: true,
        global_auditor: true,

        space_developer: true,
        space_manager: true,
        space_auditor: true,
        org_user: true,
        org_manager: true,
        org_auditor: true,
        org_billing_manager: true,
      }

      read_table = {
        unauthenticated: false,
        reader_and_writer: false,
        reader: false,
        writer: false,

        admin: true,
        admin_read_only: true,
        global_auditor: true,

        space_developer: true,
        space_manager: true,
        space_auditor: true,
        org_user: false,
        org_manager: true,
        org_auditor: false,
        org_billing_manager: false,
      }

      write_table = {
        unauthenticated: false,
        reader_and_writer: false,
        reader: false,
        writer: false,

        admin: true,
        admin_read_only: false,
        global_auditor: false,

        space_developer: false,
        space_manager: false,
        space_auditor: false,
        org_user: false,
        org_manager: true,
        org_auditor: false,
        org_billing_manager: false,
      }

      update_table = {
        unauthenticated: false,
        reader_and_writer: false,
        reader: false,
        writer: false,

        admin: true,
        admin_read_only: false,
        global_auditor: false,

        space_developer: false,
        space_manager: true,
        space_auditor: false,
        org_user: false,
        org_manager: true,
        org_auditor: false,
        org_billing_manager: false,
      }

      it_behaves_like('an access control', :create, write_table)
      it_behaves_like('an access control', :delete, write_table)
      it_behaves_like('an access control', :index, index_table)
      it_behaves_like('an access control', :read, read_table)
      it_behaves_like('an access control', :read_for_update, update_table)
      it_behaves_like('an access control', :update, update_table)

      describe '#can_remove_related_object?' do
        let(:op_params) { { relation: relation, related_guid: related_guid } }

        describe "when the user's guid matches the related guid" do
          let(:related_guid) { user.guid }

          [:auditors, :developers, :managers].each do |r|
            describe "when the relation is '#{r}'" do
              let(:relation) { r }

              can_remove_related_object_table = {
                reader_and_writer: false,
                reader: false,
                writer: false,

                admin: true,
                admin_read_only: false,
                global_auditor: false,

                space_developer: true,
                space_manager: true,
                space_auditor: true,
                org_user: true,
                org_manager: true,
                org_auditor: true,
                org_billing_manager: true,
              }

              it_behaves_like('an access control', :can_remove_related_object, can_remove_related_object_table)
            end
          end

          describe 'when the relation is something else' do
            let(:relation) { :apps }

            can_remove_related_object_table = {
              reader_and_writer: false,
              reader: false,
              writer: false,

              admin: true,
              admin_read_only: false,
              global_auditor: false,

              space_developer: false,
              space_manager: true,
              space_auditor: false,
              org_user: false,
              org_manager: true,
              org_auditor: false,
              org_billing_manager: false,
            }

            it_behaves_like('an access control', :can_remove_related_object, can_remove_related_object_table)
          end
        end

        describe "when the user's guid does not match the related guid" do
          let(:related_guid) { 'abc' }

          [:auditors, :developers, :managers, :something_else].each do |r|
            describe "when the relation is '#{r}'" do
              let(:relation) { r }

              can_remove_related_object_table = {
                reader_and_writer: false,
                reader: false,
                writer: false,

                admin: true,
                admin_read_only: false,
                global_auditor: false,

                space_developer: false,
                space_manager: true,
                space_auditor: false,
                org_user: false,
                org_manager: true,
                org_auditor: false,
                org_billing_manager: false,
              }

              it_behaves_like('an access control', :can_remove_related_object, can_remove_related_object_table)
            end
          end
        end
      end
    end
  end
end
