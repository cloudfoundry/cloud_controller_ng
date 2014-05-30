module VCAP::CloudController
  class AppSecurityGroup < Sequel::Model
    APP_SECURITY_GROUP_NAME_REGEX = /\A[[:alnum:][:punct:][:print:]]+\Z/.freeze

    import_attributes :name, :rules
    export_attributes :name, :rules

    def validate
      validates_presence :name
      validates_format APP_SECURITY_GROUP_NAME_REGEX, :name
    end
  end
end