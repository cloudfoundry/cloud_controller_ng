require 'models/runtime/buildpack_lifecycle_data_model'
require_relative './sequences'

FactoryBot.define do
  factory(
    :buildpack_lifecycle_data,
    aliases: [:buildpack_lifecycle_data_model],
    class: VCAP::CloudController::BuildpackLifecycleDataModel
  ) do
    to_create(&:save)

    buildpacks { nil }
    stack { create(:stack).name }
  end
end
