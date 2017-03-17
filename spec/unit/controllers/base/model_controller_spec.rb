require 'spec_helper'
require 'stringio'

module VCAP::CloudController
  RSpec.describe RestController::ModelController do
    let(:user) { User.make(active: true) }

    describe '#validate_access' do
      let(:access_context) { Security::AccessContext.new }
      let(:obj) { double('test object') }
      let(:fields) { { 'key' => 1 } }

      before do
        allow(Security::AccessContext).to receive(:new).and_return(access_context)

        dep = { object_renderer: nil, collection_renderer: nil }
        @model_controller = RestController::ModelController.new(
          nil, FakeLogger.new([]), {}, {}, nil, nil, dep
        )
      end

      it 'checks if you can access an object' do
        expect(access_context).to receive(:cannot?).with(:read_for_update_with_token, obj).ordered.and_return(false)
        expect(access_context).to receive(:cannot?).with(:read_for_update, obj, fields).ordered.and_return(false)
        @model_controller.validate_access(:read_for_update, obj, fields)

        expect(access_context).to receive(:cannot?).with(:update_with_token, obj).ordered.and_return(false)
        expect(access_context).to receive(:cannot?).with(:update, obj, fields).ordered.and_return(false)
        @model_controller.validate_access(:update, obj, fields)
      end

      context 'raises an error when it fails' do
        it 'on operation_with_token' do
          expect(access_context).to receive(:cannot?).with(:read_for_update_with_token, obj).ordered.and_return(true)
          expect { @model_controller.validate_access(:read_for_update, obj) }.to raise_error CloudController::Errors::ApiError

          expect(access_context).to receive(:cannot?).with(:update_with_token, obj).ordered.and_return(true)
          expect { @model_controller.validate_access(:update, obj) }.to raise_error CloudController::Errors::ApiError
        end

        it 'on operation' do
          expect(access_context).to receive(:cannot?).with(:read_for_update_with_token, obj).ordered.and_return(false)
          expect(access_context).to receive(:cannot?).with(:read_for_update, obj, fields).ordered.and_return(true)
          expect { @model_controller.validate_access(:read_for_update, obj, fields) }.to raise_error CloudController::Errors::ApiError

          expect(access_context).to receive(:cannot?).with(:update_with_token, obj).ordered.and_return(false)
          expect(access_context).to receive(:cannot?).with(:update, obj, fields).ordered.and_return(true)
          expect { @model_controller.validate_access(:update, obj, fields) }.to raise_error CloudController::Errors::ApiError
        end
      end
    end

    describe 'common model controller behavior' do
      context 'for an existing user' do
        it 'succeeds' do
          set_current_user(user)
          get '/v2/test_models'
          expect(last_response.status).to eq(200)
        end
      end

      context 'for a user not yet in cloud controller' do
        it 'succeeds' do
          set_current_user(User.new)
          get '/v2/test_models'
          expect(last_response.status).to eq(200)
        end
      end

      context 'for a deleted user' do
        it 'returns 200 by recreating the user' do
          set_current_user(user)
          user.delete
          get '/v2/test_models'
          expect(last_response.status).to eq(200)
        end
      end

      context 'for an admin' do
        it 'succeeds' do
          set_current_user_as_admin
          get '/v2/test_models'
          expect(last_response.status).to eq(200)
        end
      end

      context 'for no user' do
        it 'should return 401' do
          set_current_user(nil)
          get '/v2/test_models'
          expect(last_response.status).to eq(401)
        end
      end
    end

    describe '#create' do
      it 'calls the hooks in the right order' do
        calls = []

        expect_any_instance_of(TestModelsController).to receive(:before_create).with(no_args) do
          calls << :before_create
        end

        expect(TestModel).to receive(:create_from_hash) {
          calls << :create_from_hash
          TestModel.make
        }

        expect_any_instance_of(TestModelsController).to receive(:after_create).with(instance_of(TestModel)) do
          calls << :after_create
        end

        set_current_user_as_admin
        post '/v2/test_models', MultiJson.dump({ required_attr: true, unique_value: 'foobar' })

        expect(calls).to eq([:before_create, :create_from_hash, :after_create])
      end

      context "when the user's token is missing the required scope" do
        it 'responds with a 403 Insufficient Scope' do
          set_current_user(user, scopes: ['bogus.scope'])
          post '/v2/test_models', MultiJson.dump({ required_attr: true, unique_value: 'foobar' })
          expect(decoded_response['code']).to eq(10007)
          expect(decoded_response['description']).to match(/lacks the necessary scopes/)
        end
      end

      it 'does not persist the model when validate access fails' do
        set_current_user(user)
        expect {
          post '/v2/test_models', MultiJson.dump({ required_attr: true, unique_value: 'foobar' })
        }.to_not change { TestModel.count }

        expect(decoded_response['code']).to eq(10003)
        expect(decoded_response['description']).to match(/not authorized/)
      end

      it 'returns the right values on a successful create' do
        set_current_user_as_admin
        post '/v2/test_models', MultiJson.dump({ required_attr: true, unique_value: 'foobar' })
        model_instance = TestModel.first
        url = "/v2/test_models/#{model_instance.guid}"

        expect(last_response.status).to eq(201)
        expect(last_response.location).to eq(url)
        expect(decoded_response['metadata']['url']).to eq(url)
        expect(decoded_response['entity']['unique_value']).to eq('foobar')
      end

      it 'allows extra fields to be included' do
        set_current_user_as_admin
        post '/v2/test_models', MultiJson.dump({ extra_field: true, required_attr: true, unique_value: 'foobar' })

        expect(last_response.status).to eq(201)
      end

      context 'with attributes for redacting' do
        # TODO: MSSQL blows up with a syntax error when saving nested hashes, but Postgres silently fails as well.
        # MSSQL: TinyTds::Error: Incorrect syntax near '='.
        # Postgres: UPDATE "test_model_redacts" SET "guid" = 'c90704d5-c321-4cc4-be46-c8517a1cb963', "redacted" = ('secret' = 'super secret data');
        #           The part in the parens is treated as a boolean comparison and the string "false" is set for "redacted"
        # let(:request_attributes) { { redacted: { secret: 'super secret data' } } }
        # let(:redact_request_attributes) { { 'redacted' => { 'secret' => 'super secret data' } } }
        let(:request_attributes) { { redacted: 'super secret data' } }
        let(:redact_request_attributes) { { 'redacted' => 'super secret data' } }

        it 'attempts to redact the attributes' do
          set_current_user_as_admin
          expect_any_instance_of(TestModelRedactController).to receive(:redact_attributes).with(:create, redact_request_attributes)

          post '/v2/test_model_redact', MultiJson.dump(request_attributes)
          expect(last_response.status).to eq(201), "Response: #{last_response.body}"
        end
      end

      context 'with empty attributes for redacting' do
        let(:request_attributes) { { redacted: '' } }
        let(:redact_request_attributes) { { 'redacted' => '' } }

        it 'attempts to redact the attributes' do
          expect(TestModelRedact).to receive(:create_from_hash) { TestModelRedact.make }
          expect_any_instance_of(TestModelRedactController).to receive(:redact_attributes).with(:create, redact_request_attributes)

          set_current_user_as_admin
          post '/v2/test_model_redact', MultiJson.dump(request_attributes)

          expect(last_response.status).to eq(201)
        end
      end
    end

    describe '#read' do
      context 'when the guid matches a record' do
        let!(:model) { TestModel.make }

        it 'returns not authorized if user does not have access' do
          set_current_user(user)
          get "/v2/test_models/#{model.guid}"

          expect(decoded_response['code']).to eq(10003)
          expect(decoded_response['description']).to match(/not authorized/)
        end

        it 'returns the serialized object if access is validated' do
          expect_any_instance_of(RestController::ObjectRenderer).
            to receive(:render_json).
            with(TestModelsController, model, {}).
            and_return('serialized json')

          set_current_user_as_admin
          get "/v2/test_models/#{model.guid}"

          expect(last_response.body).to eq('serialized json')
        end
      end
    end

    describe '#update' do
      let!(:model) { TestModel.make }
      let(:fields) { { 'unique_value' => 'something' } }

      before { set_current_user_as_admin }

      it 'updates the data' do
        put "/v2/test_models/#{model.guid}", MultiJson.dump({ unique_value: 'new value' })

        expect(last_response.status).to eq(201)
        model.reload
        expect(model.unique_value).to eq('new value')
        expect(decoded_response['entity']['unique_value']).to eq('new value')
      end

      it 'returns the serialized updated object on success' do
        expect_any_instance_of(RestController::ObjectRenderer).
          to receive(:render_json).
          with(TestModelsController, instance_of(TestModel), {}).
          and_return('serialized json')

        put "/v2/test_models/#{model.guid}", MultiJson.dump({})

        expect(last_response.body).to eq('serialized json')
      end

      it 'returns not authorized if the user does not have access ' do
        set_current_user(user)
        put "/v2/test_models/#{model.guid}", MultiJson.dump(fields)

        expect(model.reload.unique_value).not_to eq('something')
        expect(decoded_response['code']).to eq(10003)
        expect(decoded_response['description']).to match(/not authorized/)
      end

      it 'prevents other processes from updating the same row until the transaction finishes' do
        allow(TestModel).to receive(:find).with(guid: model.guid).and_return(model)
        expect(model).to receive(:lock!).ordered
        expect(model).to receive(:update_from_hash).ordered.and_call_original

        put "/v2/test_models/#{model.guid}", MultiJson.dump(fields)
      end

      it 'calls the hooks in the right order' do
        calls = []

        expect_any_instance_of(TestModelsController).to receive(:before_update).with(model) do
          calls << :before_update
        end

        expect_any_instance_of(TestModelsController).to receive(:validate_access).with(:read_for_update, model, fields) {
          calls << :read_for_update
        }

        expect_any_instance_of(TestModel).to receive(:update_from_hash) do
          calls << :update_from_hash
          model
        end

        expect_any_instance_of(TestModelsController).to receive(:validate_access).with(:update, model, fields) {
          calls << :update
        }

        expect_any_instance_of(TestModelsController).to receive(:after_update).with(instance_of(TestModel)) do
          calls << :after_update
        end

        put "/v2/test_models/#{model.guid}", MultiJson.dump(fields)
        expect(calls).to eq([:before_update, :read_for_update, :update_from_hash, :update, :after_update])
      end

      context 'with attributes for redacting' do
        let!(:model) { TestModelRedact.make }
        # TODO: MSSQL blows up with a syntax error when saving nested hashes, but Postgres silently fails as well.
        # MSSQL: TinyTds::Error: Incorrect syntax near '='.
        # Postgres: UPDATE "test_model_redacts" SET "guid" = 'c90704d5-c321-4cc4-be46-c8517a1cb963', "redacted" = ('secret' = 'super secret data');
        #           The part in the parens is treated as a boolean comparison and the string "false" is set for "redacted"
        # let(:request_attributes) { { redacted: { secret: 'super secret data' } } }
        # let(:redact_request_attributes) { { 'redacted' => { 'secret' => 'super secret data' } } }
        let(:request_attributes) { { redacted: 'super secret data' } }
        let(:redact_request_attributes) { { 'redacted' => 'super secret data' } }

        it 'attempts to redact the attributes' do
          expect_any_instance_of(TestModelRedactController).to receive(:redact_attributes).with(:update, redact_request_attributes)

          put "/v2/test_model_redact/#{model.guid}", MultiJson.dump(request_attributes)
          expect(last_response.status).to eq(201), "Response Body #{last_response.body}"
        end
      end
    end

    describe '#delete' do
      let!(:model) { TestModel.make }
      let(:params) { {} }

      before { set_current_user_as_admin }

      def query_params
        params.to_a.collect { |pair| pair.join('=') }.join('&')
      end

      shared_examples 'tests with associations' do
        context 'with associated models' do
          let(:test_model_nullify_dep) { TestModelNullifyDep.create }

          before do
            model.add_test_model_destroy_dep TestModelDestroyDep.create
            model.add_test_model_nullify_dep test_model_nullify_dep
          end

          context 'when deleting with recursive set to true' do
            def run_delayed_job
              Delayed::Worker.new.work_off if Delayed::Job.last
            end

            before { params.merge!('recursive' => 'true') }

            it 'successfully deletes' do
              expect {
                delete "/v2/test_models/#{model.guid}?#{query_params}"
                run_delayed_job
              }.to change {
                TestModel.count
              }.by(-1)
            end

            it 'successfully deletes association marked for destroy' do
              expect {
                delete "/v2/test_models/#{model.guid}?#{query_params}"
                run_delayed_job
              }.to change {
                TestModelDestroyDep.count
              }.by(-1)
            end

            it 'successfully nullifies association marked for nullify' do
              expect {
                delete "/v2/test_models/#{model.guid}?#{query_params}"
                run_delayed_job
              }.to change {
                test_model_nullify_dep.reload.test_model_id
              }.from(model.id).to(nil)
            end
          end

          context 'when deleting non-recursively' do
            it 'raises an association error' do
              delete "/v2/test_models/#{model.guid}?#{query_params}"
              expect(last_response.status).to eq(400)
              expect(decoded_response['code']).to eq(10006)
              expect(decoded_response['description']).to match(/associations/)
            end
          end
        end
      end

      context 'when sync' do
        it 'deletes the object' do
          expect {
            delete "/v2/test_models/#{model.guid}?#{query_params}"
          }.to change {
            TestModel.count
          }.by(-1)

          expect(last_response.status).to eq(204)
          expect(last_response.body).to eq('')
        end

        include_examples 'tests with associations'
      end

      context 'when async=true' do
        let(:params) { { 'async' => 'true' } }

        context 'and using the job enqueuer' do
          let(:job) { double(Jobs::Runtime::ModelDeletion) }
          let(:enqueuer) { double(Jobs::Enqueuer) }
          let(:presenter) { double(JobPresenter) }

          it 'returns a 202 with the job information' do
            delete "/v2/test_models/#{model.guid}?#{query_params}"

            expect(last_response.status).to eq(202)
            job_id = decoded_response['entity']['guid']
            expect(Delayed::Job.where(guid: job_id).first).to exist
          end
        end

        include_examples 'tests with associations'
      end
    end

    describe '#enumerate' do
      let(:timestamp) { Time.now.utc.change(usec: 0) }
      let!(:model1) { TestModel.make(created_at: timestamp, sortable_value: 'zelda') }
      let!(:model2) { TestModel.make(created_at: timestamp + 1.second, sortable_value: 'artichoke') }
      let!(:model3) { TestModel.make(created_at: timestamp + 2.seconds, sortable_value: 'marigold') }

      before { set_current_user_as_admin }

      it 'paginates the dataset with query params' do
        expect_any_instance_of(TestModelsController).to receive(:validate_access).with(:index, TestModel)
        expect_any_instance_of(RestController::PaginatedCollectionRenderer).
          to receive(:render_json).with(
            TestModelsController,
            anything,
            anything,
            anything,
            anything,
          ).and_call_original

        get '/v2/test_models'
        expect(last_response.status).to eq(200)
        expect(decoded_response['total_results']).to eq(3)
      end

      it 'returns the first page' do
        get '/v2/test_models?results-per-page=2'

        expect(last_response.status).to eq(200)
        expect(decoded_response['total_results']).to eq(3)
        expect(decoded_response).to have_key('prev_url')
        expect(decoded_response['prev_url']).to be_nil
        expect(decoded_response['next_url']).to include('page=2&results-per-page=2')
        found_guids = decoded_response['resources'].collect { |resource| resource['metadata']['guid'] }
        expect(found_guids).to match_array([model1.guid, model2.guid])
      end

      it 'returns other pages when requested' do
        get '/v2/test_models?page=2&results-per-page=2'

        expect(last_response.status).to eq(200)
        expect(decoded_response['total_results']).to eq(3)
        expect(decoded_response['prev_url']).to include('page=1&results-per-page=2')
        expect(decoded_response).to have_key('next_url')
        expect(decoded_response['next_url']).to be_nil
        found_guids = decoded_response['resources'].collect { |resource| resource['metadata']['guid'] }
        expect(found_guids).to match_array([model3.guid])
      end

      describe 'using query parameters' do
        it 'returns matching results when querying for equality' do
          found_model = TestModel.make(unique_value: 'value1')
          TestModel.make(unique_value: 'value2')

          get '/v2/test_models?q=unique_value:value1'

          expect(decoded_response['total_results']).to eq(1)
          expect(decoded_response['resources'][0]['metadata']['guid']).to eq(found_model.guid)
        end

        it 'returns matching results when querying for greater than or equal' do
          get escape_query("/v2/test_models?q=created_at>=#{model2.created_at.utc.iso8601}")

          expect(decoded_response['total_results']).to eq(2)
          found_guids = decoded_response['resources'].collect { |resource| resource['metadata']['guid'] }
          expect(found_guids).to eq([model2.guid, model3.guid])
        end

        it 'returns matching results when querying for less than or equal' do
          get escape_query("/v2/test_models?q=created_at<=#{model2.created_at.utc.iso8601}")

          expect(decoded_response['total_results']).to eq(2)
          found_guids = decoded_response['resources'].collect { |resource| resource['metadata']['guid'] }
          expect(found_guids).to eq([model1.guid, model2.guid])
        end

        it 'returns matching results when querying for greater than' do
          get escape_query("/v2/test_models?q=created_at>#{model2.created_at.utc.iso8601}")

          expect(decoded_response['total_results']).to eq(1)
          expect(decoded_response['resources'][0]['metadata']['guid']).to eq(model3.guid)
        end

        it 'returns matching results when querying for less than' do
          get escape_query("/v2/test_models?q=created_at<#{model2.created_at.utc.iso8601}")

          expect(decoded_response['total_results']).to eq(1)
          expect(decoded_response['resources'][0]['metadata']['guid']).to eq(model1.guid)
        end

        it 'returns matching results when querying using IN' do
          get escape_query("/v2/test_models?q=created_at IN #{model1.created_at.utc.iso8601},#{model3.created_at.utc.iso8601}")

          expect(decoded_response['total_results']).to eq(2)
          found_guids = decoded_response['resources'].collect { |resource| resource['metadata']['guid'] }
          expect(found_guids).to eq([model1.guid, model3.guid])
        end

        it 'returns matching results when querying by multiple conditions' do
          get escape_query("/v2/test_models?q=created_at<#{model3.created_at.utc.iso8601}\;created_at>#{model1.created_at.utc.iso8601}")

          expect(decoded_response['total_results']).to eq(1)
          expect(decoded_response['resources'][0]['metadata']['guid']).to eq(model2.guid)
        end

        it 'returns matching results when querying with multiple parameters' do
          get escape_query("/v2/test_models?q=created_at<#{model3.created_at.utc.iso8601}&q=created_at>#{model1.created_at.utc.iso8601}")

          expect(decoded_response['total_results']).to eq(1)
          expect(decoded_response['resources'][0]['metadata']['guid']).to eq(model2.guid)
        end
      end

      describe 'ordering by specific columns' do
        it 'can order by approved columns' do
          get '/v2/test_models?order-by=sortable_value'

          expect(last_response.status).to eq(200)
          sorted_values = decoded_response['resources'].map { |r| r['entity']['sortable_value'] }
          expect(sorted_values).to eq(['artichoke', 'marigold', 'zelda'])
        end

        it 'fails when trying to order by unapproved columns' do
          get '/v2/test_models?order-by=nonsortable_value'

          expect(last_response.status).to eq(500)
          expect(last_response.body).to match /Cannot order/
          expect(last_response.body).to match /nonsortable_value/
        end
      end
    end

    describe 'error handling' do
      describe '404' do
        before do
          CloudController::Errors::Details::HARD_CODED_DETAILS['TestModelNotFound'] = {
            'code' => 999999999,
            'http_code' => 404,
            'message' => 'Test Model Not Found',
          }
          set_current_user_as_admin
        end

        it 'returns not found for reads' do
          get '/v2/test_models/99999'
          expect(last_response.status).to eq(404)
          expect(decoded_response['code']).to eq 999999999
          expect(decoded_response['description']).to match(/Test Model Not Found/)
        end

        it 'returns not found for updates' do
          put '/v2/test_models/99999', '{}'
          expect(last_response.status).to eq(404)
          expect(decoded_response['code']).to eq 999999999
          expect(decoded_response['description']).to match(/Test Model Not Found/)
        end

        it 'returns not found for deletes' do
          delete '/v2/test_models/99999'
          expect(last_response.status).to eq(404)
          expect(decoded_response['code']).to eq 999999999
          expect(decoded_response['description']).to match(/Test Model Not Found/)
        end
      end

      describe 'model errors' do
        before do
          CloudController::Errors::Details::HARD_CODED_DETAILS['TestModelValidation'] = {
            'code' => 999999998,
            'http_code' => 400,
            'message' => 'Validation Error',
          }
          set_current_user_as_admin
        end

        it 'returns 400 error for missing attributes; returns a request-id and no location' do
          post '/v2/test_models', '{}'
          expect(last_response.status).to eq(400)
          expect(decoded_response['code']).to eq 1001
          expect(decoded_response['description']).to match(/invalid/)
          expect(last_response.location).to be_nil
        end

        it 'returns 400 error when validation fails on create' do
          TestModel.make(unique_value: 'unique')
          post '/v2/test_models', MultiJson.dump({ required_attr: true, unique_value: 'unique' })
          expect(last_response.status).to eq(400)
          expect(decoded_response['code']).to eq 999999998
          expect(decoded_response['description']).to match(/Validation Error/)
        end

        it 'returns 400 error when validation fails on update' do
          TestModel.make(unique_value: 'unique')
          test_model = TestModel.make(unique_value: 'not-unique')
          put "/v2/test_models/#{test_model.guid}", MultiJson.dump({ unique_value: 'unique' })
          expect(last_response.status).to eq(400)
          expect(decoded_response['code']).to eq 999999998
          expect(decoded_response['description']).to match(/Validation Error/)
        end
      end
    end

    describe 'associated collections' do
      before { set_current_user_as_admin }

      describe 'permissions' do
        let(:model) { TestModel.make }
        let(:associated_model1) { TestModelManyToOne.make }
        let(:associated_model2) { TestModelManyToOne.make(test_model: model) }

        context 'when adding an associated object' do
          it 'succeeds when user has access to both objects' do
            put "/v2/test_models/#{model.guid}/test_model_many_to_ones/#{associated_model1.guid}", '{}'

            expect(last_response.status).to eq(201)
            model.reload
            expect(model.test_model_many_to_ones).to include(associated_model1)
          end
        end

        context 'when removing an associated object' do
          it 'succeeds when user has access to both objects in the association' do
            associated_model2.save
            expect(model.test_model_many_to_ones).to_not be_empty

            delete "/v2/test_models/#{model.guid}/test_model_many_to_ones/#{associated_model2.guid}", '{}'

            expect(last_response.status).to eq(204)
            model.reload
            expect(model.test_model_many_to_ones).to be_empty
          end
        end

        context 'user does not have access to the root association' do
          context 'because read_for_update? denies access' do
            it 'fails' do
              expect_any_instance_of(TestModelAccess).to receive(:read_for_update?).with(
                instance_of(TestModel), {
                'test_model_many_to_one' => associated_model1.guid,
                verb: 'add',
                relation: :test_model_many_to_ones,
                related_guid: associated_model1.guid
              }).and_return(false)

              put "/v2/test_models/#{model.guid}/test_model_many_to_ones/#{associated_model1.guid}", '{}'

              expect(last_response.status).to eq(403)
              model.reload
              expect(model.test_model_many_to_ones).to_not include(associated_model1)
            end
          end
        end
      end

      describe 'to_many' do
        let(:model) { TestModel.make }
        let(:associated_model1) { TestModelManyToMany.make }
        let(:associated_model2) { TestModelManyToMany.make }

        describe 'update' do
          it 'allows associating nested models' do
            put "/v2/test_models/#{model.guid}", MultiJson.dump({ test_model_many_to_many_guids: [associated_model1.guid, associated_model2.guid] })
            expect(last_response.status).to eq(201)
            model.reload
            expect(model.test_model_many_to_manies).to include(associated_model1)
            expect(model.test_model_many_to_manies).to include(associated_model2)
          end

          context 'with existing models in the association' do
            before { model.add_test_model_many_to_many(associated_model1) }

            it 'replaces existing associated models' do
              put "/v2/test_models/#{model.guid}", MultiJson.dump({ test_model_many_to_many_guids: [associated_model2.guid] })
              expect(last_response.status).to eq(201)
              model.reload
              expect(model.test_model_many_to_manies).not_to include(associated_model1)
              expect(model.test_model_many_to_manies).to include(associated_model2)
            end

            it 'removes associated models when empty array is provided' do
              put "/v2/test_models/#{model.guid}", MultiJson.dump({ test_model_many_to_many_guids: [] })
              expect(last_response.status).to eq(201)
              model.reload
              expect(model.test_model_many_to_manies).not_to include(associated_model1)
            end

            it 'fails invalid guids' do
              put "/v2/test_models/#{model.guid}", MultiJson.dump({ test_model_many_to_many_guids: [associated_model2.guid, 'abcd'] })
              expect(last_response.status).to eq(400)
              model.reload
              expect(model.test_model_many_to_manies.length).to eq(1)
              expect(model.test_model_many_to_manies).to include(associated_model1)
            end
          end
        end

        describe 'reading' do
          context 'with no associated records' do
            it 'returns an empty collection' do
              get "/v2/test_models/#{model.guid}/test_model_many_to_manies"

              expect(last_response.status).to eq(200)
              expect(decoded_response['total_results']).to eq(0)
              expect(decoded_response).to have_key('prev_url')
              expect(decoded_response['prev_url']).to be_nil
              expect(decoded_response).to have_key('next_url')
              expect(decoded_response['next_url']).to be_nil
              expect(decoded_response['resources']).to eq []
            end
          end

          context 'with associated records' do
            before do
              model.add_test_model_many_to_many associated_model1
              model.add_test_model_many_to_many associated_model2
            end

            it 'returns collection response' do
              get "/v2/test_models/#{model.guid}/test_model_many_to_manies"

              expect(last_response.status).to eq(200)
              expect(decoded_response['total_results']).to eq(2)
              found_guids = decoded_response['resources'].collect { |resource| resource['metadata']['guid'] }
              expect(found_guids).to match_array([associated_model1.guid, associated_model2.guid])
            end

            it 'uses the collection_renderer for the associated class' do
              collection_renderer = double('Collection Renderer', render_json: 'JSON!')
              allow_any_instance_of(TestModelManyToManiesController).to receive(:collection_renderer).and_return(collection_renderer)

              get "/v2/test_models/#{model.guid}/test_model_many_to_manies"

              expect(last_response.body).to eq('JSON!')
            end

            it 'fails when you do not have access to the associated model' do
              allow_any_instance_of(TestModelManyToOneAccess).to receive(:index?).
                with(TestModelManyToOne, { related_obj: instance_of(TestModel), related_model: TestModel }).and_return(false)
              get "/v2/test_models/#{model.guid}/test_model_many_to_ones"
              expect(last_response.status).to eq(403)
            end
          end

          describe 'inline-relations-depth' do
            before { model.add_test_model_many_to_many associated_model1 }

            context 'when depth is not set' do
              it 'does not return relations inline' do
                get "/v2/test_models/#{model.guid}"
                expect(entity).to have_key 'test_model_many_to_manies_url'
                expect(entity).to_not have_key 'test_model_many_to_manies'
              end
            end

            context 'when depth is 0' do
              it 'does not return relations inline' do
                get "/v2/test_models/#{model.guid}?inline-relations-depth=0"
                expect(entity).to have_key 'test_model_many_to_manies_url'
                expect(entity).to_not have_key 'test_model_many_to_manies'
              end
            end

            context 'when depth is 1' do
              it 'returns nested relations' do
                get "/v2/test_models/#{model.guid}?inline-relations-depth=1"
                expect(entity).to have_key 'test_model_many_to_manies_url'
                expect(entity).to have_key 'test_model_many_to_manies'
              end
            end
          end
        end
      end

      describe 'to_one' do
        let(:model) { TestModelManyToOne.make }
        let(:associated_model) { TestModel.make }

        before do
          model.test_model = associated_model
          model.save
        end

        describe 'reading' do
          describe 'inline-relations-depth' do
            context 'when depth is not set' do
              it 'does not return relations inline' do
                get "/v2/test_model_many_to_ones/#{model.guid}"
                expect(entity).to have_key 'test_model_url'
                expect(entity).to have_key 'test_model_guid'
                expect(entity).to_not have_key 'test_model'
              end
            end

            context 'when depth is 0' do
              it 'does not return relations inline' do
                get "/v2/test_model_many_to_ones/#{model.guid}?inline-relations-depth=0"
                expect(entity).to have_key 'test_model_url'
                expect(entity).to have_key 'test_model_guid'
                expect(entity).to_not have_key 'test_model'
              end
            end

            context 'when depth is 1' do
              it 'returns nested relations' do
                get "/v2/test_model_many_to_ones/#{model.guid}?inline-relations-depth=1"
                expect(entity).to have_key 'test_model_url'
                expect(entity).to have_key 'test_model_guid'
                expect(entity).to have_key 'test_model'
              end
            end
          end
        end
      end
    end

    describe 'attributes censoring' do
      let(:dep) { { object_renderer: nil, collection_renderer: nil } }
      let(:model_controller) { TestModelRedactController.new(nil, FakeLogger.new([]), {}, {}, nil, nil, dep) }

      context 'when the request contains sensitive attributes' do
        let(:request_attributes) { { 'one' => 1, 'two' => 2, 'redacted' => 'password' } }
        let(:redacted_attributes) { { 'one' => 1, 'two' => 2, 'redacted' => 'PRIVATE DATA HIDDEN' } }

        it 'redacts attributes for censoring' do
          processed_attributes = model_controller.redact_attributes(:create, request_attributes)
          expect(processed_attributes).to eq redacted_attributes
        end

        context 'and the operation does not require censoring' do
          let(:redacted_attributes) { { 'one' => 1, 'two' => 2, 'redacted' => 'password' } }

          it 'does not redact' do
            processed_attributes = model_controller.redact_attributes(:read, request_attributes)
            expect(processed_attributes).to eq redacted_attributes
          end
        end
      end

      context 'when the request has no sensitive attributes' do
        let(:request_attributes) { { 'one' => 1, 'two' => 2 } }
        let(:redacted_attributes) { { 'one' => 1, 'two' => 2 } }

        it 'does not redact' do
          processed_attributes = model_controller.redact_attributes(:create, request_attributes)
          expect(processed_attributes).to eq redacted_attributes
        end
      end
    end
  end
end
