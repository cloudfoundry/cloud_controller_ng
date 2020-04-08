require 'rails_helper'
require 'jobs/v3/services/create_service_instance_job'
require 'cloud_controller/errors/api_error'

module VCAP
  module CloudController
    module V3
      RSpec.describe CreateServiceInstanceJob do
        it_behaves_like 'delayed job', described_class
      end
    end
  end
end
