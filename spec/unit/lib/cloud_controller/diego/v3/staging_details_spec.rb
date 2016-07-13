require 'spec_helper'

module VCAP::CloudController
  module Diego::V3
    RSpec.describe StagingDetails do
      subject(:details) do
        StagingDetails.new(
          package:                 package,
          lifecycle:               lifecycle,
          memory_limit_calculator: memory_limit_calculator,
          disk_limit_calculator:   disk_limit_calculator,
          environment_builder:     environment_builder
        )
      end

      let(:memory_limit_calculator) { instance_double(StagingMemoryCalculator) }
      let(:disk_limit_calculator) { instance_double(StagingDiskCalculator) }
      let(:environment_builder) { instance_double(StagingEnvironmentBuilder) }

      let(:staging_message) { DropletCreateMessage.new({ lifecycle: { type: 'buildpack' } }) }
      let(:package) { PackageModel.make }
      let(:lifecycle) { BuildpackLifecycle.new(package, staging_message) }

      it 'passes along staging details' do
        expect(details
      end
    end
  end
end
