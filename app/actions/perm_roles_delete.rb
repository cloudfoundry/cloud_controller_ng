module VCAP::CloudController
  class PermRolesDelete
    def initialize(client, enabled, delete_action, role_prefixes)
      @client = client
      @enabled = enabled
      @delete_action = delete_action
      @role_prefixes = role_prefixes
    end

    def delete(dataset)
      if enabled
        dataset.each do |org|
          role_prefixes.each do |prefix|
            role_name = "#{prefix}-#{org.guid}"

            client.delete_role(role_name)
          end
        end
      end

      delete_action.delete(dataset)
    end

    def timeout_error(dataset)
      delete_action.timeout_error(dataset)
    end

    private

    attr_reader :client, :enabled, :delete_action, :role_prefixes
  end
end
