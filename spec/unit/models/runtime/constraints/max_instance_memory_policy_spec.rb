require "spec_helper"

describe MaxInstanceMemoryPolicy do
  let(:app) { VCAP::CloudController::AppFactory.make(memory: 100, state: "STARTED") }
  let(:quota_definition) { double(instance_memory_limit: 150) }
  let(:error_name) { :random_memory_error }

  subject(:validator) { MaxInstanceMemoryPolicy.new(app, quota_definition, error_name) }

  it "gives error when app memory exceeds instance memory limit" do
    app.memory = 200
    expect(validator).to validate_with_error(app, :memory, error_name)
  end

  it "does not give error when app memory equals instance memory limit" do
    app.memory = 150
    expect(validator).to validate_without_error(app)
  end

  context "when quota definition is null" do
    let(:quota_definition) { nil }

    it "does not give error " do
      app.memory = 150
      expect(validator).to validate_without_error(app)
    end
  end

  context "when instance memory limit is -1" do
    let(:quota_definition) { double(instance_memory_limit: -1) }

    it "does not give error when instance memory limit is -1" do
      app.memory = 200
      expect(validator).to validate_without_error(app)
    end
  end

  it "does not register error when not performing a scaling operation" do
    app.memory = 200
    app.state = 'STOPPED'
    expect(validator).to validate_without_error(app)
  end
end
