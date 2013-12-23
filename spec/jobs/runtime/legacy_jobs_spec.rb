require "spec_helper"

describe "Legacy Jobs" do
  describe ::AppBitsPackerJob do
    it { should be_a(VCAP::CloudController::Jobs::Runtime::AppBitsPacker) }
  end
end
