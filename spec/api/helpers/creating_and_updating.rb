module VCAP::CloudController::ApiSpecHelper
  shared_examples "creating and updating" do |opts|
    include_examples "updating", opts
    include_examples "creating", opts
  end
end

