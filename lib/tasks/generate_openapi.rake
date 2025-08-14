require 'yaml'
require_relative '../open_api_auto_generator'
require 'vcap/rest_api'
require 'factory_bot'

# Load all presenters
Dir[Rails.root.join('app/presenters/v3/*.rb')].each { |f| require f }
FactoryBot.find_definitions

namespace :openapi do
  desc 'Generate OpenAPI specification from code'
  task :generate, [:output_file] => :environment do |_task, args|
    output_file = args[:output_file] || 'public/openapi.yaml'

    puts "Generating OpenAPI specification in #{output_file}..."

    openapi_spec = {
      'openapi' => '3.0.0',
      'info' => {
        'title' => 'Cloud Foundry API',
        'version' => '3.130.0',
        'description' => 'Cloud Foundry API V3',
        'termsOfService' => 'https://www.cloudfoundry.org/policies/',
        'contact' => {
          'name' => 'Cloud Foundry',
          'url' => 'https://www.cloudfoundry.org/',
          'email' => 'cf-dev@lists.cloudfoundry.org'
        },
        'license' => {
          'name' => 'Apache 2.0',
          'url' => 'https://www.apache.org/licenses/LICENSE-2.0.html'
        }
      },
      'servers' => [
        { 'url' => 'https://api.example.org' }
      ],
      'paths' => {},
      'tags' => [],
      'components' => {
        'schemas' => {},
        'securitySchemes' => {
          'bearerAuth' => {
            'type' => 'http',
            'scheme' => 'bearer',
            'bearerFormat' => 'JWT'
          }
        },
        'parameters' => {},
        'responses' => {
          'Unauthorized' => {
            'description' => 'Unauthorized',
            'content' => { 'application/json' => { 'schema' => { '$ref' => '#/components/schemas/Error' } } }
          },
          'Forbidden' => {
            'description' => 'Forbidden',
            'content' => { 'application/json' => { 'schema' => { '$ref' => '#/components/schemas/Error' } } }
          },
          'NotFound' => {
            'description' => 'Not Found',
            'content' => { 'application/json' => { 'schema' => { '$ref' => '#/components/schemas/Error' } } }
          },
          'UnprocessableEntity' => {
            'description' => 'Unprocessable Entity',
            'content' => { 'application/json' => { 'schema' => { '$ref' => '#/components/schemas/Error' } } }
          },
          'BadRequest' => {
            'description' => 'Bad Request',
            'content' => { 'application/json' => { 'schema' => { '$ref' => '#/components/schemas/Error' } } }
          },
          'InternalServerError' => {
            'description' => 'Internal Server Error',
            'content' => { 'application/json' => { 'schema' => { '$ref' => '#/components/schemas/Error' } } }
          }
        }
      },
      'security' => [
        { 'bearerAuth' => [] }
      ],
      'externalDocs' => {
        'description' => 'Cloud Foundry API V3 Docs',
        'url' => 'https://v3-apidocs.cloudfoundry.org/'
      }
    }

    # Generate common components first
    generate_common_parameters(openapi_spec)
    generate_common_schemas(openapi_spec)

    # Discover and generate schemas from all V3 presenters
    discover_schemas_from_presenters(openapi_spec)

    tags = {}

    Rails.application.routes.routes.each do |route|
      next if route.path.spec.to_s.starts_with?('/rails/info/properties')

      # Skip non-API routes
      next if route.path.spec.to_s.starts_with?('/rails')

      raw_path = route.path.spec.to_s.gsub('(.:format)', '')

      # Add /v3 prefix for API routes (but not for root route)
      path = if raw_path == '/'
               raw_path
             else
               "/v3#{raw_path}"
             end

      # Convert route parameters to OpenAPI format
      path = path.gsub(/:(\w+)/, '{\1}')

      verb = route.verb.downcase
      next if verb.blank?

      controller_name = route.defaults[:controller]
      action_name = route.defaults[:action]

      next unless controller_name

      tag_name = if controller_name.include?('_v3')
                   controller_name.gsub('_v3', '').camelize
                 else
                   controller_name.split('/').last.gsub('_v3', '').camelize
                 end
      unless tags.key?(tag_name)
        model_name = "VCAP::CloudController::#{tag_name.singularize}"
        model_class = model_name.safe_constantize
        if model_class
          begin
            model_file_path = Rails.root.join('app', 'models', 'runtime', "#{model_class.name.demodulize.underscore}.rb")
            if File.exist?(model_file_path)
              lines = File.readlines(model_file_path)
              class_definition_line = lines.index { |l| l.match?(/\s*class\s+#{model_class.name.demodulize}/) }
              if class_definition_line
                comment_lines = []
                (class_definition_line - 1).downto(0) do |i|
                  line = lines[i].strip
                  break unless line.starts_with?('#')

                  comment_lines.unshift(line[1..].strip)
                end
                tags[tag_name] = comment_lines.join("\n") unless comment_lines.empty?
              end
            end
          rescue StandardError
            # Not all models will have a file or be easily inspectable.
          end
        end
        tags[tag_name] ||= ''
      end

      controller_class = if controller_name.include?('_v3')
                           "#{controller_name.camelize}Controller".safe_constantize
                         else
                           "V3::#{controller_name.camelize}Controller".safe_constantize ||
                             "#{controller_name.camelize}V3Controller".safe_constantize
                         end
      description = nil
      if controller_class&.method_defined?(action_name)
        begin
          # Using source_location is not ideal, but it's a way to get comments without
          # depending on gems that might not be available (like solargraph).
          file_path, line_number = controller_class.instance_method(action_name).source_location
          if file_path && line_number
            lines = File.readlines(file_path)
            comment_lines = []
            (line_number - 2).downto(0) do |i|
              line = lines[i].strip
              break unless line.starts_with?('#')

              comment_lines.unshift(line[1..].strip)
            end
            description = comment_lines.join("\n") unless comment_lines.empty?
          end
        rescue NameError
          # Some controllers might not be easily loadable this way.
        end
      end

      # Generate Cloud Foundry style summary and description
      cf_summary = generate_cf_style_summary(action_name, tag_name, path, verb)
      cf_description = generate_cf_style_description(action_name, tag_name, path, verb)

      operation = {
        'summary' => summary_from_comment(description).presence || cf_summary,
        'description' => description.presence || cf_description,
        'operationId' => "#{verb}#{path.gsub(%r{[/\{\}]}, '_')}#{action_name.camelize}",
        'tags' => [tag_name],
        'parameters' => [],
        'responses' => {}
      }

      # Extract path parameters
      path.scan(/\{(\w+)\}/).each do |param|
        param_name = param.first
        operation['parameters'] << if param_name == 'guid'
                                     { '$ref' => '#/components/parameters/Guid' }
                                   else
                                     {
                                       'name' => param_name,
                                       'in' => 'path',
                                       'required' => true,
                                       'schema' => { 'type' => 'string' }
                                     }
                                   end
      end
      operation['parameters'].uniq! { |p| p['name'] || p['$ref'] }

      # Define default success response
      success_status = '200'
      case action_name
      when 'create'
        success_status = '201'
      when 'destroy'
        success_status = '202'
      when 'update'
        success_status = '200'
      end
      operation['responses'][success_status] = { 'description' => 'Successful response' }

      # Add error responses
      operation['responses']['400'] = { '$ref' => '#/components/responses/BadRequest' }
      operation['responses']['401'] = { '$ref' => '#/components/responses/Unauthorized' }
      operation['responses']['403'] = { '$ref' => '#/components/responses/Forbidden' }
      operation['responses']['404'] = { '$ref' => '#/components/responses/NotFound' }
      operation['responses']['422'] = { '$ref' => '#/components/responses/UnprocessableEntity' }
      operation['responses']['500'] = { '$ref' => '#/components/responses/InternalServerError' }

      if action_name == 'index'
        class_name = controller_name.split('/').last.gsub('_v3', '').camelize
        list_message_class_name = "VCAP::CloudController::#{class_name}ListMessage"
        list_message_class = list_message_class_name.safe_constantize

        if list_message_class
          dynamic_params = discover_list_message_parameters(list_message_class)
          operation['parameters'].concat(dynamic_params)
        end
      end

      # Introspect presenter for response schema
      presenter_name = map_controller_to_presenter(controller_name)
      presenter_class_name = "VCAP::CloudController::Presenters::V3::#{presenter_name.camelize}Presenter"
      presenter_class = presenter_class_name.safe_constantize

      if presenter_class
        schema_name = presenter_class_name.demodulize.gsub(/Presenter$/, '')
        schema = OpenApiAutoGenerator.schema_from_presenter(presenter_class)

        if schema && !schema['properties'].empty?
          openapi_spec['components']['schemas'][schema_name] ||= schema
          if action_name == 'index'
            paginated_schema_name = "Paginated#{schema_name}Response"
            openapi_spec['components']['schemas'][paginated_schema_name] ||= {
              'type' => 'object',
              'properties' => {
                'pagination' => { '$ref' => '#/components/schemas/Pagination' },
                'resources' => {
                  'type' => 'array',
                  'items' => { '$ref' => "#/components/schemas/#{schema_name}" }
                }
              }
            }
            operation['responses'][success_status]['content'] = {
              'application/json' => {
                'schema' => { '$ref' => "#/components/schemas/#{paginated_schema_name}" }
              }
            }
          else
            operation['responses'][success_status]['content'] = {
              'application/json' => {
                'schema' => { '$ref' => "#/components/schemas/#{schema_name}" }
              }
            }
          end
        end
      end

      # Introspect message for request schema
      base_name = controller_name.split('/').last.camelize
      # Handle special case for v3 controllers (e.g., apps_v3 -> App, not AppV3)
      base_name = base_name.gsub(/V\d+$/, '') if base_name.end_with?('V3')
      # Singularize the base name after removing V3 suffix
      base_name = base_name.singularize
      message_class_name = "VCAP::CloudController::#{base_name}#{action_name.camelize}Message"
      message_class = message_class_name.safe_constantize
      if message_class.respond_to?(:allowed_keys)
        schema_name = "#{message_class.name.demodulize}Request"
        schema = OpenApiAutoGenerator.schema_from_message(message_class, openapi_spec)
        if schema && !schema['properties'].empty?
          openapi_spec['components']['schemas'][schema_name] ||= schema
          operation['requestBody'] = {
            'content' => {
              'application/json' => {
                'schema' => { '$ref' => "#/components/schemas/#{schema_name}" }
              }
            }
          }
        end
      end

      openapi_spec['paths'][path] ||= {}
      openapi_spec['paths'][path][verb] = operation
    end

    openapi_spec['tags'] = tags.map { |name, description| { 'name' => name, 'description' => description } }

    File.write(output_file, openapi_spec.to_yaml)

    puts 'OpenAPI specification generated successfully.'
  end

  def self.map_controller_to_presenter(controller_name)
    # Map controller names to presenter names
    case controller_name
    when 'apps_v3'
      'app'
    when 'organizations_v3'
      'organization'
    when 'spaces_v3'
      'space'
    when 'service_instances_v3'
      'service_instance'
    else
      controller_name.split('/').last.singularize
    end
  end

  def self.summary_from_comment(comment)
    return '' unless comment

    comment.split("\n").first
  end

  def self.generate_cf_style_summary(action_name, tag_name, path, verb)
    # Convert tag name to a descriptive resource name
    resource_name = case tag_name
                    when 'Apps' then 'app'
                    when 'Organizations' then 'organization'
                    when 'Spaces' then 'space'
                    when 'Routes' then 'route'
                    when 'Domains' then 'domain'
                    when 'Services' then 'service'
                    when 'ServiceInstances' then 'service instance'
                    when 'ServiceBrokers' then 'service broker'
                    when 'ServiceOfferings' then 'service offering'
                    when 'ServicePlans' then 'service plan'
                    when 'ServiceCredentialBindings' then 'service credential binding'
                    when 'ServiceRouteBindings' then 'service route binding'
                    when 'Buildpacks' then 'buildpack'
                    when 'Packages' then 'package'
                    when 'Builds' then 'build'
                    when 'Deployments' then 'deployment'
                    when 'Processes' then 'process'
                    when 'Tasks' then 'task'
                    when 'Droplets' then 'droplet'
                    when 'Revisions' then 'revision'
                    when 'Users' then 'user'
                    when 'Roles' then 'role'
                    when 'IsolationSegments' then 'isolation segment'
                    when 'SecurityGroups' then 'security group'
                    when 'Stacks' then 'stack'
                    when 'FeatureFlags' then 'feature flag'
                    when 'OrganizationQuotas' then 'organization quota'
                    when 'SpaceQuotas' then 'space quota'
                    when 'Events' then 'event'
                    when 'AppUsageEvents' then 'app usage event'
                    when 'ServiceUsageEvents' then 'service usage event'
                    when 'EnvironmentVariableGroups' then 'environment variable group'
                    else
                      tag_name.downcase.gsub(/([a-z])([A-Z])/, '\1 \2')
                    end

    # Helper to determine correct article (a/an)
    article = %w[a e i o u].include?(resource_name[0]) ? 'an' : 'a'

    # Check for specific action patterns
    case action_name
    when 'index'
      if path.include?('relationships')
        relationship_part = path.split('/relationships/').last
        relationship_name = relationship_part.tr('_', ' ')
        "List #{relationship_name} relationship"
      else
        "List #{resource_name.pluralize}"
      end
    when 'show'
      if path.include?('relationships')
        relationship_part = path.split('/relationships/').last
        relationship_name = relationship_part.tr('_', ' ')
        "Get #{relationship_name} relationship"
      else
        "Get #{article} #{resource_name}"
      end
    when 'create'
      if path.include?('relationships')
        'Create relationship'
      else
        "Create #{article} #{resource_name}"
      end
    when 'update'
      if path.include?('relationships')
        relationship_part = path.split('/relationships/').last
        relationship_name = relationship_part.tr('_', ' ')
        "Update #{relationship_name} relationship"
      else
        "Update #{article} #{resource_name}"
      end
    when 'destroy', 'delete'
      if path.include?('relationships')
        'Delete relationship'
      else
        "Delete #{article} #{resource_name}"
      end
    when 'start'
      "Start #{article} #{resource_name}"
    when 'stop'
      "Stop #{article} #{resource_name}"
    when 'restart'
      "Restart #{article} #{resource_name}"
    when 'upload'
      "Upload #{resource_name} bits"
    when 'download'
      "Download #{resource_name} bits"
    when 'stage'
      "Stage #{article} #{resource_name}"
    when 'assign_current_droplet'
      'Assign current droplet'
    when 'assign'
      "Assign #{resource_name}"
    when 'unassign'
      "Unassign #{resource_name}"
    when 'share'
      "Share #{article} #{resource_name}"
    when 'unshare'
      "Unshare #{article} #{resource_name}"
    when 'scale'
      "Scale #{article} #{resource_name}"
    when 'stats'
      "Get #{resource_name} stats"
    when 'env'
      "Get #{resource_name} environment"
    when 'permissions'
      "Get #{resource_name} permissions"
    when 'cancel'
      "Cancel #{article} #{resource_name}"
    when 'apply_manifest'
      'Apply manifest'
    when 'clear_buildpack_cache'
      'Clear buildpack cache'
    else
      # Check for special path patterns
      if path.include?('/actions/')
        action_part = path.split('/actions/').last
        "#{action_part.humanize} #{resource_name}"
      elsif path.include?('/features/')
        feature_part = path.split('/features/').last
        case verb
        when 'get'
          if feature_part == 'features'
            "List #{resource_name} features"
          else
            "Get #{resource_name} feature"
          end
        when 'patch'
          "Update #{resource_name} feature"
        else
          "#{verb.humanize} #{resource_name} feature"
        end
      else
        action_name.humanize
      end
    end
  end

  def self.generate_cf_style_description(action_name, tag_name, path, _verb)
    resource_name = case tag_name
                    when 'Apps' then 'app'
                    when 'Organizations' then 'organization'
                    when 'Spaces' then 'space'
                    when 'Routes' then 'route'
                    when 'Domains' then 'domain'
                    when 'Services' then 'service'
                    when 'ServiceInstances' then 'service instance'
                    when 'ServiceBrokers' then 'service broker'
                    when 'ServiceOfferings' then 'service offering'
                    when 'ServicePlans' then 'service plan'
                    when 'ServiceCredentialBindings' then 'service credential binding'
                    when 'ServiceRouteBindings' then 'service route binding'
                    when 'Buildpacks' then 'buildpack'
                    when 'Packages' then 'package'
                    when 'Builds' then 'build'
                    when 'Deployments' then 'deployment'
                    when 'Processes' then 'process'
                    when 'Tasks' then 'task'
                    when 'Droplets' then 'droplet'
                    when 'Revisions' then 'revision'
                    when 'Users' then 'user'
                    when 'Roles' then 'role'
                    when 'IsolationSegments' then 'isolation segment'
                    when 'SecurityGroups' then 'security group'
                    when 'Stacks' then 'stack'
                    when 'FeatureFlags' then 'feature flag'
                    when 'OrganizationQuotas' then 'organization quota'
                    when 'SpaceQuotas' then 'space quota'
                    when 'Events' then 'event'
                    when 'AppUsageEvents' then 'app usage event'
                    when 'ServiceUsageEvents' then 'service usage event'
                    when 'EnvironmentVariableGroups' then 'environment variable group'
                    else
                      tag_name.downcase.gsub(/([a-z])([A-Z])/, '\1 \2')
                    end

    case action_name
    when 'index'
      if path.include?('relationships')
        "This endpoint retrieves the #{path.split('/relationships/').last.tr('_', ' ')} relationship."
      else
        "This endpoint retrieves the #{resource_name.pluralize} the user has access to."
      end
    when 'show'
      if path.include?('relationships')
        "This endpoint retrieves the #{path.split('/relationships/').last.tr('_', ' ')} relationship."
      else
        "This endpoint retrieves the specified #{resource_name} object."
      end
    when 'create'
      if path.include?('relationships')
        'This endpoint creates a new relationship.'
      else
        "This endpoint creates a new #{resource_name}."
      end
    when 'update'
      if path.include?('relationships')
        "This endpoint updates the #{path.split('/relationships/').last.tr('_', ' ')} relationship."
      else
        "This endpoint updates the specified #{resource_name}."
      end
    when 'destroy', 'delete'
      if path.include?('relationships')
        'This endpoint deletes the relationship.'
      else
        "This endpoint deletes the specified #{resource_name}."
      end
    when 'start'
      "This endpoint starts the specified #{resource_name}."
    when 'stop'
      "This endpoint stops the specified #{resource_name}."
    when 'restart'
      "This endpoint restarts the specified #{resource_name}."
    when 'upload'
      "This endpoint uploads bits for the specified #{resource_name}."
    when 'download'
      "This endpoint downloads bits for the specified #{resource_name}."
    when 'stage'
      "This endpoint stages the specified #{resource_name}."
    when 'scale'
      "This endpoint scales the specified #{resource_name}."
    when 'stats'
      "This endpoint retrieves stats for the specified #{resource_name}."
    when 'env'
      "This endpoint retrieves environment variables for the specified #{resource_name}."
    when 'permissions'
      "This endpoint retrieves permissions for the specified #{resource_name}."
    when 'clear_buildpack_cache'
      'This endpoint deletes all of the existing buildpack caches in the blobstore.'
    else
      "This endpoint performs the #{action_name} operation on the #{resource_name}."
    end
  end

  def self.generate_common_parameters(openapi_spec)
    # Generate standard pagination and filtering parameters
    common_params = {
      'Page' => {
        'name' => 'page',
        'in' => 'query',
        'description' => 'Page to display; valid values are integers >= 1',
        'schema' => { 'type' => 'integer', 'minimum' => 1, 'default' => 1 }
      },
      'PerPage' => {
        'name' => 'per_page',
        'in' => 'query',
        'description' => 'Number of results per page, valid values are 1 through 5000',
        'schema' => { 'type' => 'integer', 'minimum' => 1, 'maximum' => 5000, 'default' => 50 }
      },
      'OrderBy' => {
        'name' => 'order_by',
        'in' => 'query',
        'description' => 'Order results by a specific field. Prepend with - to sort descending.',
        'schema' => { 'type' => 'string' }
      },
      'Guid' => {
        'name' => 'guid',
        'in' => 'path',
        'required' => true,
        'description' => 'The resource identifier',
        'schema' => { 'type' => 'string', 'format' => 'uuid' }
      }
    }

    # Add timestamp filters
    %w[created_ats updated_ats].each do |param|
      common_params[param.camelize] = {
        'name' => param,
        'in' => 'query',
        'description' => 'Timestamp to filter by. When filtering on equality, several comma-delimited timestamps may be passed.',
        'schema' => { 'type' => 'string' }
      }
    end

    # Add common array filters
    {
      'Guids' => 'guids',
      'Names' => 'names',
      'OrganizationGuids' => 'organization_guids',
      'SpaceGuids' => 'space_guids'
    }.each do |key, param|
      item_type = param.include?('guid') ? { 'type' => 'string', 'format' => 'uuid' } : { 'type' => 'string' }
      common_params[key] = {
        'name' => param,
        'in' => 'query',
        'description' => "Comma-delimited list of #{param.gsub('_', ' ')} to filter by",
        'style' => 'form',
        'explode' => false,
        'schema' => { 'type' => 'array', 'items' => item_type }
      }
    end

    openapi_spec['components']['parameters'].merge!(common_params)
  end

  def self.generate_common_schemas(openapi_spec)
    # Generate pagination schema
    openapi_spec['components']['schemas']['Pagination'] = {
      'type' => 'object',
      'properties' => {
        'total_results' => { 'type' => 'integer' },
        'total_pages' => { 'type' => 'integer' },
        'first' => { 'type' => 'object', 'properties' => { 'href' => { 'type' => 'string', 'format' => 'uri' } } },
        'last' => { 'type' => 'object', 'properties' => { 'href' => { 'type' => 'string', 'format' => 'uri' } } },
        'next' => { 'type' => 'object', 'nullable' => true, 'properties' => { 'href' => { 'type' => 'string', 'format' => 'uri' } } },
        'previous' => { 'type' => 'object', 'nullable' => true, 'properties' => { 'href' => { 'type' => 'string', 'format' => 'uri' } } }
      }
    }

    # Generate error schema
    openapi_spec['components']['schemas']['Error'] = {
      'type' => 'object',
      'properties' => {
        'errors' => {
          'type' => 'array',
          'items' => {
            'type' => 'object',
            'properties' => {
              'code' => { 'type' => 'integer' },
              'detail' => { 'type' => 'string' },
              'title' => { 'type' => 'string' }
            }
          }
        }
      }
    }

    # Generate basic components that appear frequently
    openapi_spec['components']['schemas']['Metadata'] = {
      'type' => 'object',
      'properties' => {
        'labels' => {
          'type' => 'object',
          'additionalProperties' => { 'type' => 'string' },
          'description' => 'Key-value pairs of labels'
        },
        'annotations' => {
          'type' => 'object',
          'additionalProperties' => { 'type' => 'string' },
          'description' => 'Key-value pairs of annotations'
        }
      },
      'description' => 'Metadata containing labels and annotations'
    }

    openapi_spec['components']['schemas']['Links'] = {
      'type' => 'object',
      'additionalProperties' => {
        'type' => 'object',
        'properties' => {
          'href' => { 'type' => 'string', 'format' => 'uri' },
          'method' => { 'type' => 'string' }
        }
      }
    }
  end

  def self.discover_list_message_parameters(list_message_class)
    return [] unless list_message_class.respond_to?(:allowed_keys)

    parameters = []

    list_message_class.allowed_keys.each do |key|
      param_name = key.to_s

      # Skip if parameter already exists
      next if parameters.any? { |p| p['name'] == param_name }

      # Map to common parameters if available
      param_ref = case key
                  when :page
                    '#/components/parameters/Page'
                  when :per_page
                    '#/components/parameters/PerPage'
                  when :order_by
                    '#/components/parameters/OrderBy'
                  when :created_ats
                    '#/components/parameters/CreatedAts'
                  when :updated_ats
                    '#/components/parameters/UpdatedAts'
                  when :guids
                    '#/components/parameters/Guids'
                  when :names
                    '#/components/parameters/Names'
                  when :organization_guids
                    '#/components/parameters/OrganizationGuids'
                  when :space_guids
                    '#/components/parameters/SpaceGuids'
                  end

      if param_ref
        parameters << { '$ref' => param_ref }
      else
        # Generate parameter schema dynamically
        schema = infer_parameter_schema(key)
        parameters << {
          'name' => param_name,
          'in' => 'query',
          'description' => humanize_parameter_name(param_name),
          'schema' => schema
        }
      end
    end

    parameters
  end

  def self.infer_parameter_schema(key)
    key_str = key.to_s

    # Check for array parameters
    if key_str.pluralize == key_str || key_str.include?('_guids') || key_str.include?('_names')
      item_type = if key_str.include?('guid')
                    { 'type' => 'string', 'format' => 'uuid' }
                  else
                    { 'type' => 'string' }
                  end
      return { 'type' => 'array', 'items' => item_type }
    end

    # Check for boolean parameters
    return { 'type' => 'boolean' } if key_str.include?('enable') || key_str.include?('disable') || key_str == 'suspended'

    # Check for timestamp parameters
    return { 'type' => 'string', 'format' => 'date-time' } if key_str.include?('_at') || key_str.include?('timestamp')

    # Default to string
    { 'type' => 'string' }
  end

  def self.humanize_parameter_name(param_name)
    param_name.humanize.downcase.capitalize
  end

  def self.discover_v3_presenters
    # Find all V3 presenter files
    presenter_files = Dir.glob(Rails.root.join('app/presenters/v3/**/*_presenter.rb'))

    presenters = []
    presenter_files.each do |file|
      # Extract class name from file path
      relative_path = file.gsub(Rails.root.to_s + '/', '')
      class_name = relative_path.
                   gsub('app/presenters/', '').
                   gsub('.rb', '').
                   split('/').
                   map(&:camelize).
                   join('::')

      full_class_name = "VCAP::CloudController::Presenters::#{class_name}"

      begin
        presenter_class = full_class_name.constantize
        next unless presenter_class.instance_methods.include?(:to_hash)

        presenters << {
          name: class_name.split('::').last.gsub('Presenter', ''),
          class: presenter_class,
          file: relative_path
        }
      rescue NameError => e
        puts "Warning: Could not load presenter class #{full_class_name}: #{e.message}"
        next
      end
    end

    presenters
  end

  def self.discover_schemas_from_presenters(openapi_spec)
    presenters = discover_v3_presenters

    presenters.each do |presenter_info|
      schema_name = presenter_info[:name]

      # Skip MetadataPresenter as it conflicts with our common Metadata schema
      next if schema_name == 'Metadata'

      schema = OpenApiAutoGenerator.schema_from_presenter(presenter_info[:class])

      if schema
        openapi_spec['components']['schemas'][schema_name] = schema
        puts "Generated schema for #{schema_name} from #{presenter_info[:file]}"
      else
        puts "Warning: Could not generate schema for #{schema_name}"
      end
    end

    openapi_spec
  end
end
