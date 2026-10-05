require 'jobs/cc_job'
require 'actions/service_account_provision'

module VCAP::CloudController
  module Jobs
    module V3
      class ServiceAccountProvision < CCJob
        attr_reader :resource_guid

        def initialize(account_guid, operation: 'provision')
          @resource_guid = account_guid
          @operation = operation
        end

        def perform
          account = ServiceAccountModel.first(guid: resource_guid)
          raise CloudController::Errors::ApiError.new_from_details('ResourceNotFound', 'The service account could not be found') unless account

          provisioner = CloudController::DependencyLocator.instance.service_account_provisioner
          case @operation
          when 'provision'
            provisioner.provision(account)
          when 'disable', 'delete'
            provisioner.deprovision(account, delete: @operation == 'delete')
          else
            raise ArgumentError.new('unsupported service account operation')
          end
        end

        def max_attempts
          3
        end

        def resource_type
          'service_account'
        end

        def display_name
          "service_account.#{@operation}"
        end

        def job_name_in_configuration
          :service_account_provision
        end
      end
    end
  end
end
