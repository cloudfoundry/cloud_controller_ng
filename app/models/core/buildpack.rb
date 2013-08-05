module VCAP::CloudController
  module Models
    class Buildpack < Sequel::Model
      export_attributes :name, :url
      import_attributes :name, :url

      def validate
        validates_presence :name
        validates_unique   :name

        validates_presence :url
        validates_git_url  :url
      end
    end
  end
end
