FactoryBot.define do
  factory :route_mapping_model, class: 'VCAP::CloudController::RouteMappingModel' do
    association :app, factory: :app_model
    route        { create(:route, space: app.space) } # rubocop:disable FactoryBot/FactoryAssociationWithStrategy
    process_type { 'web' }
    app_port     { -1 }
    weight       { nil }

    after(:create) do |route_mapping|
      route_mapping.route.associations.delete(:apps)
    end
  end
end
