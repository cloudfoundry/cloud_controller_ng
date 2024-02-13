module VCAP::CloudController
  class IncludeBindingAppDecorator
    class << self
      def match?(include)
        include&.any? { |i| %w[app].include?(i) }
      end

      def decorate(hash, bindings)
        hash.deep_merge({
                          included: {
                            apps: apps(bindings)&.map { |app| Presenters::V3::AppPresenter.new(app).to_hash } || []
                          }
                        })
      end

      private

      def apps(bindings)
        app_guids = bindings.pluck(:app_guid).compact.uniq
        return if app_guids.empty?

        AppModel.where(guid: app_guids).order(:created_at).
          eager(Presenters::V3::AppPresenter.associated_resources).all
      end
    end
  end
end
