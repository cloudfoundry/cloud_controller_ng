module CloudController
  class ControllerFactory
    include VCAP::CloudController

    def initialize(config, logger, env, params, body, sinatra=nil)
      @config  = config
      @logger  = logger
      @env     = env
      @params  = params
      @body    = body
      @sinatra = sinatra
    end

    def create_controller(klass)
      dependencies = dependencies_for_class(klass)
      klass.new(@config, @logger, @env, @params, @body, @sinatra, dependencies)
    end

    private

    def dependency_locator
      DependencyLocator.instance
    end

    def default_dependencies
      {
        object_renderer:     dependency_locator.object_renderer,
        collection_renderer: dependency_locator.paginated_collection_renderer,
      }
    end

    def dependencies_for_class(klass)
      custom_dependencies = if klass.respond_to?(:dependencies)
                              fetch_dependencies(klass.dependencies)
                            else
                              {}
                            end

      default_dependencies.merge(custom_dependencies)
    end

    def fetch_dependencies(dependency_names)
      dependencies = dependency_names.map do |name|
        dependency_locator.send(name)
      end
      Hash[dependency_names.zip(dependencies)]
    end
  end
end
