module VCAP::CloudController
  module Presenters
    module V3
      module AppManifestPresenters
        class FeaturesPresenter
          def to_hash(app:, **_)
            features = {}
            AppFeatures.all_features.each do |feature|
              features[feature.to_sym] = app.send(AppFeatures::DATABASE_COLUMNS_MAPPING[feature])
            end

            {
              features:
            }
          end
        end
      end
    end
  end
end
