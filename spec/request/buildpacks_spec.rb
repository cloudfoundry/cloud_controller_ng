require 'spec_helper'
require 'messages/buildpack_upload_message'
require 'request_spec_shared_examples'

RSpec.describe 'buildpacks' do
  describe 'GET /v3/buildpacks' do
    let(:user) { make_user }
    let(:headers) { headers_for(user) }

    before do
      TestConfig.override(kubernetes: {})
    end

    it 'returns 200 OK' do
      get '/v3/buildpacks', nil, headers
      expect(last_response.status).to eq(200)
    end

    it_behaves_like 'list query endpoint' do
      let(:request) { 'v3/buildpacks' }

      let(:message) { VCAP::CloudController::BuildpacksListMessage }
      let(:user_header) { headers }
      let(:params) do
        {
          page: '2',
          per_page: '10',
          order_by: 'updated_at',
          names: 'foo',
          stacks: 'cf',
          label_selector: 'foo,bar',
          guids: 'foo,bar',
          created_ats:  "#{Time.now.utc.iso8601},#{Time.now.utc.iso8601}",
          updated_ats: { gt: Time.now.utc.iso8601 },
        }
      end
    end

    it_behaves_like 'list_endpoint_with_common_filters' do
      let(:resource_klass) { VCAP::CloudController::Buildpack }
      let(:api_call) do
        lambda { |headers, filters| get "/v3/buildpacks?#{filters}", nil, headers }
      end
      let(:headers) { admin_headers }
    end

    context 'when filtered by label_selector' do
      let!(:buildpackA) { VCAP::CloudController::Buildpack.make(name: 'A') }
      let!(:buildpackAFruit) { VCAP::CloudController::BuildpackLabelModel.make(key_name: 'fruit', value: 'strawberry', buildpack: buildpackA) }
      let!(:buildpackAAnimal) { VCAP::CloudController::BuildpackLabelModel.make(key_name: 'animal', value: 'horse', buildpack: buildpackA) }

      let!(:buildpackB) { VCAP::CloudController::Buildpack.make(name: 'B') }
      let!(:buildpackBEnv) { VCAP::CloudController::BuildpackLabelModel.make(key_name: 'env', value: 'prod', buildpack: buildpackB) }
      let!(:buildpackBAnimal) { VCAP::CloudController::BuildpackLabelModel.make(key_name: 'animal', value: 'dog', buildpack: buildpackB) }

      let!(:buildpackC) { VCAP::CloudController::Buildpack.make(name: 'C') }
      let!(:buildpackCEnv) { VCAP::CloudController::BuildpackLabelModel.make(key_name: 'env', value: 'prod', buildpack: buildpackC) }
      let!(:buildpackCAnimal) { VCAP::CloudController::BuildpackLabelModel.make(key_name: 'animal', value: 'horse', buildpack: buildpackC) }

      let!(:buildpackD) { VCAP::CloudController::Buildpack.make(name: 'D') }
      let!(:buildpackDEnv) { VCAP::CloudController::BuildpackLabelModel.make(key_name: 'env', value: 'prod', buildpack: buildpackD) }

      let!(:buildpackE) { VCAP::CloudController::Buildpack.make(name: 'E') }
      let!(:buildpackEEnv) { VCAP::CloudController::BuildpackLabelModel.make(key_name: 'env', value: 'staging', buildpack: buildpackE) }
      let!(:buildpackEAnimal) { VCAP::CloudController::BuildpackLabelModel.make(key_name: 'animal', value: 'dog', buildpack: buildpackE) }

      it 'returns the matching buildpacks' do
        get '/v3/buildpacks?label_selector=!fruit,env=prod,animal in (dog,horse)', nil, admin_headers
        expect(last_response.status).to eq(200), last_response.body

        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(buildpackB.guid, buildpackC.guid)
      end
    end

    context 'when filtered by null stack' do
      let!(:stack) { VCAP::CloudController::Stack.make }
      let!(:buildpack_without_stack) { VCAP::CloudController::Buildpack.make(stack: nil) }
      let!(:buildpack_with_stack) { VCAP::CloudController::Buildpack.make(stack: stack.name) }

      it 'returns the matching buildpacks' do
        get '/v3/buildpacks?stacks=', nil, admin_headers
        expect(last_response.status).to eq(200), last_response.body

        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response['resources'].map { |r| r['guid'] }).to contain_exactly(buildpack_without_stack.guid)
      end
    end

    context 'When buildpacks exist' do
      let!(:stack1) { VCAP::CloudController::Stack.make }
      let!(:stack2) { VCAP::CloudController::Stack.make }
      let!(:stack3) { VCAP::CloudController::Stack.make }

      let!(:buildpack1) { VCAP::CloudController::Buildpack.make(stack: stack1.name) }
      let!(:buildpack2) { VCAP::CloudController::Buildpack.make(stack: stack2.name) }
      let!(:buildpack3) { VCAP::CloudController::Buildpack.make(stack: stack3.name) }

      it 'returns a paginated list of buildpacks' do
        get '/v3/buildpacks?page=1&per_page=2', nil, headers

        expect(parsed_response).to be_a_response_like(
          {
            'pagination' => {
              'total_results' => 3,
              'total_pages' => 2,
              'first' => {
                'href' => "#{link_prefix}/v3/buildpacks?page=1&per_page=2"
              },
              'last' => {
                'href' => "#{link_prefix}/v3/buildpacks?page=2&per_page=2"
              },
              'next' => {
                'href' => "#{link_prefix}/v3/buildpacks?page=2&per_page=2"
              },
              'previous' => nil
            },
            'resources' => [
              {
                'guid' => buildpack1.guid,
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'name' => buildpack1.name,
                'state' => buildpack1.state,
                'filename' => buildpack1.filename,
                'stack' => buildpack1.stack,
                'position' => 1,
                'enabled' => true,
                'locked' => false,
                'metadata' => { 'labels' => {}, 'annotations' => {} },
                'links' => {
                  'self' => {
                    'href' => "#{link_prefix}/v3/buildpacks/#{buildpack1.guid}"
                  },
                  'upload' => {
                    'href' => "#{link_prefix}/v3/buildpacks/#{buildpack1.guid}/upload",
                    'method' => 'POST'
                  }
                }
              },
              {
                'guid' => buildpack2.guid,
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'name' => buildpack2.name,
                'state' => buildpack2.state,
                'filename' => buildpack2.filename,
                'stack' => buildpack2.stack,
                'position' => 2,
                'enabled' => true,
                'locked' => false,
                'metadata' => { 'labels' => {}, 'annotations' => {} },
                'links' => {
                  'self' => {
                    'href' => "#{link_prefix}/v3/buildpacks/#{buildpack2.guid}"
                  },
                  'upload' => {
                    'href' => "#{link_prefix}/v3/buildpacks/#{buildpack2.guid}/upload",
                    'method' => 'POST'
                  }
                }
              }
            ]
          }
        )
      end

      it 'returns a list of filtered buildpacks' do
        get "/v3/buildpacks?names=#{buildpack1.name},#{buildpack3.name}&stacks=#{stack1.name}", nil, headers

        expect(parsed_response).to be_a_response_like(
          {
            'pagination' => {
              'total_results' => 1,
              'total_pages' => 1,
              'first' => {
                'href' => "#{link_prefix}/v3/buildpacks?names=#{buildpack1.name}%2C#{buildpack3.name}&page=1&per_page=50&stacks=#{stack1.name}"
              },
              'last' => {
                'href' => "#{link_prefix}/v3/buildpacks?names=#{buildpack1.name}%2C#{buildpack3.name}&page=1&per_page=50&stacks=#{stack1.name}"
              },
              'next' => nil,
              'previous' => nil
            },
            'resources' => [
              {
                'guid' => buildpack1.guid,
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'name' => buildpack1.name,
                'state' => buildpack1.state,
                'filename' => buildpack1.filename,
                'stack' => stack1.name,
                'position' => 1,
                'enabled' => true,
                'locked' => false,
                'metadata' => { 'labels' => {}, 'annotations' => {} },
                'links' => {
                  'self' => {
                    'href' => "#{link_prefix}/v3/buildpacks/#{buildpack1.guid}"
                  },
                  'upload' => {
                    'href' => "#{link_prefix}/v3/buildpacks/#{buildpack1.guid}/upload",
                    'method' => 'POST'
                  }
                }
              }
            ]
          }
        )
      end

      it 'orders by position' do
        get "/v3/buildpacks?names=#{buildpack1.name},#{buildpack3.name}&order_by=-position", nil, headers

        expect(parsed_response).to be_a_response_like(
          {
            'pagination' => {
              'total_results' => 2,
              'total_pages' => 1,
              'first' => {
                'href' => "#{link_prefix}/v3/buildpacks?names=#{buildpack1.name}%2C#{buildpack3.name}&order_by=-position&page=1&per_page=50"
              },
              'last' => {
                'href' => "#{link_prefix}/v3/buildpacks?names=#{buildpack1.name}%2C#{buildpack3.name}&order_by=-position&page=1&per_page=50"
              },
              'next' => nil,
              'previous' => nil
            },
            'resources' => [
              {
                'guid' => buildpack3.guid,
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'name' => buildpack3.name,
                'state' => buildpack3.state,
                'filename' => buildpack3.filename,
                'stack' => buildpack3.stack,
                'position' => 3,
                'enabled' => true,
                'locked' => false,
                'metadata' => { 'labels' => {}, 'annotations' => {} },
                'links' => {
                  'self' => {
                    'href' => "#{link_prefix}/v3/buildpacks/#{buildpack3.guid}"
                  },
                  'upload' => {
                    'href' => "#{link_prefix}/v3/buildpacks/#{buildpack3.guid}/upload",
                    'method' => 'POST'
                  }
                }
              },
              {
                'guid' => buildpack1.guid,
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'name' => buildpack1.name,
                'state' => buildpack1.state,
                'filename' => buildpack1.filename,
                'stack' => buildpack1.stack,
                'position' => 1,
                'enabled' => true,
                'locked' => false,
                'metadata' => { 'labels' => {}, 'annotations' => {} },
                'links' => {
                  'self' => {
                    'href' => "#{link_prefix}/v3/buildpacks/#{buildpack1.guid}"
                  },
                  'upload' => {
                    'href' => "#{link_prefix}/v3/buildpacks/#{buildpack1.guid}/upload",
                    'method' => 'POST'
                  }
                }
              }
            ]
          }
        )
      end
    end

    context 'when targeting a Kubernetes API' do
      let(:client) { instance_double(Kubernetes::ApiClient) }
      let(:kubernetes_api_url) { 'https://kube.example.com' }

      before do
        stub_request(:get, "#{kubernetes_api_url}/apis/kpack.io/v1alpha1").to_return(
          status: 200,
          body: '
            {
              "kind": "APIResourceList",
              "apiVersion": "v1",
              "groupVersion": "kpack.io/v1alpha1",
              "resources": [
                {
                  "name": "builders",
                  "singularName": "builder",
                  "namespaced": true,
                  "kind": "Builder",
                  "verbs": [
                    "delete",
                    "deletecollection",
                    "get",
                    "list",
                    "patch",
                    "create",
                    "update",
                    "watch"
                  ],
                  "shortNames": [
                    "custmbldr"
                  ],
                  "categories": [
                    "kpack"
                  ],
                  "storageVersionHash": "2afHeqawAfQ="
                },
                {
                  "name": "builders/status",
                  "singularName": "",
                  "namespaced": true,
                  "kind": "Builder",
                  "verbs": [
                    "get",
                    "patch",
                    "update"
                  ]
                }
              ]
  }
          '
        )
        stub_request(:get, "#{kubernetes_api_url}/apis/kpack.io/v1alpha1/namespaces/cf-workloads-staging/builders/cf-default-builder").
          to_return(
            status: 200,
            # rubocop:disable Layout/LineLength
            body: '
              {
                "apiVersion": "kpack.io/v1alpha1",
                "kind": "Builder",
                "metadata": {
                  "annotations": {
                    "kapp.k14s.io/identity": "v1;cf-workloads-staging/kpack.io/Builder/cf-default-builder;kpack.io/v1alpha1",
                    "kapp.k14s.io/original": "{\"apiVersion\":\"kpack.io/v1alpha1\",\"kind\":\"Builder\",\"metadata\":{\"labels\":{\"kapp.k14s.io/app\":\"1593227539339407000\",\"kapp.k14s.io/association\":\"v1.b29251cc7bb0f9e1950aad9f9ea1d82a\"},\"name\":\"cf-default-builder\",\"namespace\":\"cf-workloads-staging\"},\"spec\":{\"order\":[{\"group\":[{\"id\":\"paketo-community/ruby\"}]},{\"group\":[{\"id\":\"paketo-community/python\"}]},{\"group\":[{\"id\":\"paketo-buildpacks/java\"}]},{\"group\":[{\"id\":\"paketo-buildpacks/nodejs\"}]},{\"group\":[{\"id\":\"paketo-buildpacks/go\"}]},{\"group\":[{\"id\":\"paketo-buildpacks/dotnet-core\"}]},{\"group\":[{\"id\":\"paketo-buildpacks/php\"}]},{\"group\":[{\"id\":\"paketo-buildpacks/httpd\"}]},{\"group\":[{\"id\":\"paketo-buildpacks/nginx\"}]},{\"group\":[{\"id\":\"paketo-buildpacks/procfile\"}]}],\"serviceAccount\":\"cc-kpack-registry-service-account\",\"stack\":\"cflinuxfs3-stack\",\"store\":\"cf-buildpack-store\",\"tag\":\"gcr.io/cf-capi-arya/cf-workloads/cf-default-builder\"}}",
                    "kapp.k14s.io/original-diff-md5": "c6e94dc94aed3401b5d0f26ed6c0bff3"
                  },
                  "creationTimestamp": "2020-06-27T03:13:07Z",
                  "generation": 1,
                  "labels": {
                    "kapp.k14s.io/app": "1593227539339407000",
                    "kapp.k14s.io/association": "v1.b29251cc7bb0f9e1950aad9f9ea1d82a"
                  },
                  "name": "cf-default-builder",
                  "namespace": "cf-workloads-staging",
                  "resourceVersion": "5467789",
                  "selfLink": "/apis/kpack.io/v1alpha1/namespaces/cf-workloads-staging/builders/cf-default-builder",
                  "uid": "82ede34e-20ae-4d81-8813-ac57134d4062"
                },
                "spec": {
                  "order": [
                    {
                      "group": [
                        {
                          "id": "paketo-community/ruby"
                        }
                      ]
                    },
                    {
                      "group": [
                        {
                          "id": "paketo-community/python"
                        }
                      ]
                    },
                    {
                      "group": [
                        {
                          "id": "paketo-buildpacks/java"
                        }
                      ]
                    },
                    {
                      "group": [
                        {
                          "id": "paketo-buildpacks/nodejs"
                        }
                      ]
                    },
                    {
                      "group": [
                        {
                          "id": "paketo-buildpacks/go"
                        }
                      ]
                    },
                    {
                      "group": [
                        {
                          "id": "paketo-buildpacks/dotnet-core"
                        }
                      ]
                    },
                    {
                      "group": [
                        {
                          "id": "paketo-buildpacks/php"
                        }
                      ]
                    },
                    {
                      "group": [
                        {
                          "id": "paketo-buildpacks/httpd"
                        }
                      ]
                    },
                    {
                      "group": [
                        {
                          "id": "paketo-buildpacks/nginx"
                        }
                      ]
                    },
                    {
                      "group": [
                        {
                          "id": "paketo-buildpacks/procfile"
                        }
                      ]
                    }
                  ],
                  "serviceAccount": "cc-kpack-registry-service-account",
                  "stack": "cflinuxfs3-stack",
                  "store": "cf-buildpack-store",
                  "tag": "gcr.io/cf-capi-arya/cf-workloads/cf-default-builder"
                },
                "status": {
                  "builderMetadata": [
                    {
                      "id": "paketo-buildpacks/bellsoft-liberica",
                      "version": "2.8.0"
                    },
                    {
                      "id": "paketo-buildpacks/php-web",
                      "version": "0.0.108"
                    },
                    {
                      "id": "paketo-buildpacks/nginx",
                      "version": "0.0.151"
                    },
                    {
                      "id": "paketo-buildpacks/php-composer",
                      "version": "0.0.90"
                    },
                    {
                      "id": "paketo-buildpacks/node-engine",
                      "version": "0.0.210"
                    },
                    {
                      "id": "paketo-buildpacks/httpd",
                      "version": "0.0.132"
                    },
                    {
                      "id": "paketo-buildpacks/yarn-install",
                      "version": "0.1.49"
                    },
                    {
                      "id": "paketo-buildpacks/google-stackdriver",
                      "version": "1.3.0"
                    },
                    {
                      "id": "paketo-buildpacks/encrypt-at-rest",
                      "version": "1.2.8"
                    },
                    {
                      "id": "paketo-buildpacks/azure-application-insights",
                      "version": "1.3.0"
                    },
                    {
                      "id": "paketo-buildpacks/dep",
                      "version": "0.0.140"
                    },
                    {
                      "id": "paketo-buildpacks/dotnet-core-aspnet",
                      "version": "0.0.159"
                    },
                    {
                      "id": "paketo-buildpacks/dotnet-core-sdk",
                      "version": "0.0.161"
                    },
                    {
                      "id": "paketo-buildpacks/dotnet-core-runtime",
                      "version": "0.0.163"
                    },
                    {
                      "id": "paketo-buildpacks/php-dist",
                      "version": "0.0.164"
                    },
                    {
                      "id": "paketo-buildpacks/dotnet-core-build",
                      "version": "0.0.95"
                    },
                    {
                      "id": "paketo-community/pipenv",
                      "version": "0.0.97"
                    },
                    {
                      "id": "paketo-buildpacks/icu",
                      "version": "0.0.73"
                    },
                    {
                      "id": "paketo-community/conda",
                      "version": "0.0.90"
                    },
                    {
                      "id": "paketo-buildpacks/go-mod",
                      "version": "0.0.128"
                    },
                    {
                      "id": "paketo-buildpacks/dotnet-core-conf",
                      "version": "0.0.150"
                    },
                    {
                      "id": "paketo-community/pip",
                      "version": "0.0.115"
                    },
                    {
                      "id": "paketo-buildpacks/spring-boot",
                      "version": "1.6.0"
                    },
                    {
                      "id": "paketo-community/mri",
                      "version": "0.0.131"
                    },
                    {
                      "id": "paketo-buildpacks/debug",
                      "version": "1.2.8"
                    },
                    {
                      "id": "paketo-community/python-runtime",
                      "version": "0.0.128"
                    },
                    {
                      "id": "paketo-buildpacks/go-compiler",
                      "version": "0.0.160"
                    },
                    {
                      "id": "paketo-community/bundler",
                      "version": "0.0.117"
                    },
                    {
                      "id": "paketo-buildpacks/apache-tomcat",
                      "version": "1.3.0"
                    },
                    {
                      "id": "paketo-buildpacks/maven",
                      "version": "1.4.5"
                    },
                    {
                      "id": "paketo-buildpacks/gradle",
                      "version": "1.3.1"
                    },
                    {
                      "id": "paketo-buildpacks/sbt",
                      "version": "1.2.5"
                    },
                    {
                      "id": "paketo-buildpacks/jmx",
                      "version": "1.1.8"
                    },
                    {
                      "id": "paketo-buildpacks/executable-jar",
                      "version": "1.2.7"
                    },
                    {
                      "id": "paketo-buildpacks/npm",
                      "version": "0.1.39"
                    },
                    {
                      "id": "paketo-buildpacks/procfile",
                      "version": "1.3.8"
                    },
                    {
                      "id": "paketo-buildpacks/image-labels",
                      "version": "1.1.0"
                    },
                    {
                      "id": "paketo-buildpacks/dist-zip",
                      "version": "1.3.5"
                    },
                    {
                      "id": "paketo-community/bundle-install",
                      "version": "0.0.22"
                    },
                    {
                      "id": "paketo-community/rackup",
                      "version": "0.0.13"
                    },
                    {
                      "id": "paketo-community/unicorn",
                      "version": "0.0.8"
                    },
                    {
                      "id": "paketo-community/puma",
                      "version": "0.0.14"
                    },
                    {
                      "id": "paketo-community/thin",
                      "version": "0.0.11"
                    },
                    {
                      "id": "paketo-buildpacks/java",
                      "version": "1.14.0"
                    },
                    {
                      "id": "paketo-buildpacks/dotnet-core",
                      "version": "0.0.5"
                    },
                    {
                      "id": "paketo-community/ruby",
                      "version": "0.0.11"
                    },
                    {
                      "id": "paketo-buildpacks/php",
                      "version": "0.0.7"
                    },
                    {
                      "id": "paketo-community/python",
                      "version": "0.0.2"
                    },
                    {
                      "id": "paketo-buildpacks/go",
                      "version": "0.0.8"
                    },
                    {
                      "id": "paketo-buildpacks/nodejs",
                      "version": "0.0.3"
                    }
                  ],
                  "conditions": [
                    {
                      "lastTransitionTime": "2020-06-27T03:15:46Z",
                      "status": "True",
                      "type": "Ready"
                    }
                  ],
                  "latestImage": "gcr.io/cf-capi-arya/cf-workloads/cf-default-builder@sha256:6fe98d20624f29b89ec03b69b12f9b01a1826c0e14158b7dc66bc32bcadcb299",
                  "observedGeneration": 1,
                  "stack": {
                    "id": "org.cloudfoundry.stacks.cflinuxfs3",
                    "runImage": "gcr.io/paketo-buildpacks/run@sha256:84f7b60192e69036cb363b2fc7d9834cff69dcbcf7aaf8c058d986fdee6941c3"
                  }
                }
              }
              '
            # rubocop:enable Layout/LineLength
          )

        TestConfig.override(
          kubernetes: {
            host_url: kubernetes_api_url,
            service_account: { token_file: Rails.root + 'spec/fixtures/service_accounts/k8s.token' },
            ca_file: Rails.root + 'spec/fixtures/certs/kubernetes_ca.crt',
            kpack: { builder_namespace: 'cf-workloads-staging' },
          },
        )
      end

      it 'renders a list of paketo buildpacks' do
        get '/v3/buildpacks', nil, headers

        parsed_response = MultiJson.load(last_response.body)
        expect(parsed_response['pagination']['total_results']).to(eq(10))
        expect(parsed_response['resources'].map { |r| r['name'] }).to(eq(%w[
          paketo-buildpacks/dotnet-core
          paketo-buildpacks/go
          paketo-buildpacks/httpd
          paketo-buildpacks/java
          paketo-buildpacks/nginx
          paketo-buildpacks/nodejs
          paketo-buildpacks/php
          paketo-buildpacks/procfile
          paketo-community/python
          paketo-community/ruby
        ]))
      end
    end
  end

  describe 'POST /v3/buildpacks' do
    context 'when not authenticated' do
      let(:headers) { {} }

      it 'returns 401' do
        post '/v3/buildpacks', nil, headers

        expect(last_response.status).to eq(401)
      end
    end

    context 'when authenticated but not admin' do
      let(:user) { VCAP::CloudController::User.make }
      let(:headers) { headers_for(user) }

      it 'returns 403' do
        params = {}

        post '/v3/buildpacks', params, headers

        expect(last_response.status).to eq(403)
      end
    end

    context 'when authenticated and admin' do
      let(:user) { VCAP::CloudController::User.make }
      let(:headers) { admin_headers_for(user) }

      context 'when successful' do
        let(:stack) { VCAP::CloudController::Stack.make }
        let(:params) do
          {
            name: 'the-r3al_Name',
            stack: stack.name,
            enabled: false,
            locked: true,
            metadata: {
              labels: {
                potato: 'yam'
              },
              annotations: {
                potato: 'idaho'
              }
            },
          }
        end

        it 'returns 201' do
          post '/v3/buildpacks', params.to_json, headers

          expect(last_response.status).to eq(201)
        end

        describe 'non-position values' do
          it 'returns the newly-created buildpack resource' do
            post '/v3/buildpacks', params.to_json, headers

            buildpack = VCAP::CloudController::Buildpack.last

            expected_response = {
              'name' => params[:name],
              'state' => 'AWAITING_UPLOAD',
              'filename' => nil,
              'stack' => params[:stack],
              'position' => 1,
              'enabled' => params[:enabled],
              'locked' => params[:locked],
              'guid' => buildpack.guid,
              'created_at' => iso8601,
              'updated_at' => iso8601,
              'metadata' => {
                'labels' => {
                  'potato' => 'yam'
                },
                'annotations' => {
                  'potato' => 'idaho'
                },
              },
              'links' => {
                'self' => {
                  'href' => "#{link_prefix}/v3/buildpacks/#{buildpack.guid}"
                },
                'upload' => {
                  'href' => "#{link_prefix}/v3/buildpacks/#{buildpack.guid}/upload",
                  'method' => 'POST'
                }
              }
            }
            expect(parsed_response).to be_a_response_like(expected_response)
          end
        end

        describe 'position' do
          let!(:buildpack1) { VCAP::CloudController::Buildpack.make(position: 1) }
          let!(:buildpack2) { VCAP::CloudController::Buildpack.make(position: 2) }
          let!(:buildpack3) { VCAP::CloudController::Buildpack.make(position: 3) }

          context 'the position is not provided' do
            it 'defaults the position value to 1' do
              post '/v3/buildpacks', params.to_json, headers

              expect(parsed_response['position']).to eq(1)
              expect(buildpack1.reload.position).to eq(2)
              expect(buildpack2.reload.position).to eq(3)
              expect(buildpack3.reload.position).to eq(4)
            end
          end

          context 'the position is less than or equal to the total number of buildpacks' do
            before do
              params[:position] = 2
            end

            it 'sets the position value to the provided position' do
              post '/v3/buildpacks', params.to_json, headers

              expect(parsed_response['position']).to eq(2)
              expect(buildpack1.reload.position).to eq(1)
              expect(buildpack2.reload.position).to eq(3)
              expect(buildpack3.reload.position).to eq(4)
            end
          end

          context 'the position is greater than the total number of buildpacks' do
            before do
              params[:position] = 42
            end

            it 'sets the position value to the provided position' do
              post '/v3/buildpacks', params.to_json, headers

              expect(parsed_response['position']).to eq(4)
              expect(buildpack1.reload.position).to eq(1)
              expect(buildpack2.reload.position).to eq(2)
              expect(buildpack3.reload.position).to eq(3)
            end
          end
        end
      end
    end
  end

  describe 'GET /v3/buildpacks/:guid' do
    let(:params) { {} }
    let(:buildpack) { VCAP::CloudController::Buildpack.make }

    context 'when not authenticated' do
      it 'returns 401' do
        headers = {}

        get "/v3/buildpacks/#{buildpack.guid}", params, headers

        expect(last_response.status).to eq(401)
      end
    end

    context 'when authenticated' do
      let(:user) { VCAP::CloudController::User.make }
      let(:headers) { headers_for(user) }

      context 'the buildpack does not exist' do
        it 'returns 404' do
          get '/v3/buildpacks/does-not-exist', params, headers
          expect(last_response.status).to eq(404)
        end

        context 'the buildpack exists' do
          it 'returns 200' do
            get "/v3/buildpacks/#{buildpack.guid}", params, headers
            expect(last_response.status).to eq(200)
          end

          it 'returns the newly-created buildpack resource' do
            get "/v3/buildpacks/#{buildpack.guid}", params, headers

            expected_response = {
              'name' => buildpack.name,
              'state' => buildpack.state,
              'stack' => buildpack.stack,
              'filename' => buildpack.filename,
              'position' => buildpack.position,
              'enabled' => buildpack.enabled,
              'locked' => buildpack.locked,
              'guid' => buildpack.guid,
              'created_at' => iso8601,
              'updated_at' => iso8601,
              'metadata' => { 'labels' => {}, 'annotations' => {} },
              'links' => {
                'self' => {
                  'href' => "#{link_prefix}/v3/buildpacks/#{buildpack.guid}"
                },
                'upload' => {
                  'href' => "#{link_prefix}/v3/buildpacks/#{buildpack.guid}/upload",
                  'method' => 'POST'
                }
              }
            }
            expect(parsed_response).to be_a_response_like(expected_response)
          end
        end
      end
    end
  end

  describe 'DELETE /v3/buildpacks/:guid' do
    let(:buildpack) { VCAP::CloudController::Buildpack.make }

    it 'deletes a buildpack asynchronously' do
      delete "/v3/buildpacks/#{buildpack.guid}", nil, admin_headers

      expect(last_response.status).to eq(202)
      expect(last_response.headers['Location']).to match(%r(http.+/v3/jobs/[a-fA-F0-9-]+))

      execute_all_jobs(expected_successes: 2, expected_failures: 0)
      get "/v3/buildpacks/#{buildpack.guid}", {}, admin_headers
      expect(last_response.status).to eq(404)
    end

    context 'deleting metadata' do
      it_behaves_like 'resource with metadata' do
        let(:resource) { buildpack }
        let(:api_call) do
          -> { delete "/v3/buildpacks/#{resource.guid}", nil, admin_headers }
        end
      end
    end
  end

  describe 'POST /v3/buildpacks/:guid/upload' do
    let(:buildpack) { VCAP::CloudController::Buildpack.make }

    before do
      allow_any_instance_of(VCAP::CloudController::BuildpackUploadMessage).to receive(:valid?).and_return(true)
    end

    it 'enqueues a job to process the uploaded bits' do
      file_upload_params = {
        bits_name: 'buildpack.zip',
        bits_path: 'tmpdir/buildpack.zip',
      }

      expect(Delayed::Job.count).to eq 0

      post "/v3/buildpacks/#{buildpack.guid}/upload", file_upload_params.to_json, admin_headers

      expect(Delayed::Job.count).to eq 1

      expect(last_response.status).to eq(202)

      get last_response.headers['Location'], nil, admin_headers

      expect(last_response.status).to eq(200)
    end
  end

  describe 'PATCH /v3/buildpacks/:guid' do
    let(:buildpack) { VCAP::CloudController::Buildpack.make }

    it 'updates a buildpack' do
      params = { enabled: false }

      patch "/v3/buildpacks/#{buildpack.guid}", params.to_json, admin_headers

      expect(parsed_response['enabled']).to eq(false)
      expect(last_response.status).to eq(200)
      expect(buildpack.reload).to_not be_enabled
    end
  end
end
