require 'models/runtime/sidecar_model'

FactoryBot.define do
  factory(:sidecar, class: VCAP::CloudController::SidecarModel) do
    name { 'side_process' }
    command { 'bundle exec rackup' }
    app
  end
end
