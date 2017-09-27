require 'perm'

module VCAP::CloudController
  module Perm
    class Client
      def initialize(url:, enabled:)
        @client = CloudFoundry::Perm::V1::Client.new(url: url)
        @enabled = enabled
      end

      def create_org_role(role:, org_id:)
        create_role(org_role(role, org_id))
      end

      def delete_org_role(role:, org_id:)
        delete_role(org_role(role, org_id))
      end

      def assign_org_role(role:, org_id:, user_id:, issuer:)
        assign_role(role: org_role(role, org_id), user_id: user_id, issuer: issuer)
      end

      def unassign_org_role(role:, org_id:, user_id:, issuer:)
        unassign_role(role: org_role(role, org_id), user_id: user_id, issuer: issuer)
      end

      def create_space_role(role:, space_id:)
        create_role(space_role(role, space_id))
      end

      def delete_space_role(role:, space_id:)
        delete_role(space_role(role, space_id))
      end

      def assign_space_role(role:, space_id:, user_id:, issuer:)
        assign_role(role: space_role(role, space_id), user_id: user_id, issuer: issuer)
      end

      def unassign_space_role(role:, space_id:, user_id:, issuer:)
        unassign_role(role: space_role(role, space_id), user_id: user_id, issuer: issuer)
      end

      private

      attr_reader :client, :enabled

      def org_role(role, org_id)
        "org-#{role}-#{org_id}"
      end

      def space_role(role, space_id)
        "space-#{role}-#{space_id}"
      end

      def create_role(role)
        if enabled
          begin
            client.create_role(role)
          rescue GRPC::AlreadyExists
            # ignored
          end
        end
      end

      def delete_role(role)
        if enabled
          begin
            client.delete_role(role)
          rescue GRPC::NotFound
            # ignored
          end
        end
      end

      def assign_role(role:, user_id:, issuer:)
        if enabled
          begin
            client.assign_role(role_name: role, actor_id: user_id, issuer: issuer)
          rescue GRPC::AlreadyExists, GRPC::NotFound
            # ignored
          end
        end
      end

      def unassign_role(role:, user_id:, issuer:)
        if enabled
          begin
            client.unassign_role(role_name: role, actor_id: user_id, issuer: issuer)
          rescue GRPC::NotFound
            # ignored
          end
        end
      end
    end
  end
end
