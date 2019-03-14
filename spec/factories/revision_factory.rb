require 'models/runtime/revision_model'

FactoryBot.define do
  factory(:revision, class: VCAP::CloudController::RevisionModel) do
    app
    description
  end
end
