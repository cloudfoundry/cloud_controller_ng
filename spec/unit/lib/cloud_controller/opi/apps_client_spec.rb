require 'spec_helper'
require 'kubernetes/eirini_client'
require 'cloud_controller/opi/apps_client'
require 'cloud_controller/opi/apps_rest_client'

RSpec.describe(OPI::KubernetesClient) do
  let(:opi_url) { 'http://opi.service.cf.internal:8077' }
  let(:eirini_kube_client) { double(Kubernetes::EiriniClient) }
  let(:opi_apps_client) { double(OPI::Client) }
  let(:config) do
    TestConfig.override(
      opi: {
        url: opi_url
      },
      kubernetes: {
        host_url: 'https://kubernetes.example.com',
        workloads_namespace: 'cf-workloads',
      }
    )
  end

  describe '#desire_app' do
    subject(:client) { described_class.new(config, eirini_kube_client, opi_apps_client) }
    let(:img_url) { 'http://example.org/image1234' }
    let(:droplet) { VCAP::CloudController::DropletModel.make(
      lifecycle_type,
      state: VCAP::CloudController::DropletModel::STAGED_STATE,
      docker_receipt_image: 'http://example.org/image1234',
      docker_receipt_username: 'docker-user',
      docker_receipt_password: 'docker-password',
      droplet_hash: 'd_haash',
      guid: 'some-droplet-guid',
    )
    }
    let(:routing_info) {
      instance_double(VCAP::CloudController::Diego::Protocol::RoutingInfo)
    }

    let(:lifecycle_type) { :kpack }
    let(:org) { ::VCAP::CloudController::Organization.make(guid: 'org-guid', name: 'org-name') }
    let(:space) { ::VCAP::CloudController::Space.make(guid: 'space-guid', name: 'space-name', organization: org) }
    let(:app_model) {
      ::VCAP::CloudController::AppModel.make(lifecycle_type,
                                             guid: 'app-guid',
                                             name: 'app-name',
                                             droplet: droplet,
                                             enable_ssh: false,
                                             space: space,
                                             environment_variables: { BISH: 'BASH', FOO: 'BAR' })
    }

    let(:lrp) do
      lrp = ::VCAP::CloudController::ProcessModel.make(:process,
        app:                  app_model,
        state:                'STARTED',
        diego:                false,
        guid:                 'process-guid',
        type:                 'web',
        health_check_timeout: 12,
        instances:            21,
        memory:               128,
        disk_quota:           256,
        ports:                [8080],
        command:              'ls -la',
        file_descriptors:     32,
        health_check_type:    'port',
        enable_ssh:           false,
      )
      lrp.this.update(updated_at: Time.at(2))
      lrp.reload
    end

    context 'when request executes successfully' do
      let(:egress_rules) { instance_double(VCAP::CloudController::Diego::EgressRules) }
      let(:protobuf_rules) {
        [
          ::Diego::Bbs::Models::SecurityGroupRule.new({
            protocol:      'udp',
            ports:         [8080],
            destinations:  ['1.2.3.4'],
          }),
          ::Diego::Bbs::Models::SecurityGroupRule.new({
            protocol:     'tcp',
            port_range:   { 'start' => 9090, 'end' => 9095 },
            destinations: ['5.6.7.8'],
            log:          true,
         }),
        ]
      }

      before do
        routes = {
              'http_routes' => [
                {
                  'hostname'          => 'numero-uno.example.com',
                  'port'              => 8080
                },
                {
                  'hostname'          => 'numero-dos.example.com',
                  'port'              => 7777
                }
              ]
        }

        allow(routing_info).to receive(:routing_info).and_return(routes)
        allow(VCAP::CloudController::Diego::Protocol::RoutingInfo).to receive(:new).with(lrp).and_return(routing_info)
        allow(VCAP::CloudController::IsolationSegmentSelector).to receive(:for_space).and_return('placement-tag')
        allow(VCAP::CloudController::Diego::EgressRules).to receive(:new).and_return(egress_rules)
        allow(egress_rules).to receive(:running_protobuf_rules).and_return(protobuf_rules)
        allow(eirini_kube_client).to receive(:create_lrp)
      end

      let(:expected_lrp) {
        Kubeclient::Resource.new({
          metadata: {
            name: 'app-name',
            namespace: 'cf-workloads',
          },
          spec: {
            GUID: 'process-guid',
            version: lrp.version.to_s,
            processType: 'web',
            appGUID: 'app-guid',
            appName: 'app-name',
            spaceGUID: 'space-guid',
            spaceName: 'space-name',
            orgGUID: 'org-guid',
            orgName: 'org-name',
            command: ['/cnb/lifecycle/launcher', 'ls -la'],
            image: 'http://example.org/image1234',
            env: {
              BISH: 'BASH',
              FOO: 'BAR',
              VCAP_APPLICATION: %{
                  {
                    "cf_api": "http://api2.vcap.me",
                    "limits": {
                      "fds": 32,
                      "mem": 128,
                      "disk": 256
                     },
                    "application_name": "#{app_model.name}",
                    "application_uris":[],
                    "name": "#{app_model.name}",
                    "space_name": "#{lrp.space.name}",
                    "space_id": "#{lrp.space.guid}",
                    "organization_id": "#{lrp.space.organization_guid}",
                    "organization_name": "#{lrp.space.organization.name}",
                    "uris": [],
                    "process_id": "#{lrp.guid}",
                    "process_type": "#{lrp.type}",
                    "application_id": "#{app_model.guid}",
                    "version": "#{lrp.version}",
                    "application_version": "#{lrp.version}"
                  }}.delete(' ').delete("\n"),
              MEMORY_LIMIT: '128m',
              VCAP_SERVICES: '{}',
              PORT: '8080',
              VCAP_APP_PORT: '8080',
              VCAP_APP_HOST: '0.0.0.0'
            },
            instances: 21,
            memoryMB: 128,
            cpuWeight: 1,
            diskMB: 256,
            health: {
              type: 'port',
              timeoutMs: 12000,
              port: 8080,
            },
            lastUpdated: '2.0',
            volumeMounts: [],
            ports: [8080],
            appRoutes: [
              {
                hostname: 'numero-uno.example.com',
                port: 8080
              },
              {
                hostname: 'numero-dos.example.com',
                port: 7777
              }
            ],
            userDefinedAnnotations: {}
          },
        })
      }

      it 'creates an LRP custom resource' do
        subject.desire_app(lrp)

        expect(eirini_kube_client).to have_received(:create_lrp).with(expected_lrp)
      end

      context 'when the app has annotations' do
        before do
          ::VCAP::CloudController::AppAnnotationModel.create(
            resource_guid: app_model.guid,
            key: 'namespace',
            value: 'secret-namespace'
          )
          ::VCAP::CloudController::AppAnnotationModel.create(
            resource_guid: app_model.guid,
            key_prefix: 'prometheus.io',
            key: 'port',
            value: '6666'
          )
          ::VCAP::CloudController::AppAnnotationModel.create(
            resource_guid: app_model.guid,
            key_prefix: 'the_prometheus.io',
            key: 'blah',
            value: 'whatever'
          )
        end

        it 'propagates only those that start with prometheus.io' do
          subject.desire_app(lrp)

          expect(eirini_kube_client).to have_received(:create_lrp) do |actual_lrp|
            expect(actual_lrp.spec.userDefinedAnnotations).to eq(Kubeclient::Resource.new({ 'prometheus.io/port' => '6666' }))
          end
        end
      end

      context 'when droplet has a docker lifecycle' do
        let(:lifecycle_type) { :docker }

        it 'configures a private registry in the desired LRP' do
          subject.desire_app(lrp)

          expect(eirini_kube_client).to have_received(:create_lrp) do |actual_lrp|
            expect(actual_lrp.spec.privateRegistry).to include(username: 'docker-user', password: 'docker-password')
          end
        end

        it 'sets the image URL' do
          subject.desire_app(lrp)

          expect(eirini_kube_client).to have_received(:create_lrp) do |actual_lrp|
            expect(actual_lrp.spec.image).to eq('http://example.org/image1234')
          end
        end

        it 'sets the command' do
          subject.desire_app(lrp)

          expect(eirini_kube_client).to have_received(:create_lrp) do |actual_lrp|
            expect(actual_lrp.spec.command).to eq(['/bin/sh', '-c', 'ls -la'])
          end
        end

        context 'when volume mounts are provided' do
          let(:service_instance) { ::VCAP::CloudController::ManagedServiceInstance.make space: app_model.space }
          let(:multiple_volume_mounts) do
            [
              {
                container_dir: '/data/images',
                mode:          'r',
                device_type:   'shared',
                driver:        'cephfs',
                device:        {
                  volume_id:    'abc',
                  mount_config: {
                    name: 'volume-one',
                    key: 'value'
                  }
                }
              },
              {
                container_dir: '/data/pictures',
                mode:          'r',
                device_type:   'shared',
                driver:        'cephfs',
                device:        {
                  volume_id:    'abc',
                  mount_config: {
                    key: 'value'
                  }
                }
              },
              {
                container_dir: '/data/scratch',
                mode:          'rw',
                device_type:   'shared',
                driver:        'local',
                device:        {
                  volume_id:    'def'
                }
              }
            ]
          end

          let(:binding) { ::VCAP::CloudController::ServiceBinding.make(app: app_model, service_instance: service_instance, volume_mounts: multiple_volume_mounts) }
          let(:creds) {
            system_env = SystemEnvPresenter.new([binding]).system_env
            service_details = system_env[:VCAP_SERVICES][:"#{service_instance.service.label}"]
            service_credentials = service_details[0].to_hash[:credentials]
            service_credentials
          }

          it 'configures the volume mounts and VCAP_SERVICES env var' do
            creds_json = MultiJson.dump(creds)
            vcap_services = %{{"#{service_instance.service.label}":[{
              "label": "#{service_instance.service.label}",
              "provider": null,
              "plan": "#{service_instance.service_plan.name}",
              "name": "#{service_instance.name}",
              "tags": [],
              "instance_guid": "#{service_instance.guid}",
              "instance_name": "#{service_instance.name}",
              "binding_guid": "#{binding.guid}",
              "binding_name": null,
              "credentials": #{creds_json},
              "syslog_drain_url": null,
              "volume_mounts": [
                {
                  "container_dir": "/data/images",
                  "mode": "r",
                  "device_type": "shared"
                },
                {
                  "container_dir": "/data/pictures",
                  "mode": "r",
                  "device_type": "shared"
                },
                {
                  "container_dir": "/data/scratch",
                  "mode": "rw",
                  "device_type": "shared"
                }
              ]
            }]}}.delete(' ').delete("\n")

            subject.desire_app(lrp)

            expect(eirini_kube_client).to have_received(:create_lrp) do |actual_lrp|
              expect(actual_lrp.spec.env['VCAP_SERVICES']).to eq(vcap_services)
              expect(actual_lrp.spec.volumeMounts.length).to eq(1)
              expect(actual_lrp.spec.volumeMounts.first).to include(claimName: 'volume-one', mountPath: '/data/images')
            end
          end
        end
      end

      context 'when the process has a detected start command' do
        let(:lrp) do
          lrp = ::VCAP::CloudController::ProcessModel.make(
            :process,
            app:                  app_model,
            state:                'STARTED',
            diego:                false,
            guid:                 'process-guid',
            type:                 'web',
            health_check_timeout: 12,
            instances:            21,
            memory:               128,
            disk_quota:           256,
            file_descriptors:     32,
            health_check_type:    'port',
            enable_ssh:           false,
          )
          lrp.this.update(updated_at: Time.at(2))
          lrp.reload
        end

        it 'includes the start command in the LRP request' do
          subject.desire_app(lrp)

          expect(eirini_kube_client).to have_received(:create_lrp) do |actual_lrp|
            expect(actual_lrp.spec).to include(
              image: 'http://example.org/image1234',
              command: ['/cnb/lifecycle/launcher', '$HOME/boot.sh']
            )
          end
        end
      end
    end
  end

  describe '#fetch_scheduling_infos' do
    let(:scheduling_infos) { double }

    before do
      allow(opi_apps_client).to receive('fetch_scheduling_infos').and_return(scheduling_infos)
    end

    subject(:client) { described_class.new(config, eirini_kube_client, opi_apps_client) }

    it 'delegates the call to the opi apps client' do
      actual_scheduling_infos = client.fetch_scheduling_infos
      expect(opi_apps_client).to have_received(:fetch_scheduling_infos)
      expect(actual_scheduling_infos).to eq(scheduling_infos)
    end

    context 'when the rest client raises an error' do
      let(:err) {
        CloudController::Errors::ApiError.new
      }

      before do
        allow(opi_apps_client).to receive(:fetch_scheduling_infos).and_raise(err)
      end

      it 'raises the same error' do
        expect { client.fetch_scheduling_infos }.to raise_error(err)
        expect(opi_apps_client).to have_received(:fetch_scheduling_infos)
      end
    end
  end

  describe '#update_app' do
    subject(:client) { described_class.new(config, eirini_kube_client, opi_apps_client) }

    let(:process) { double }
    let(:existing_lrp) { double }

    before do
      allow(opi_apps_client).to receive('update_app')
    end

    it 'delegates the request to the opi apps client' do
      client.update_app(process, existing_lrp)
      expect(opi_apps_client).to have_received(:update_app).with(process, existing_lrp)
    end

    context 'when the rest client raises an error' do
      let(:err) {
        CloudController::Errors::ApiError.new
      }

      before do
        allow(opi_apps_client).to receive(:update_app).and_raise(err)
      end

      it 'raises the same error' do
        expect { client.update_app(process, existing_lrp) }.to raise_error(err)
        expect(opi_apps_client).to have_received(:update_app).with(process, existing_lrp)
      end
    end
  end

  describe '#get_app' do
    subject(:client) { described_class.new(config, eirini_kube_client, opi_apps_client) }
    let(:process) { double }
    let(:desired_app) { double }

    before do
      allow(opi_apps_client).to receive(:get_app).and_return(desired_app)
    end

    it 'delegates the call to the opi apps client' do
      desired_lrp = client.get_app(process)
      expect(opi_apps_client).to have_received(:get_app).with(process)
      expect(desired_lrp).to eq(desired_lrp)
    end

    context 'when the rest client raises an error' do
      let(:err) {
        CloudController::Errors::ApiError.new
      }

      before do
        allow(opi_apps_client).to receive(:get_app).and_raise(err)
      end

      it 'raises the same error' do
        expect { client.get_app(process) }.to raise_error(err)
        expect(opi_apps_client).to have_received(:get_app).with(process)
      end
    end
  end

  context '#stop_app' do
    let(:versioned_guid) { 'd082417c-c5aa-488c-aaf8-845a580eb11f' }
    subject(:client) { described_class.new(config, eirini_kube_client, opi_apps_client) }

    before do
      allow(opi_apps_client).to receive(:stop_app)
    end

    it 'delegates the call to the opi apps client' do
      client.stop_app(versioned_guid)
      expect(opi_apps_client).to have_received(:stop_app).with(versioned_guid)
    end

    context 'when the rest client raises an error' do
      let(:err) {
        CloudController::Errors::ApiError.new
      }

      before do
        allow(opi_apps_client).to receive(:stop_app).and_raise(err)
      end

      it 'raises the same error' do
        expect { client.stop_app(versioned_guid) }.to raise_error(err)
        expect(opi_apps_client).to have_received(:stop_app).with(versioned_guid)
      end
    end
  end

  context '#stop_index' do
    let(:versioned_guid) { 'd082417c-c5aa-488c-aaf8-845a580eb11f' }
    let(:index) { 1 }
    subject(:client) { described_class.new(config, eirini_kube_client, opi_apps_client) }

    before do
      allow(opi_apps_client).to receive(:stop_index)
    end

    it 'delegates the call to the opi apps client' do
      client.stop_index(versioned_guid, index)
      expect(opi_apps_client).to have_received(:stop_index).with(versioned_guid, index)
    end

    context 'when the rest client raises an error' do
      let(:err) {
        CloudController::Errors::ApiError.new
      }

      before do
        allow(opi_apps_client).to receive(:stop_index).and_raise(err)
      end

      it 'raises the same error' do
        expect { client.stop_index(versioned_guid, index) }.to raise_error(err)
        expect(opi_apps_client).to have_received(:stop_index).with(versioned_guid, index)
      end
    end
  end
end
