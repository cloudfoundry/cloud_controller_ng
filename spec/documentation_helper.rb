module VCAP::CloudController
  class DocumentationConfigure
    def self.configure!(example_class)
      if should_run_rails?(example_class)
        change_app rails_app
      else
        change_app sinatra_app
      end
    end

    def self.rails_app
      @documentation_rails_app ||= Rails.application.app
    end

    def self.sinatra_app
      @documentation_sinatra_app ||= FakeFrontController.new(TestConfig.config)
    end

    def self.change_app(app)
      RspecApiDocumentation.configure do |c|
        c.app = app
      end
    end

    def self.should_run_rails?(example_class)
      !!(/(v3)|(V3)/ =~ example_class.inspect)
    end
  end
end
