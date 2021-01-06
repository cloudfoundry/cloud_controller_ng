require 'spec_helper'
require 'request_spec_shared_examples'

RSpec.describe 'Revisions' do
  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { headers_for(user, email: user_email, user_name: user_name) }
  let(:space) { VCAP::CloudController::Space.make }
  let(:stack) { VCAP::CloudController::Stack.make }
  let(:user_email) { Sham.email }
  let(:user_name) { 'some-username' }
  let(:app_model) { VCAP::CloudController::AppModel.make(name: 'app_name', space: space) }
  let!(:revision) { VCAP::CloudController::RevisionModel.make(app: app_model, version: 42) }

  before do
    space.organization.add_user(user)
    space.add_developer(user)
  end

  describe 'GET /v3/revisions/:revguid' do
    let(:droplet) { VCAP::CloudController::DropletModel.make(process_types: { 'web' => 'bake rackup' }) }
    let(:revision) { VCAP::CloudController::RevisionModel.make(app: app_model, version: 42, droplet: droplet) }
    let!(:revision_worker_process_command) { VCAP::CloudController::RevisionProcessCommandModel.make(revision: revision, process_type: 'worker', process_command: './work') }
    let!(:revision_sidecar) { VCAP::CloudController::RevisionSidecarModel.make(revision: revision, name: 'my-sidecar', command: 'run-sidecar', memory: 300) }

    it 'gets a specific revision' do
      get "/v3/revisions/#{revision.guid}", nil, user_header
      expect(last_response.status).to eq(200), last_response.body

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
        {
          'guid' => revision.guid,
          'version' => revision.version,
          'description' => revision.description,
          'droplet' => {
            'guid' => revision.droplet_guid
          },
          'relationships' => {
            'app' => {
              'data' => {
                'guid' => app_model.guid
              }
            }
          },
          'created_at' => iso8601,
          'updated_at' => iso8601,
          'links' => {
            'self' => {
              'href' => "#{link_prefix}/v3/revisions/#{revision.guid}"
            },
            'app' => {
              'href' => "#{link_prefix}/v3/apps/#{app_model.guid}"
            },
            'environment_variables' => {
              'href' => "#{link_prefix}/v3/revisions/#{revision.guid}/environment_variables"
            },
          },
          'metadata' => { 'labels' => {}, 'annotations' => {} },
          'processes' =>  {
            'web' => {
              'command' => nil,
            },
            'worker' => {
              'command' => './work',
            },
          },
          'sidecars' => [{
            'name' => 'my-sidecar',
            'command' => 'run-sidecar',
            'process_types' => ['web'],
            'memory_in_mb' => 300,
          }],
          'deployable' => true
        }
      )
    end
  end

  describe 'GET /v3/apps/:guid/revisions' do
    let!(:revision2) { VCAP::CloudController::RevisionModel.make(app: app_model, version: 43, description: 'New droplet deployed') }

    it_behaves_like 'list query endpoint' do
      let(:message) { VCAP::CloudController::AppRevisionsListMessage }
      let(:request) { "/v3/apps/#{app_model.guid}/revisions" }
      let(:excluded_params) { [:deployable] }
      let(:params) do
        {
          page:   '2',
          per_page:   '10',
          order_by:   'updated_at',
          guids: app_model.guid.to_s,
          versions:   '1,2',
          label_selector:   'foo,bar',
          created_ats:  "#{Time.now.utc.iso8601},#{Time.now.utc.iso8601}",
          updated_ats: { gt: Time.now.utc.iso8601 },
        }
      end
    end

    it 'gets a list of revisions for the app' do
      get "/v3/apps/#{app_model.guid}/revisions?per_page=2", nil, user_header
      expect(last_response.status).to eq(200)

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
        {
          'pagination' => {
            'total_results' => 2,
            'total_pages' => 1,
            'first' => {
              'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/revisions?page=1&per_page=2"
            },
            'last' => {
              'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/revisions?page=1&per_page=2"
            },
            'next' => nil,
            'previous' => nil
          },
          'resources' => [
            {
              'guid' => revision.guid,
              'version' =>  revision.version,
              'description' => revision.description,
              'droplet' => {
                'guid' => revision.droplet_guid
              },
              'relationships' => {
                'app' => {
                  'data' => {
                    'guid' => app_model.guid
                  }
                }
              },
              'created_at' => iso8601,
              'updated_at' => iso8601,
              'links' => {
                'self' => {
                  'href' => "#{link_prefix}/v3/revisions/#{revision.guid}"
                },
                'app' => {
                  'href' => "#{link_prefix}/v3/apps/#{app_model.guid}",
                },
                'environment_variables' => {
                  'href' => "#{link_prefix}/v3/revisions/#{revision.guid}/environment_variables"
                },
              },
              'metadata' => { 'labels' => {}, 'annotations' => {} },
              'processes' => {
                'web' => {
                  'command' => nil,
                },
              },
              'sidecars' => [],
              'deployable' => true
            },
            {
              'guid' => revision2.guid,
              'version' =>  revision2.version,
              'description' => revision2.description,
              'droplet' => {
                'guid' => revision2.droplet_guid
              },
              'relationships' => {
                'app' => {
                  'data' => {
                    'guid' => app_model.guid
                  }
                }
              },
              'created_at' => iso8601,
              'updated_at' => iso8601,
              'links' => {
                'self' => {
                  'href' => "#{link_prefix}/v3/revisions/#{revision2.guid}"
                },
                'app' => {
                  'href' => "#{link_prefix}/v3/apps/#{app_model.guid}",
                },
                'environment_variables' => {
                  'href' => "#{link_prefix}/v3/revisions/#{revision2.guid}/environment_variables"
                },
              },
              'metadata' => { 'labels' => {}, 'annotations' => {} },
              'processes' => {
                'web' => {
                  'command' => nil,
                },
              },
              'sidecars' => [],
              'deployable' => true
            }
          ]
        }
      )
    end

    context 'filtering' do
      it 'gets a list of revisions matching the provided versions' do
        revision3 = VCAP::CloudController::RevisionModel.make(app: app_model, version: 44, description: 'Rollback to revision 42')

        get "/v3/apps/#{app_model.guid}/revisions?per_page=2&versions=42,44", nil, user_header
        expect(last_response.status).to eq(200)

        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response).to be_a_response_like(
          {
            'pagination' => {
              'total_results' => 2,
              'total_pages' => 1,
              'first' => {
                'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/revisions?page=1&per_page=2&versions=42%2C44"
              },
              'last' => {
                'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/revisions?page=1&per_page=2&versions=42%2C44"
              },
              'next' => nil,
              'previous' => nil
            },
            'resources' => [
              {
                'guid' => revision.guid,
                'version' =>  revision.version,
                'relationships' => {
                  'app' => {
                    'data' => {
                      'guid' => app_model.guid
                    }
                  }
                },
                'description' => revision.description,
                'droplet' => {
                  'guid' => revision.droplet_guid
                },
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'links' => {
                  'self' => {
                    'href' => "#{link_prefix}/v3/revisions/#{revision.guid}"
                  },
                  'app' => {
                    'href' => "#{link_prefix}/v3/apps/#{app_model.guid}",
                  },
                  'environment_variables' => {
                    'href' => "#{link_prefix}/v3/revisions/#{revision.guid}/environment_variables"
                  },
                },
                'metadata' => { 'labels' => {}, 'annotations' => {} },
                'processes' => {
                  'web' => {
                    'command' => nil,
                  },
                },
                'sidecars' => [],
                'deployable' => true
              },
              {
                'guid' => revision3.guid,
                'version' =>  revision3.version,
                'description' => revision3.description,
                'droplet' => {
                  'guid' => revision3.droplet_guid
                },
                'relationships' => {
                  'app' => {
                    'data' => {
                      'guid' => app_model.guid
                    }
                  }
                },
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'links' => {
                  'self' => {
                    'href' => "#{link_prefix}/v3/revisions/#{revision3.guid}"
                  },
                  'app' => {
                    'href' => "#{link_prefix}/v3/apps/#{app_model.guid}",
                  },
                  'environment_variables' => {
                    'href' => "#{link_prefix}/v3/revisions/#{revision3.guid}/environment_variables"
                  },
                },
                'metadata' => { 'labels' => {}, 'annotations' => {} },
                'processes' => {
                  'web' => {
                    'command' => nil,
                  },
                },
                'sidecars' => [],
                'deployable' => true
              }
            ]
          }
        )
      end

      context 'label_selector' do
        let!(:revisionA) { VCAP::CloudController::RevisionModel.make(app: app_model) }
        let!(:revisionB) { VCAP::CloudController::RevisionModel.make(app: app_model) }
        let!(:revisionC) { VCAP::CloudController::RevisionModel.make(app: app_model) }

        let!(:revAFruit) { VCAP::CloudController::RevisionLabelModel.make(key_name: 'fruit', value: 'strawberry', resource_guid: revisionA.guid) }
        let!(:revAAnimal) { VCAP::CloudController::RevisionLabelModel.make(key_name: 'animal', value: 'horse', resource_guid: revisionA.guid) }

        let!(:revBEnv) { VCAP::CloudController::RevisionLabelModel.make(key_name: 'env', value: 'prod', resource_guid: revisionB.guid) }
        let!(:revBAnimal) { VCAP::CloudController::RevisionLabelModel.make(key_name: 'animal', value: 'dog', resource_guid: revisionB.guid) }

        let!(:revCEnv) { VCAP::CloudController::RevisionLabelModel.make(key_name: 'env', value: 'prod', resource_guid: revisionC.guid) }
        let!(:revCAnimal) { VCAP::CloudController::RevisionLabelModel.make(key_name: 'animal', value: 'horse', resource_guid: revisionC.guid) }

        it 'returns the matching revisions' do
          get "/v3/apps/#{app_model.guid}/revisions?label_selector=!fruit,env=prod,animal in (dog,horse)", nil, user_header
          expect(last_response.status).to eq(200)

          parsed_response = MultiJson.load(last_response.body)
          expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(revisionB.guid, revisionC.guid)
        end
      end
      context 'filtering by guids' do
        before do
          VCAP::CloudController::RevisionModel.plugin :timestamps, update_on_create: false
        end

        let(:droplet) { VCAP::CloudController::DropletModel.make(app: app_model) }
        # .make updates the resource after creating it, over writing our passed in updated_at timestamp
        # Therefore we cannot use shared_examples as the updated_at will not be as written
        let!(:resource_1) {
          VCAP::CloudController::RevisionModel.create(
            created_at: '2020-05-26T18:47:01Z',
            updated_at: '2020-05-26T18:47:01Z',
            droplet: droplet,
            description: '',
            app: app_model)
        }
        let!(:resource_2) {
          VCAP::CloudController::RevisionModel.create(
            created_at: '2020-05-26T18:47:02Z',
            updated_at: '2020-05-26T18:47:02Z',
            droplet: droplet,
            description: '',
            app: app_model)
        }
        let!(:resource_3) {
          VCAP::CloudController::RevisionModel.create(
            created_at: '2020-05-26T18:47:03Z',
            updated_at: '2020-05-26T18:47:03Z',
            droplet: droplet,
            description: '',
            app: app_model)
        }

        after do
          VCAP::CloudController::RevisionModel.plugin :timestamps, update_on_create: true
        end

        it 'filters by the created at' do
          get "/v3/apps/#{app_model.guid}/revisions?guids=#{resource_1.guid},#{resource_2.guid}", nil, admin_headers

          expect(last_response).to have_status_code(200)
          expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(resource_1.guid, resource_2.guid)
        end
      end

      context 'filtering by timestamps' do
        before do
          VCAP::CloudController::RevisionModel.plugin :timestamps, update_on_create: false
        end

        let(:droplet) { VCAP::CloudController::DropletModel.make(app: app_model) }
        # .make updates the resource after creating it, over writing our passed in updated_at timestamp
        # Therefore we cannot use shared_examples as the updated_at will not be as written
        let!(:resource_1) {
          VCAP::CloudController::RevisionModel.create(
            created_at: '2020-05-26T18:47:01Z',
            updated_at: '2020-05-26T18:47:01Z',
            droplet: droplet,
            description: '',
            app: app_model)
        }
        let!(:resource_2) {
          VCAP::CloudController::RevisionModel.create(
            created_at: '2020-05-26T18:47:02Z',
            updated_at: '2020-05-26T18:47:02Z',
            droplet: droplet,
            description: '',
            app: app_model)
        }
        let!(:resource_3) {
          VCAP::CloudController::RevisionModel.create(
            created_at: '2020-05-26T18:47:03Z',
            updated_at: '2020-05-26T18:47:03Z',
            droplet: droplet,
            description: '',
            app: app_model)
        }
        let!(:resource_4) {
          VCAP::CloudController::RevisionModel.create(
            created_at: '2020-05-26T18:47:04Z',
            updated_at: '2020-05-26T18:47:04Z',
            droplet: droplet,
            description: '',
            app: app_model)
        }

        after do
          VCAP::CloudController::RevisionModel.plugin :timestamps, update_on_create: true
        end

        it 'filters by the created at' do
          get "/v3/apps/#{app_model.guid}/revisions?created_ats[lt]=#{resource_3.created_at.iso8601}", nil, admin_headers

          expect(last_response).to have_status_code(200)
          expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(resource_1.guid, resource_2.guid)
        end

        it 'filters by the updated_at' do
          get "/v3/apps/#{app_model.guid}/revisions?updated_ats[lt]=#{resource_3.updated_at.iso8601}", nil, admin_headers

          expect(last_response).to have_status_code(200)
          expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(resource_1.guid, resource_2.guid)
        end
      end
    end
  end

  describe 'PATCH /v3/revisions/:revguid' do
    let(:update_request) do
      {
        metadata: {
          labels: {
            freaky: 'thursday'
          },
          annotations: {
            quality: 'p sus'
          }
        },
      }.to_json
    end

    it 'updates the revision with metadata' do
      patch "/v3/revisions/#{revision.guid}", update_request, user_header
      expect(last_response.status).to eq(200)

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
        {
          'guid' => revision.guid,
          'version' => revision.version,
          'description' => revision.description,
          'droplet' => {
            'guid' => revision.droplet_guid
          },
          'relationships' => {
            'app' => {
              'data' => {
                'guid' => app_model.guid
              }
            }
          },
          'created_at' => iso8601,
          'updated_at' => iso8601,
          'links' => {
            'self' => {
              'href' => "#{link_prefix}/v3/revisions/#{revision.guid}",
            },
            'app' => {
              'href' => "#{link_prefix}/v3/apps/#{app_model.guid}",
            },
            'environment_variables' => {
              'href' => "#{link_prefix}/v3/revisions/#{revision.guid}/environment_variables"
            },
          },
          'metadata' => {
            'labels' => { 'freaky' => 'thursday' },
            'annotations' => { 'quality' => 'p sus' }
          },
          'processes' => {
            'web' => {
              'command' => nil,
            },
          },
          'sidecars' => [],
          'deployable' => true
        }
      )
    end
  end

  describe 'GET /v3/revision/:revguid/environment_variables' do
    let!(:revision2) { VCAP::CloudController::RevisionModel.make(
      app: app_model,
      version: 43,
      environment_variables: { 'key' => 'value' },
    )
    }

    it 'gets the environment variables for the revision' do
      get "/v3/revisions/#{revision2.guid}/environment_variables", nil, user_header
      expect(last_response.status).to eq(200), last_response.body

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
        {
          'var' => {
            'key' => 'value'
          },
          'links' => {
            'self' => { 'href' => "#{link_prefix}/v3/revisions/#{revision2.guid}/environment_variables" },
            'revision' => { 'href' => "#{link_prefix}/v3/revisions/#{revision2.guid}" },
            'app' => { 'href' => "#{link_prefix}/v3/apps/#{app_model.guid}" },
          }
        }
      )
    end
  end

  describe 'GET /v3/apps/:guid/revisions/deployed' do
    let!(:revision2) { VCAP::CloudController::RevisionModel.make(app: app_model, version: 43, description: 'New droplet deployed') }
    let!(:revision3) { VCAP::CloudController::RevisionModel.make(app: app_model, version: 44, description: 'New environment variables') }
    let!(:process) { VCAP::CloudController::ProcessModel.make(app: app_model, revision: revision, type: 'web', state: 'STARTED') }
    let!(:process2) { VCAP::CloudController::ProcessModel.make(app: app_model, revision: revision2, type: 'worker', state: 'STARTED') }
    let!(:process3) { VCAP::CloudController::ProcessModel.make(app: app_model, revision: revision3, type: 'web', state: 'STOPPED') }

    it 'gets a list of deployed revisions' do
      get "/v3/apps/#{app_model.guid}/revisions/deployed?per_page=2", nil, user_header
      expect(last_response.status).to eq(200), last_response.body

      parsed_response = MultiJson.load(last_response.body)
      expect(parsed_response).to be_a_response_like(
        {
          'pagination' => {
            'total_results' => 2,
            'total_pages' => 1,
            'first' => {
              'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/revisions/deployed?page=1&per_page=2"
            },
            'last' => {
              'href' => "#{link_prefix}/v3/apps/#{app_model.guid}/revisions/deployed?page=1&per_page=2"
            },
            'next' => nil,
            'previous' => nil
          },
          'resources' => [
            {
              'guid' => revision.guid,
              'version' =>  revision.version,
              'description' => revision.description,
              'droplet' => {
                'guid' => revision.droplet_guid
              },
              'relationships' => {
                'app' => {
                  'data' => {
                    'guid' => app_model.guid
                  }
                }
              },
              'created_at' => iso8601,
              'updated_at' => iso8601,
              'links' => {
                'self' => {
                  'href' => "#{link_prefix}/v3/revisions/#{revision.guid}"
                },
                'app' => {
                  'href' => "#{link_prefix}/v3/apps/#{app_model.guid}",
                },
                'environment_variables' => {
                  'href' => "#{link_prefix}/v3/revisions/#{revision.guid}/environment_variables"
                },
              },
              'metadata' => { 'labels' => {}, 'annotations' => {} },
              'processes' => {
                'web' => {
                  'command' => nil,
                },
              },
              'sidecars' => [],
              'deployable' => true
            },
            {
              'guid' => revision2.guid,
              'version' =>  revision2.version,
              'description' => revision2.description,
              'droplet' => {
                'guid' => revision2.droplet_guid
              },
              'relationships' => {
                'app' => {
                  'data' => {
                    'guid' => app_model.guid
                  }
                }
              },
              'created_at' => iso8601,
              'updated_at' => iso8601,
              'links' => {
                'self' => {
                  'href' => "#{link_prefix}/v3/revisions/#{revision2.guid}"
                },
                'app' => {
                  'href' => "#{link_prefix}/v3/apps/#{app_model.guid}",
                },
                'environment_variables' => {
                  'href' => "#{link_prefix}/v3/revisions/#{revision2.guid}/environment_variables"
                },
              },
              'metadata' => { 'labels' => {}, 'annotations' => {} },
              'processes' => {
                'web' => {
                  'command' => nil,
                },
              },
              'sidecars' => [],
              'deployable' => true
            }
          ]
        }
      )
    end
  end
end
