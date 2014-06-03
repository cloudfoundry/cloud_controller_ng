require "spec_helper"

module VCAP::CloudController
  describe RestController::PreloadedObjectSerializer do
    describe '#serialize' do
      module TestModel
        def checked_transaction(*args, &blk); true; end
        def save(*args, &blk);   true; end
        def update(*args, &blk); true; end
      end

      class Wheel < Sequel::Model
        include TestModel
        attr_accessor :id, :car_id

        one_to_many :bolts, clearer: ->(*args){  }

        export_attributes :attr

        def guid;       "wheel-guid";       end
        def created_at; "wheel-created-at"; end

        def attr; "wheel-attr"; end
      end

      class Engine < Sequel::Model
        include TestModel
        attr_accessor :id, :car_id

        def guid;       "engine-guid";       end
        def created_at; "engine-created-at"; end

        def attr; "engine-attr"; end
      end

      class Keycode < Sequel::Model
        include TestModel
        attr_accessor :id, :car_id

        def guid;       "keycode-guid";       end
        def created_at; "keycode-created-at"; end

        def attr; "keycode-attr"; end
      end

      class Bolt < Sequel::Model
        include TestModel
        attr_accessor :id, :car_id, :wheel_id

        export_attributes :attr

        def guid;       "bolt-guid";       end
        def created_at; "bolt-created-at"; end

        def attr; "bolt-attr"; end
      end

      class Car < Sequel::Model
        include TestModel
        attr_accessor :id

        # Clearers are defined to avoid db access
        one_to_one :engine
        one_to_many :wheels, clearer: ->(*args){  }

        one_to_one :keycode
        one_to_many :bolts, clearer: ->(*args){  }

        export_attributes :attr1, :attr2

        def guid;       "car-guid";       end
        def created_at; "car-created-at"; end

        def attr1; "car-attr1-value"; end
        def attr2; "car-attr2-value"; end
      end

      class CarsController < RestController::ModelController
        define_attributes do
          to_one :engine
          to_many :wheels

          to_one :keycode, link_only: true
          to_many :bolts, link_only: true
        end
      end

      class WheelsController < RestController::ModelController;
        define_attributes do
          to_many :bolts
        end
      end

      class EnginesController < RestController::ModelController; end
      class KeycodesController < RestController::ModelController; end
      class BoltsController < RestController::ModelController; end

      let(:controller_class) { CarsController }
      let(:car) { Car.new.tap { |c| c.set_values(id: 1) } }
      let(:opts) { {} }

      it 'serializes the main object' do
        car.engine = nil
        car.keycode = nil
        hash = subject.serialize(controller_class, car, opts)
        expect(hash).to eql(
          'metadata' => {
            'guid' => 'car-guid',
            'url' => '/v2/cars/car-guid',
            'created_at' => 'car-created-at',
          },
          'entity' => {
            'attr1' => 'car-attr1-value',
            'attr2' => 'car-attr2-value',
            'wheels_url' => '/v2/cars/car-guid/wheels',
            'bolts_url' => '/v2/cars/car-guid/bolts',
          }
        )
      end

      describe 'to_one relationship' do
        before { car.remove_all_wheels }

        it 'includes to_one relationship link when association is set' do
          car.keycode = nil
          car.engine = Engine.new.tap { |e| e.set_values(id: 1) }
          hash = subject.serialize(controller_class, car, opts)
          expect(hash.fetch('entity').fetch('engine_url')).to eql('/v2/engines/engine-guid')
        end

        it 'does not include to_one relationship link when association content is nil' do
          car.keycode = nil
          car.engine = nil
          hash = subject.serialize(controller_class, car, opts)
          expect(hash.fetch('entity')).to_not have_key('engine_url')
        end

        it 'includes the association content when link_only is not specified' do
          car.keycode = nil
          car.engine = Engine.new.tap { |e| e.set_values(id: 1) }
          hash = subject.serialize(controller_class, car, opts.merge(inline_relations_depth: 1))
          expect(hash.fetch('entity').fetch('engine_url')).to be
          expect(hash.fetch('entity').fetch('engine')).to be
        end

        it 'does not include the association content when link_only is specified' do
          car.engine = nil
          car.keycode = Keycode.new.tap { |k| k.set_values(id: 1) }
          hash = subject.serialize(controller_class, car, opts.merge(inline_relations_depth: 1))
          expect(hash.fetch('entity').fetch('keycode_url')).to be
          expect(hash.fetch('entity')).to_not have_key('keycode')
        end

        it 'raises NotLoadedAssociationError when association is not loaded and will be included' +
           'so that this object is not responsible for checking authorization' do
          car.keycode = nil
          expect {
            subject.serialize(controller_class, car, opts)
          }.to raise_error(described_class::NotLoadedAssociationError, /engine.*Car/)
        end
      end

      describe 'to_many relationship' do
        before { car.engine = nil; car.keycode = nil }

        it 'includes to_many relationship link when association is set' do
          car.remove_all_bolts
          car.add_wheel(Wheel.new.tap { |w| w.set_values(id: 1) })
          hash = subject.serialize(controller_class, car, opts)
          expect(hash.fetch('entity').fetch('wheels_url')).to eql('/v2/cars/car-guid/wheels')
        end

        it 'includes to_many relationship link when association content is nil' do
          car.remove_all_bolts
          car.remove_all_wheels
          hash = subject.serialize(controller_class, car, opts)
          expect(hash.fetch('entity').fetch('wheels_url')).to eql('/v2/cars/car-guid/wheels')
        end

        it 'includes the association content when link_only is not specified' do
          car.remove_all_bolts
          car.remove_all_wheels
          car.add_wheel(Wheel.new.tap { |w| w.set_values(id: 1) })
          hash = subject.serialize(controller_class, car, opts.merge(inline_relations_depth: 1))
          expect(hash.fetch('entity').fetch('wheels_url')).to be
          expect(hash.fetch('entity').fetch('wheels')).to be
        end

        it 'does not include the association content when link_only is specified' do
          car.remove_all_wheels
          car.add_bolt(Bolt.new.tap { |k| k.set_values(id: 1) })
          hash = subject.serialize(controller_class, car, opts.merge(inline_relations_depth: 1))
          expect(hash.fetch('entity').fetch('bolts_url')).to be
          expect(hash.fetch('entity')).to_not have_key('bolts')
        end

        it 'raises NotLoadedAssociationError when association is not loaded and will be included' +
           'so that this object is not responsible for checking authorization' do
          expect {
            subject.serialize(controller_class, car, opts.merge(inline_relations_depth: 1))
          }.to raise_error(described_class::NotLoadedAssociationError, /wheels.*Car/)
        end
      end

      it 'serializes related inline objects inline' do

      end

      it 'serializes related inline objects inline transitively' do
        car.engine = nil
        car.keycode = nil

        wheel = Wheel.new.tap { |w| w.set_values(id: 1) }
        car.remove_all_wheels
        car.add_wheel(wheel)

        bolt = Bolt.new.tap { |w| w.set_values(id: 1) }
        wheel.remove_all_bolts
        wheel.add_bolt(bolt)

        hash = subject.serialize(controller_class, car, opts.merge(inline_relations_depth: 2))
        expect(hash.fetch('entity').fetch('wheels')).to eql([
          'metadata' => {
            'guid' => 'wheel-guid',
            'url' => '/v2/wheels/wheel-guid',
            'created_at' => 'wheel-created-at',
          },
          'entity' => {
            'attr' => 'wheel-attr',
            'bolts_url' => '/v2/wheels/wheel-guid/bolts',
            'bolts' => [{
              'metadata' => {
                'guid' => 'bolt-guid',
                'url' => '/v2/bolts/bolt-guid',
                'created_at' => 'bolt-created-at',
              },
              'entity' => {
                'attr' => 'bolt-attr',
              },
            }]
          }
        ])
      end
    end
  end
end
