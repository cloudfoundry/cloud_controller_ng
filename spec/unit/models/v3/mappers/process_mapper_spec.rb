require 'spec_helper'
require 'models/v3/mappers/process_mapper'

module VCAP::CloudController
  describe ProcessMapper do
    describe '.map_model_to_domain' do
      let(:model) { AppFactory.make }
      
      it 'maps App to AppProcess' do
        process = ProcessMapper.map_model_to_domain(model)

        expect(process.guid).to eq(model.guid)
        expect(process.name).to eq(model.name)
        expect(process.memory).to eq(model.memory)
        expect(process.instances).to eq(model.instances)
        expect(process.disk_quota).to eq(model.disk_quota)
        expect(process.space_guid).to eq(model.space.guid)
        expect(process.stack_guid).to eq(model.stack.guid)
        expect(process.state).to eq(model.state)
        expect(process.command).to eq(model.command)
        expect(process.buildpack).to be_nil
        expect(process.health_check_timeout).to eq(model.health_check_timeout)
        expect(process.docker_image).to eq(model.docker_image)
        expect(process.environment_json).to eq(model.environment_json)
        
      end
    end
  end
end
