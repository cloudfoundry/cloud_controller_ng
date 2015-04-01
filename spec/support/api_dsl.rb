require 'active_support/concern'

module ApiDsl
  extend ActiveSupport::Concern

  def validate_response(model, json, expected_values={}, ignored_attributes=[])
    ignored_attributes.push :guid
    expected_attributes_for_model(model).each do |expected_attribute|
      # refactor: pass exclusions, and figure out which are valid to not be there
      next if ignored_attributes.include? expected_attribute

      # if a relationship is not present, its url should not be present
      next if field_is_url_and_relationship_not_present?(json, expected_attribute)

      expect(json).to have_key expected_attribute.to_s
      if expected_values.key? expected_attribute.to_sym
        expect(json[expected_attribute.to_s]).to eq(expected_values[expected_attribute.to_sym])
      end
    end
  end

  def standard_list_response(response_json, model)
    standard_paginated_response_format? response_json
    resource = response_json['resources'].first
    standard_entity_response resource, model
  end

  def standard_entity_response(json, model, expected_values={})
    expect(json).to include('metadata')
    expect(json).to include('entity')
    standard_metadata_response_format? json['metadata'], model
    validate_response model, json['entity'], expected_values
  end

  def standard_paginated_response_format?(json)
    validate_response VCAP::RestAPI::PaginatedResponse, json
  end

  def standard_metadata_response_format?(json, model)
    ignored_attributes = []
    ignored_attributes = [:updated_at] unless model_has_updated_at?(model)
    validate_response VCAP::RestAPI::MetadataMessage, json, {}, ignored_attributes
  end

  def expected_attributes_for_model(model)
    return model.fields.keys if model.respond_to? :fields
    "VCAP::CloudController::#{model.to_s.classify}".constantize.export_attrs
  end

  def parsed_response
    parse(response_body)
  end

  def field_is_url_and_relationship_not_present?(json, field)
    if field =~ /(.*)_url$/
      !json["#{Regexp.last_match[1]}_guid".to_sym]
    end
  end

  def audited_event(event)
    attributes = event.columns.map do |column|
      if column == :metadata
        { attribute_name: column.to_s, value: JSON.pretty_generate(JSON.parse(event[column])), is_json: true }
      else
        { attribute_name: column.to_s, value: event[column], is_json: false }
      end
    end

    RSpec.current_example.metadata[:audit_records] ||= []
    RSpec.current_example.metadata[:audit_records] << { type: event[:type], attributes: attributes }
  end

  def field_data(name)
    self.class.metadata[:fields].detect do |field|
      name == field[:name]
    end
  end

  def fields_json(overrides={})
    MultiJson.dump(required_fields.merge(overrides), pretty: true)
  end

  def required_fields
    self.class.metadata[:fields].each_with_object({}) do |field, memo|
      memo[field[:name].to_sym] = (field[:valid_values] || field[:example_values]).first if field[:required]
    end
  end

  private

  def model_has_updated_at?(model)
    "VCAP::CloudController::#{model.to_s.classify}".constantize.columns.include?(:updated_at)
  end

  def add_deprecation_warning
    example.metadata[:description] << ' (deprecated)' if response_headers['X-Cf-Warnings'] && response_headers['X-Cf-Warnings'][/deprecated/i]
  end

  module ClassMethods
    def api_version
      '/v2'
    end

    def root(model)
      "#{api_version}/#{model.to_s.pluralize}"
    end

    def standard_model_list(model, controller, options={})
      outer_model_description = ''
      model_name = options[:path] || model
      title = options[:title] || model_name.to_s.pluralize.titleize

      if options[:outer_model]
        model_name = options[:path] if options[:path]
        path = "#{options[:outer_model].to_s.pluralize}/:guid/#{model_name}"
        outer_model_description = " for the #{options[:outer_model].to_s.singularize.titleize}"
      else
        path = options[:path] || model
      end

      get root(path) do
        standard_list_parameters controller
        example_request "List all #{title}#{outer_model_description}" do
          expect(status).to eq 200
          standard_list_response parsed_response, model
        end
      end
    end

    def nested_model_associate(model, outer_model)
      path = "#{api_version}/#{outer_model.to_s.pluralize}/:guid/#{model.to_s.pluralize}/:#{model}_guid"

      put path do
        example_request "Associate #{model.to_s.titleize} with the #{outer_model.to_s.titleize}" do
          expect(status).to eq 201
          standard_entity_response parsed_response, outer_model
        end
      end
    end

    def nested_model_remove(model, outer_model)
      path_name = "#{api_version}/#{outer_model.to_s.pluralize}/:guid/#{model.to_s.pluralize}/:#{model}_guid"

      delete path_name do
        example "Remove #{model.to_s.titleize} from the #{outer_model.to_s.titleize}" do
          path = "#{self.class.api_version}/#{outer_model.to_s.pluralize}/#{send(:guid)}/#{model.to_s.pluralize}/#{send("associated_#{model}_guid")}"
          client.delete path, '', headers
          expect(status).to eq 201
          standard_entity_response parsed_response, outer_model
        end
      end
    end

    def standard_model_get(model, options={})
      path = options[:path] || model
      title = options[:title] || path.to_s.singularize.titleize
      get "#{root(path)}/:guid" do
        example_request "Retrieve a Particular #{title}" do
          standard_entity_response parsed_response, model
          if options[:nested_associations]
            options[:nested_associations].each do |association_name|
              expect(parsed_response['entity'].keys).to include("#{association_name}_url")
            end
          end
        end
      end
    end

    def standard_model_delete(model, options={})
      title = options[:title] || model.to_s.titleize
      delete "#{root(model)}/:guid" do
        parameter :guid, "The guid of the #{title}"
        request_parameter :async, "Will run the delete request in a background job. Recommended: 'true'." unless options[:async] == false

        example_request "Delete a Particular #{title}" do
          expect(status).to eq 204
          after_standard_model_delete(guid) if respond_to?(:after_standard_model_delete)
        end
      end
    end

    def standard_model_delete_without_async(model)
      delete "#{root(model)}/:guid" do
        example_request "Delete a Particular #{model.to_s.titleize}" do
          expect(status).to eq 204
          after_standard_model_delete(guid) if respond_to?(:after_standard_model_delete)
        end
      end
    end

    def standard_list_parameters(controller)
      if controller.query_parameters.size > 0
        query_parameter_description = 'Parameters used to filter the result set.<br/>'
        query_parameter_description += 'Format queries as &lt;filter&gt;&lt;op&gt;&lt;value&gt;<br/>'
        query_parameter_description += ' Valid ops: : &gt;= &lt;= &lt; &gt; IN<br/>'
        query_parameter_description += " Valid filters: #{controller.query_parameters.to_a.join(', ')}"

        examples = ['q=filter:value', 'q=filter>value', 'q=filter IN a,b,c']
        request_parameter :q, query_parameter_description, { html: true, example_values: examples }
      end
      pagination_parameters
      request_parameter :'inline-relations-depth', "0 - don't inline any relations and return URLs.  Otherwise, inline to depth N.", deprecated: true
      request_parameter :'orphan-relations', '0 - de-duplicate object entries in response', deprecated: true
      request_parameter :'exclude-relations', 'comma-delimited list of relations to drop from response', deprecated: true
      request_parameter :'include-relations', 'comma-delimited list of the only relations to include in response', deprecated: true
    end

    def pagination_parameters
      request_parameter :page, 'Page of results to fetch'
      request_parameter :'results-per-page', 'Number of results per page'
      request_parameter :'order-direction', 'Order of the results: asc (default) or desc'
    end

    def request_parameter(name, description, options={})
      if options[:html]
        options[:description_html] = description
      end

      parameter name, description, options
      metadata[:request_parameters] ||= []
      metadata[:request_parameters].push(options.merge(name: name.to_s, description: description))
    end

    def field(name, description='', options={})
      metadata[:fields] = metadata[:fields] ? metadata[:fields].dup : []
      metadata[:fields].push(options.merge(name: name.to_s, description: description))
    end

    def modify_fields_for_update
      metadata[:fields] = metadata[:fields].collect do |field|
        field.delete(:required)
        field.delete(:default)
        field
      end
    end

    def authenticated_request
      header 'AUTHORIZATION', :admin_auth_header
    end
  end
end
