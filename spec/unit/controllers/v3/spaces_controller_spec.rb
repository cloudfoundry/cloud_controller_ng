require 'rails_helper'
require 'permissions_spec_helper'

RSpec.describe SpacesV3Controller, type: :controller do
  describe '#show' do
    let(:user) { set_current_user(VCAP::CloudController::User.make) }

    let!(:org) { VCAP::CloudController::Organization.make(name: 'Lyle\'s Farm') }
    let!(:space) { VCAP::CloudController::Space.make(name: 'Cat', organization: org) }

    describe 'permissions by role' do
      before do
        set_current_user(user)
      end

      role_to_expected_http_response = {
        'admin'               => 200,
        'space_developer'     => 200,
        'admin_read_only'     => 200,
        'global_auditor'      => 200,
        'space_manager'       => 200,
        'space_auditor'       => 200,
        'org_manager'         => 200,
        'org_auditor'         => 404,
        'org_billing_manager' => 404,
      }.freeze

      role_to_expected_http_response.each do |role, expected_return_value|
        context "as an #{role}" do
          it "returns #{expected_return_value}" do
            set_current_user_as_role(role: role, org: org, space: space, user: user)

            get :show, params: { guid: space.guid }

            expect(response.status).to eq(expected_return_value),
              "Expected #{expected_return_value}, but got #{response.status}. Response: #{response.body}"
            if expected_return_value == 200
              expect(parsed_body['guid']).to eq(space.guid)
              expect(parsed_body['name']).to eq('Cat')
              expect(parsed_body['created_at']).to match(iso8601)
              expect(parsed_body['updated_at']).to match(iso8601)
              expect(parsed_body['links']['self']['href']).to match(%r{/v3/spaces/#{space.guid}$})
            end
          end
        end
      end
    end
  end

  describe '#index' do
    let(:user) { set_current_user(VCAP::CloudController::User.make) }

    let!(:org1) { VCAP::CloudController::Organization.make(name: 'Lyle\'s Farm') }
    let!(:org2) { VCAP::CloudController::Organization.make(name: 'Greg\'s Ranch') }
    let!(:org1_space) { VCAP::CloudController::Space.make(name: 'Alpaca', organization: org1) }
    let!(:org1_other_space) { VCAP::CloudController::Space.make(name: 'Lamb', organization: org1) }
    let!(:org2_space) { VCAP::CloudController::Space.make(name: 'Horse', organization: org2) }
    names_in_associated_org    = %w/Alpaca Lamb/
    names_in_associated_space  = %w/Alpaca/
    names_in_nonassociated_org = %w/Horse/

    describe 'permissions by role' do
      role_to_expected_http_response = {
        'admin'               => names_in_associated_org + names_in_nonassociated_org,
        'admin_read_only'     => names_in_associated_org + names_in_nonassociated_org,
        'global_auditor'      => names_in_associated_org + names_in_nonassociated_org,
        'org_manager'         => names_in_associated_org,
        'org_auditor'         => [],
        'org_billing_manager' => [],
        'space_manager'       => names_in_associated_space,
        'space_auditor'       => names_in_associated_space,
        'space_developer'     => names_in_associated_space,
      }.freeze

      role_to_expected_http_response.each do |role, expected_return_value|
        context "as an #{role}" do
          it "returns #{expected_return_value}" do
            set_current_user_as_role(role: role, org: org1, space: org1_space, user: user)

            get :index

            expect(response.status).to eq(200), response.body
            expect(parsed_body['resources'].map { |h| h['name'] }).to match_array(expected_return_value)
          end
        end
      end
    end

    context 'pagination' do
      before do
        allow_user_global_read_access(user)
      end

      context 'when pagination options are specified' do
        let(:page) { 2 }
        let(:per_page) { 1 }
        let(:params) { { 'page' => page, 'per_page' => per_page, 'order_by' => 'name' } }

        it 'paginates the response' do
          get :index, params: params

          parsed_response = parsed_body
          expect(parsed_response['pagination']['total_results']).to eq(3)
          expect(parsed_response['resources'].length).to eq(per_page)
          expect(parsed_response['resources'][0]['name']).to eq('Horse')
        end
      end

      context 'when invalid pagination values are specified' do
        it 'returns 400' do
          get :index, params: { per_page: 'meow' }

          expect(response.status).to eq 400
          expect(response.body).to include('Per page must be a positive integer')
          expect(response.body).to include('BadQueryParameter')
        end
      end

      context 'when unknown pagination fields are specified' do
        it 'returns 400' do
          get :index, params: { meow: 'bad-val', nyan: 'mow' }

          expect(response.status).to eq 400
          expect(response.body).to include('BadQueryParameter')
          expect(response.body).to include('Unknown query parameter(s)')
          expect(response.body).to include('nyan')
          expect(response.body).to include('meow')
        end
      end
    end

    context 'when the user is in orgs but no spaces' do
      before do
        org1.add_user(user)
        org2.add_user(user)
      end

      it 'returns all spaces they are a developer or manager' do
        get :index

        expect(response.status).to eq(200)
        expect(parsed_body['resources'].map { |r| r['name'] }).to match_array([])
      end
    end

    context 'when the user has multiple roles in the same space' do
      before do
        org1.add_user(user)
        org1_space.add_manager(user)
        org1_space.add_auditor(user)
        org1_space.add_developer(user)
      end

      it 'returns the spaces' do
        get :index

        expect(response.status).to eq(200)
        expect(parsed_body['resources'].map { |r| r['name'] }).to match_array([
          org1_space.name
        ])
      end
    end

    context 'when the user has multiple roles in different orgs' do
      before do
        org1.add_user(user)
        org2.add_user(user)
        org1_space.add_manager(user)
        org1_other_space.add_developer(user)
        org2_space.add_auditor(user)
      end

      it 'returns all spaces they are a space developer, space manager, or space auditor' do
        get :index

        expect(response.status).to eq(200)
        expect(parsed_body['resources'].map { |r| r['name'] }).to match_array([
          org1_space.name, org1_other_space.name, org2_space.name,
        ])
      end

      it 'eager loads associated resources that the presenter specifies' do
        expect(VCAP::CloudController::SpaceListFetcher).to receive(:fetch).with(
          hash_including(eager_loaded_associations: [:labels, :annotations, :organization])
        ).and_call_original

        get :index

        expect(response.status).to eq(200)
      end
    end

    describe 'filters' do
      context 'when the user has global read access' do
        before do
          allow_user_global_read_access(user)
        end

        describe 'names' do
          it 'returns the list of matching spaces' do
            get :index, params: { names: 'Alpaca,Horse' }

            expect(response.status).to eq(200)
            expect(parsed_body['resources'].map { |s| s['name'] }).to match_array([
              'Alpaca', 'Horse',
            ])
          end
        end

        describe 'guids' do
          it 'returns the list of matching spaces' do
            get :index, params: { guids: "#{org1_space.guid},#{org2_space.guid}" }

            expect(response.status).to eq(200)
            expect(parsed_body['resources'].map { |s| s['guid'] }).to match_array([
              org1_space.guid, org2_space.guid
            ])
          end
        end

        describe 'label_selectors' do
          context 'when there are label-selectors' do
            let(:params3) do
              { 'organization_guids' => org1.guid, 'label_selector' => 'jim' }
            end
            before do
              VCAP::CloudController::SpaceLabelModel.make(
                key_name: 'jim',
                value: 'stable',
                resource_guid: org1_space.guid
              )
              VCAP::CloudController::SpaceLabelModel.make(
                key_name: 'hambone',
                value: 'experimental',
                resource_guid: org1_other_space.guid
              )
            end

            it 'returns the list of matching spaces' do
              get :index, params: params3

              expect(response.status).to eq(200)
              expect(parsed_body['resources'].map { |s| s['guid'] }).to match_array([
                org1_space.guid
              ])
            end
          end
        end
      end

      context 'when the user does NOT have global read access' do
        before do
          org1.add_manager(user)
        end

        describe 'names' do
          it 'returns the list of matching spaces' do
            get :index, params: { names: 'Alpaca,Horse' }

            expect(response.status).to eq(200)
            expect(parsed_body['resources'].map { |s| s['name'] }).to match_array([
              'Alpaca',
            ])
          end

          describe 'guids' do
            it 'returns the list of readable matching spaces' do
              get :index, params: { guids: "#{org1_space.guid},#{org2_space.guid}" }

              expect(response.status).to eq(200)
              expect(parsed_body['resources'].map { |s| s['guid'] }).to match_array([
                org1_space.guid
              ])
            end
          end
        end
      end
    end

    describe 'order_by' do
      let!(:org1_space) do
        VCAP::CloudController::Space.make(
          name: 'Alpaca',
          organization: org1,
          created_at: Time.new(2017, 1, 3)
        )
      end
      let!(:org1_other_space) do
        VCAP::CloudController::Space.make(
          name: 'Lamb',
          organization: org1,
          created_at: Time.new(2017, 1, 2)
        )
      end
      let!(:org1_third_space) do
        VCAP::CloudController::Space.make(
          name: 'Dog',
          organization: org1,
          created_at: Time.new(2017, 1, 4)
        )
      end
      let!(:org2_space) do
        VCAP::CloudController::Space.make(
          name: 'Horse',
          organization: org2,
          created_at: Time.new(2017, 1, 1)
        )
      end

      before do
        allow_user_global_read_access(user)
      end

      context 'when name is specified' do
        it 'returns the spaces ordered by name in ascending order' do
          get :index, params: { order_by: 'name' }

          expect(response.status).to eq(200)

          expect(parsed_body['resources'].map { |s| s['name'] }).to eq([
            'Alpaca', 'Dog', 'Horse', 'Lamb'
          ])
        end

        it 'includes the name parameter in pagination links' do
          get :index, params: { order_by: 'name', per_page: 1, page: 2 }

          expect(parsed_body['pagination']['first']['href']).to eq("#{link_prefix}/v3/spaces?order_by=%2Bname&page=1&per_page=1")
          expect(parsed_body['pagination']['last']['href']).to eq("#{link_prefix}/v3/spaces?order_by=%2Bname&page=4&per_page=1")

          expect(parsed_body['pagination']['previous']['href']).to eq("#{link_prefix}/v3/spaces?order_by=%2Bname&page=1&per_page=1")
          expect(parsed_body['pagination']['next']['href']).to eq("#{link_prefix}/v3/spaces?order_by=%2Bname&page=3&per_page=1")
        end
      end

      context 'when -name is specified' do
        it 'returns the spaces ordered by name in descending order' do
          get :index, params: { order_by: '-name' }

          expect(response.status).to eq(200)

          expect(parsed_body['resources'].map { |s| s['name'] }).to eq([
            'Lamb', 'Horse', 'Dog', 'Alpaca'
          ])
        end

        it 'includes the -name parameter in pagination links' do
          get :index, params: { order_by: '-name', per_page: 1, page: 2 }

          expect(parsed_body['pagination']['first']['href']).to eq("#{link_prefix}/v3/spaces?order_by=-name&page=1&per_page=1")
          expect(parsed_body['pagination']['last']['href']).to eq("#{link_prefix}/v3/spaces?order_by=-name&page=4&per_page=1")
          expect(parsed_body['pagination']['previous']['href']).to eq("#{link_prefix}/v3/spaces?order_by=-name&page=1&per_page=1")
          expect(parsed_body['pagination']['next']['href']).to eq("#{link_prefix}/v3/spaces?order_by=-name&page=3&per_page=1")
        end
      end

      context 'when created_at is specified' do
        it 'returns the spaces ordered by created_at in ascending order' do
          get :index, params: { order_by: 'created_at' }

          expect(response.status).to eq(200)

          expect(parsed_body['resources'].map { |s| s['name'] }).to eq([
            'Horse', 'Lamb', 'Alpaca', 'Dog'
          ])
        end

        it 'includes the created_at parameter in pagination links' do
          get :index, params: { order_by: 'created_at', per_page: 1, page: 2 }

          expect(parsed_body['pagination']['first']['href']).to eq("#{link_prefix}/v3/spaces?order_by=%2Bcreated_at&page=1&per_page=1")
          expect(parsed_body['pagination']['last']['href']).to eq("#{link_prefix}/v3/spaces?order_by=%2Bcreated_at&page=4&per_page=1")
          expect(parsed_body['pagination']['previous']['href']).to eq("#{link_prefix}/v3/spaces?order_by=%2Bcreated_at&page=1&per_page=1")
          expect(parsed_body['pagination']['next']['href']).to eq("#{link_prefix}/v3/spaces?order_by=%2Bcreated_at&page=3&per_page=1")
        end
      end

      context 'when -created_at is specified' do
        it 'returns the spaces ordered by created_at in descending order' do
          get :index, params: { order_by: '-created_at' }

          expect(response.status).to eq(200)

          expect(parsed_body['resources'].map { |s| s['name'] }).to eq([
            'Dog', 'Alpaca', 'Lamb', 'Horse'
          ])
        end

        it 'includes the created_at parameter in pagination links' do
          get :index, params: { order_by: '-created_at', per_page: 1, page: 2 }

          expect(parsed_body['pagination']['first']['href']).to eq("#{link_prefix}/v3/spaces?order_by=-created_at&page=1&per_page=1")
          expect(parsed_body['pagination']['last']['href']).to eq("#{link_prefix}/v3/spaces?order_by=-created_at&page=4&per_page=1")
          expect(parsed_body['pagination']['previous']['href']).to eq("#{link_prefix}/v3/spaces?order_by=-created_at&page=1&per_page=1")
          expect(parsed_body['pagination']['next']['href']).to eq("#{link_prefix}/v3/spaces?order_by=-created_at&page=3&per_page=1")
        end
      end

      context 'when updated_at is specified' do
        it 'includes the updated_at parameter in pagination links' do
          get :index, params: { order_by: 'updated_at', per_page: 1, page: 2 }

          expect(parsed_body['pagination']['first']['href']).to eq("#{link_prefix}/v3/spaces?order_by=%2Bupdated_at&page=1&per_page=1")
          expect(parsed_body['pagination']['last']['href']).to eq("#{link_prefix}/v3/spaces?order_by=%2Bupdated_at&page=4&per_page=1")
          expect(parsed_body['pagination']['previous']['href']).to eq("#{link_prefix}/v3/spaces?order_by=%2Bupdated_at&page=1&per_page=1")
          expect(parsed_body['pagination']['next']['href']).to eq("#{link_prefix}/v3/spaces?order_by=%2Bupdated_at&page=3&per_page=1")
        end
      end

      context 'when -updated_at is specified' do
        it 'includes the updated_at parameter in pagination links' do
          get :index, params: { order_by: '-updated_at', per_page: 1, page: 2 }

          expect(parsed_body['pagination']['first']['href']).to eq("#{link_prefix}/v3/spaces?order_by=-updated_at&page=1&per_page=1")
          expect(parsed_body['pagination']['last']['href']).to eq("#{link_prefix}/v3/spaces?order_by=-updated_at&page=4&per_page=1")
          expect(parsed_body['pagination']['previous']['href']).to eq("#{link_prefix}/v3/spaces?order_by=-updated_at&page=1&per_page=1")
          expect(parsed_body['pagination']['next']['href']).to eq("#{link_prefix}/v3/spaces?order_by=-updated_at&page=3&per_page=1")
        end
      end

      context 'when a non-supported value is specified' do
        it 'returns the spaces ordered by updated_at in descending order' do
          get :index, params: { order_by: 'organization_guid' }

          expect(response.status).to eq(400)
          expect(response.body).to include 'BadQueryParameter'
          expect(response.body).to include("Order by can only be: 'created_at', 'updated_at', 'name'")
        end
      end
    end
  end

  describe '#create' do
    let(:user) { VCAP::CloudController::User.make }
    let(:user_without_role) { VCAP::CloudController::User.make }
    let(:org) { VCAP::CloudController::Organization.make }

    let(:name) { 'space1' }
    let(:org_guid) { org.guid }
    let(:req_body) do
      {
        name:          name,
        relationships: {
          organization: {
            data: { guid: org_guid }
          }
        }
      }
    end

    before do
      set_current_user_as_admin(user: user)
    end

    describe 'permissions by role' do
      role_to_expected_http_response = {
        'admin'               => 201,
        'org_manager'         => 201,
        'admin_read_only'     => 403,
        'org_auditor'         => 403,
        'org_billing_manager' => 403,
        'org_user'            => 403,
      }.freeze

      role_to_expected_http_response.each do |role, expected_return_value|
        context "as an #{role}" do
          it "returns #{expected_return_value}" do
            set_current_user_as_role(role: role, org: org, user: user)

            post :create, params: req_body, as: :json

            expect(response.status).to eq expected_return_value
          end
        end
      end
    end

    context 'when the organization does not exist' do
      let(:org_guid) { 'deception' }

      it 'returns a 422' do
        post :create, params: req_body, as: :json

        expect(response.status).to eq 422
        expect(response.body).to include 'UnprocessableEntity'
        expect(response.body).to include 'Invalid organization. Ensure the organization exists and you have access to it.'
      end
    end

    context 'when the user does not have read permission on the org' do
      it 'returns a 422' do
        set_current_user(user_without_role)
        post :create, params: req_body, as: :json

        expect(response.status).to eq 422
        expect(response.body).to include 'UnprocessableEntity'
        expect(response.body).to include 'Invalid organization. Ensure the organization exists and you have access to it.'
      end
    end

    context 'when the user has requested an invalid field' do
      it 'returns a 422 and a helpful error' do
        req_body[:invalid] = 'field'

        post :create, params: req_body, as: :json

        expect(response.status).to eq 422
        expect(response.body).to include 'UnprocessableEntity'
        expect(response.body).to include "Unknown field(s): 'invalid'"
      end
    end

    context 'when there is a message validation failure' do
      let(:name) { nil }

      it 'returns a 422 and a helpful error' do
        post :create, params: req_body, as: :json

        expect(response.status).to eq 422
        expect(response.body).to include 'UnprocessableEntity'
        expect(response.body).to include "Name can't be blank"
      end
    end

    context 'when there is a model validation failure' do
      let(:name) { 'not-unique' }

      before do
        VCAP::CloudController::Space.make name: name, organization: org
      end

      it 'returns a 422 and a helpful error' do
        post :create, params: req_body, as: :json

        expect(response.status).to eq 422
        expect(response.body).to include 'UnprocessableEntity'
        expect(response.body).to include 'Name must be unique'
      end
    end

    context 'when there is an invalid annotation' do
      let(:request_body) do
        {
          name:          name,
          relationships: {
            organization: {
              data: { guid: org_guid }
            }
          },
          metadata: {
            annotations: {
              key: 'big' * 5000
            }
          }
        }
      end

      it 'displays an informative error' do
        post :create, params: request_body, as: :json
        expect(response.status).to eq(422)
        expect(response).to have_error_message(/is greater than 5000 characters/)
      end
    end

    context 'when there are too many annotations' do
      let(:request_body) do
        {
          name:          name,
          relationships: {
            organization: {
              data: { guid: org_guid }
            }
          },
          metadata: {
            annotations: {
              radish: 'daikon',
              potato: 'idaho'
            }
          }
        }
      end

      before do
        VCAP::CloudController::Config.config.set(:max_annotations_per_resource, 1)
      end

      it 'fails with a 422' do
        post :create, params: request_body, as: :json
        expect(response.status).to eq(422)
        expect(response).to have_error_message(/exceed maximum of 1/)
      end
    end
  end

  describe '#patch' do
    let(:user) { set_current_user(VCAP::CloudController::User.make) }
    let!(:org) { VCAP::CloudController::Organization.make(name: 'Lyle\'s Farm') }
    let!(:space) { VCAP::CloudController::Space.make(name: 'Lamb', organization: org) }
    let(:labels) do
      {
        fruit: 'pineapple',
        truck: 'mazda5'
      }
    end
    let(:annotations) do
      {
        potato: 'yellow',
        beet: 'golden',
      }
    end
    let!(:update_message) do
      { name: 'Sheep',
        metadata: {
          labels: {
            fruit: 'passionfruit'
          },
          annotations: {
            potato: 'purple'
          }
        }
      }
    end
    before do
      VCAP::CloudController::LabelsUpdate.update(space, labels, VCAP::CloudController::SpaceLabelModel)
      VCAP::CloudController::AnnotationsUpdate.update(space, annotations, VCAP::CloudController::SpaceAnnotationModel)
    end

    context 'when the user is an admin' do
      before do
        set_current_user_as_admin
      end

      it 'updates the space' do
        patch :update, params: { guid: space.guid }.merge(update_message), as: :json

        expect(response.status).to eq(200)
        expect(parsed_body['name']).to eq('Sheep')
        expect(parsed_body['metadata']['labels']).to eq({ 'fruit' => 'passionfruit', 'truck' => 'mazda5' })
        expect(parsed_body['metadata']['annotations']).to eq({ 'potato' => 'purple', 'beet' => 'golden' })

        space.reload
        expect(space.name).to eq('Sheep')
        expect(space).to have_labels({ key: 'fruit', value: 'passionfruit' }, { key: 'truck', value: 'mazda5' })
        expect(space).to have_annotations({ key: 'potato', value: 'purple' }, { key: 'beet', value: 'golden' })
      end

      context 'when a label is deleted' do
        let(:request_body) do
          {
            metadata: {
              labels: {
                fruit: nil
              }
            }
          }
        end

        it 'succeeds' do
          patch :update, params: { guid: space.guid }.merge(request_body), as: :json

          expect(response.status).to eq(200)
          expect(parsed_body['metadata']['labels']).to eq({ 'truck' => 'mazda5' })

          space.reload
          expect(space).to have_labels({ key: 'truck', value: 'mazda5' })
        end
      end
      context 'when an empty request is sent' do
        let(:request_body) do
          {}
        end

        it 'succeeds' do
          patch :update, params: { guid: space.guid }.merge(request_body), as: :json
          expect(response.status).to eq(200)
          space.reload
          expect(space.name).to eq('Lamb')
          expect(parsed_body['name']).to eq('Lamb')
          expect(parsed_body['guid']).to eq(space.guid)
        end
      end

      context 'when the message is invalid' do
        before do
          set_current_user_as_admin
        end
        let!(:update_message) { { name: 'Sheep', animals: 'Cows' } }

        it 'fails' do
          patch :update, params: { guid: space.guid }.merge(update_message), as: :json
          expect(response.status).to eq(422)
        end
      end

      context 'when there is no such space' do
        before do
          set_current_user_as_admin
        end

        it 'fails' do
          patch :update, params: { guid: "Greg's missing space" }.merge(update_message), as: :json

          expect(response.status).to eq(404)
        end
      end

      context 'when there is a valid label (but no name)' do
        let(:request_body) do
          {
            metadata: {
              labels: {
                key: 'value'
              }
            }
          }
        end

        it 'updates the metadata' do
          patch :update, params: { guid: space.guid }.merge(request_body), as: :json
          expect(response.status).to eq(200)
          expect(parsed_body['metadata']['labels']['key']).to eq 'value'
        end
      end

      context 'when there is an invalid label' do
        let(:request_body) do
          {
            metadata: {
              labels: {
                'cloudfoundry.org/label': 'value'
              }
            }
          }
        end

        it 'displays an informative error' do
          patch :update, params: { guid: space.guid }.merge(request_body), as: :json
          expect(response.status).to eq(422)
          expect(response).to have_error_message('label key error')
        end
      end

      context 'when there is an invalid annotation' do
        let(:request_body) do
          {
            metadata: {
              annotations: {
                key: 'big' * 5000
              }
            }
          }
        end

        it 'displays an informative error' do
          patch :update, params: { guid: space.guid }.merge(request_body), as: :json
          expect(response.status).to eq(422)
          expect(response).to have_error_message(/is greater than 5000 characters/)
        end
      end

      context 'when there are too many annotations' do
        let(:request_body) do
          {
            metadata: {
              annotations: {
                radish: 'daikon',
                potato: 'idaho'
              }
            }
          }
        end

        before do
          VCAP::CloudController::Config.config.set(:max_annotations_per_resource, 2)
        end

        it 'fails with a 422' do
          patch :update, params: { guid: space.guid }.merge(request_body), as: :json
          expect(response.status).to eq(422)
          expect(response).to have_error_message(/exceed maximum of 2/)
        end
      end

      context 'when an annotation is deleted' do
        let(:request_body) do
          {
            metadata: {
              annotations: {
                potato: nil
              }
            }
          }
        end

        it 'succeeds' do
          patch :update, params: { guid: space.guid }.merge(request_body), as: :json

          expect(response.status).to eq(200)
          expect(parsed_body['metadata']['annotations']).to eq({ 'beet' => 'golden' })

          space.reload
          expect(space).to have_annotations({ key: 'beet', value: 'golden' })
        end
      end
    end

    describe 'authorization' do
      it_behaves_like 'permissions endpoint' do
        let(:roles_to_http_responses) do
          {
            'admin' => 200,
            'admin_read_only' => 403,
            'global_auditor' => 403,
            'space_developer' => 403,
            'space_manager' => 200,
            'space_auditor' => 403,
            'org_manager' => 200,
            'org_auditor' => 404,
            'org_billing_manager' => 404,
          }
        end
        let(:api_call) { lambda { patch :update, params: { guid: space.guid }.merge(update_message), as: :json } }
      end
    end
  end

  describe '#update_isolation_segment' do
    let(:user) { set_current_user(VCAP::CloudController::User.make) }

    let!(:org1) { VCAP::CloudController::Organization.make(name: 'Lyle\'s Farm') }
    let!(:org2) { VCAP::CloudController::Organization.make(name: 'Greg\'s Ranch') }
    let!(:space1) { VCAP::CloudController::Space.make(name: 'Lamb', organization: org1) }
    let!(:space2) { VCAP::CloudController::Space.make(name: 'Alpaca', organization: org1) }
    let!(:space3) { VCAP::CloudController::Space.make(name: 'Horse', organization: org2) }
    let!(:space4) { VCAP::CloudController::Space.make(name: 'Buffalo') }
    let!(:isolation_segment_model) { VCAP::CloudController::IsolationSegmentModel.make }
    let!(:update_message) { { 'data' => { 'guid' => isolation_segment_model.guid } } }
    let(:assigner) { VCAP::CloudController::IsolationSegmentAssign.new }

    context 'when the user is an admin' do
      before do
        set_current_user_as_admin
      end

      context 'when the org has been entitled with the isolation segment' do
        before do
          assigner.assign(isolation_segment_model, [org1])
        end

        it 'can assign an isolation segment to a space in org1' do
          patch :update_isolation_segment, params: { guid: space1.guid }.merge(update_message), as: :json

          expect(response.status).to eq(200)
          space1.reload
          expect(space1.isolation_segment_guid).to eq(isolation_segment_model.guid)
          expect(parsed_body['data']['guid']).to eq(isolation_segment_model.guid)
          expect(parsed_body['links']['self']['href']).to include("v3/spaces/#{space1.guid}/relationships/isolation_segment")
        end

        it 'can remove an isolation segment from a space' do
          space1.update(isolation_segment_guid: isolation_segment_model.guid)
          space1.reload
          expect(space1.isolation_segment_guid).to eq(isolation_segment_model.guid)

          patch :update_isolation_segment, params: { guid: space1.guid, data: nil }, as: :json
          expect(response.status).to eq(200)
          space1.reload
          expect(space1.isolation_segment_guid).to eq(nil)
          expect(parsed_body['links']['self']['href']).to include("v3/spaces/#{space1.guid}/relationships/isolation_segment")
        end
      end

      context 'when the org has not been entitled with the isolation segment' do
        it 'will not assign an isolation segment to a space in a different org' do
          patch :update_isolation_segment, params: { guid: space3.guid }.merge(update_message), as: :json

          expect(response.status).to eq(422)
          expect(response.body).to include(
            "Unable to assign isolation segment with guid '#{isolation_segment_model.guid}'. Ensure it has been entitled to the organization that this space belongs to."
          )
        end
      end

      context 'when the isolation segment cannot be found' do
        let!(:update_message) { { 'data' => { 'guid' => 'potato' } } }

        it 'raises an error' do
          patch :update_isolation_segment, params: { guid: space1.guid }.merge(update_message), as: :json

          expect(response.status).to eq(422)
          expect(response.body).to include(
            "Unable to assign isolation segment with guid 'potato'. Ensure it has been entitled to the organization that this space belongs to."
          )
        end
      end
    end

    context 'permissions' do
      context 'when the user does not have permissions to read from the space' do
        before do
          allow_user_read_access_for(user, orgs: [], spaces: [])
        end

        it 'throws ResourceNotFound error' do
          patch :update_isolation_segment, params: { guid: space1.guid }.merge(update_message), as: :json

          expect(response.status).to eq(404)
          expect(response.body).to include 'ResourceNotFound'
          expect(response.body).to include 'Space not found'
        end
      end

      context 'when the user is an org manager' do
        before do
          assigner.assign(isolation_segment_model, [org1])
          org1.add_manager(user)
        end

        it 'returns a successful response' do
          patch :update_isolation_segment, params: { guid: space1.guid }.merge(update_message), as: :json

          expect(response.status).to eq(200)
        end
      end

      context 'when the user is not an org manager' do
        before do
          allow_user_read_access_for(user, orgs: [org1], spaces: [space1])
        end

        it 'returns an Unauthorized error' do
          patch :update_isolation_segment, params: { guid: space1.guid }.merge(update_message), as: :json

          expect(response.status).to eq(403)
          expect(response.body).to include 'NotAuthorized'
        end
      end
    end
  end

  describe '#show_isolation_segment' do
    let(:user) { set_current_user(VCAP::CloudController::User.make) }

    let!(:org) { VCAP::CloudController::Organization.make(name: 'Lyle\'s Farm') }
    let!(:space) { VCAP::CloudController::Space.make(name: 'Lamb', organization: org) }
    let!(:isolation_segment_model) { VCAP::CloudController::IsolationSegmentModel.make }
    let(:assigner) { VCAP::CloudController::IsolationSegmentAssign.new }

    context 'when the user has permissions to read from the space' do
      before do
        allow_user_read_access_for(user, orgs: [org], spaces: [space])
        assigner.assign(isolation_segment_model, [org])
        space.update(isolation_segment_guid: isolation_segment_model.guid)
      end

      it 'returns a 200 and the isolation segment associated with the space' do
        get :show_isolation_segment, params: { guid: space.guid }

        expect(response.status).to eq(200)
        expect(parsed_body['data']['guid']).to eq(isolation_segment_model.guid)
      end

      context 'when the space does not exist' do
        it 'returns a 404' do
          get :show_isolation_segment, params: { guid: 'potato' }

          expect(response.status).to eq(404)
          expect(response.body).to include('Space not found')
        end
      end

      context 'when the space is not associated with an isolation segment' do
        before { space.update(isolation_segment_guid: nil) }

        it 'returns a 200' do
          get :show_isolation_segment, params: { guid: space.guid }

          expect(response.status).to eq(200)
          expect(parsed_body['data']).to eq(nil)
        end
      end
    end

    context 'when the user does not have permissions to read from the space' do
      before { allow_user_read_access_for(user, orgs: [], spaces: []) }

      it 'throws ResourceNotFound error' do
        get :show_isolation_segment, params: { guid: space.guid }

        expect(response.status).to eq(404)
        expect(response.body).to include 'ResourceNotFound'
        expect(response.body).to include 'Space not found'
      end
    end
  end
end
