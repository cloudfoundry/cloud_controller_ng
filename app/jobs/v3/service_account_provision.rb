require 'jobs/cc_job'
require 'actions/service_account_provision'

module VCAP::CloudController
  module Jobs
    module V3
      class ServiceAccountProvision < CCJob
        attr_reader :resource_guid

        def initialize(account_guid)
          @resource_guid = account_guid
        end

        def perform
          account = ServiceAccountModel.first(guid: resource_guid)
          raise CloudController::Errors::ApiError.new_from_details('ResourceNotFound', 'The service account could not be found') unless account

          CloudController::DependencyLocator.instance.service_account_provisioner.provision(account)
        end

        def max_attempts
          3
        end

        def resource_type
          'service_account'
        end

        def display_name
          'service_account.provision'
        end

        def job_name_in_configuration
          :service_account_provision
        end
      end
    end
  end
end
