module VCAP::CloudController
  class AppFindOrCreateSkeleton
    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
    end

    def find_or_create(message:, space:)
      app = AppModel.find(name: message.name, space: space)

      if app.nil?
        relationships = { space: { data: { guid: space.guid } } }
        app_create_args = { name: message.name, relationships: relationships }.merge(message.app_lifecycle_hash)

        app_create_message = AppCreateMessage.new(app_create_args)
        lifecycle = AppLifecycleProvider.provide_for_create(app_create_message)
        app = AppCreate.new(@user_audit_info).create(app_create_message, lifecycle)
      end

      app
    end
  end
end
