require 'spec_helper'
require 'rspec_api_documentation/dsl'

RSpec.resource 'Stacks', type: %i[api legacy_api] do
  let(:admin_auth_header) { admin_headers['HTTP_AUTHORIZATION'] }
  authenticated_request

  before do
    set_current_user_as_admin
  end

  let(:guid) { VCAP::CloudController::Stack.first.guid }

  describe 'Standard endpoints' do
    field :name, 'The name for the stack.'
    field :description, 'The description for the stack'

    standard_model_list(:stack, VCAP::CloudController::StacksController)
    standard_model_get(:stack)

    post '/v2/stacks' do
      context 'Creating a stack' do
        let(:fields_json) { Oj.dump({ name: 'example_stack', description: 'Description for the example stack' }) }

        example 'Create a Stack' do
          client.post '/v2/stacks', fields_json, headers
          expect(status).to eq 201
          standard_entity_response parsed_response, :stack,
                                   expected_values: {
                                     name: 'example_stack',
                                     description: 'Description for the example stack'
                                   }
        end

        context 'without a description' do
          let(:fields_json) { Oj.dump({ name: 'example_stack' }) }

          example 'Create a Stack', document: false do
            client.post '/v2/stacks', fields_json, headers
            expect(status).to eq 201
            standard_entity_response parsed_response, :stack,
                                     expected_values: {
                                       name: 'example_stack',
                                       description: nil
                                     }
          end
        end
      end
    end
  end

  standard_model_delete(:stack)
end
