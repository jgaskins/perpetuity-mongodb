require 'perpetuity/mongodb'
require 'date'

module Perpetuity
  describe MongoDB do
    let(:mongo) { MongoDB.new db: 'perpetuity_gem_test' }
    let(:klass) { String }

    it 'is not connected when instantiated' do
      expect(mongo).not_to be_connected
    end

    it 'connects to its host' do
      mongo.connect
      expect(mongo).to be_connected
    end

    it 'connects automatically when accessing the database' do
      mongo.database
      expect(mongo).to be_connected
    end

    describe 'initialization params' do
      let(:host)      { double('host') }
      let(:port)      { double('port') }
      let(:db)        { double('db') }
      let(:pool_size) { double('pool size') }
      let(:username)  { double('username') }
      let(:password)  { double('password') }
      let(:mongo) do
        MongoDB.new(
          host:      host,
          port:      port,
          db:        db,
          pool_size: pool_size,
          username:  username,
          password:  password
        )
      end

      it 'assigns the host' do
        expect(mongo.host).to be == host
      end

      it 'assigns the port' do
        expect(mongo.port).to be == port
      end

      it 'assigns the db' do
        expect(mongo.db).to be == db
      end

      it 'assigns the pool_size' do
        expect(mongo.pool_size).to be == pool_size
      end

      it 'assigns the username' do
        expect(mongo.username).to be == username
      end

      it 'assigns the password' do
        expect(mongo.password).to be == password
      end
    end

    it 'inserts documents into a collection' do
      expect { mongo.insert klass, { name: 'foo' }, [] }.to change { mongo.count klass }.by 1
    end

    it 'inserts multiple documents into a collection' do
      expect { mongo.insert klass, [{name: 'foo'}, {name: 'bar'}], [] }
        .to change { mongo.count klass }.by 2
    end

    it 'removes all documents from a collection' do
      mongo.insert klass, {}, []
      mongo.delete_all klass
      expect(mongo.count(klass)).to be == 0
    end

    it 'counts the documents in a collection' do
      mongo.delete_all klass
      3.times do
        mongo.insert klass, {}, []
      end
      expect(mongo.count(klass)).to be == 3
    end

    it 'counts the documents matching a query' do
      mongo.delete_all klass
      1.times { mongo.insert klass, { name: 'bar' }, [] }
      3.times { mongo.insert klass, { name: 'foo' }, [] }
      expect(mongo.count(klass) { |o| o.name == 'foo' }).to be == 3
    end

    it 'gets the first document in a collection' do
      value = {value: 1}
      mongo.insert klass, value, []
      expect(mongo.first(klass)[:hypothetical_value]).to be == value['value']
    end

    it 'gets all of the documents in a collection' do
      values = [{value: 1}, {value: 2}]
      allow(mongo).to receive(:retrieve)
        .with(Object, mongo.nil_query, {})
        .and_return(values)

      expect(mongo.all(Object)).to be == values
    end

    it 'retrieves by id if the id is a string' do
      time = Time.now.utc
      id = mongo.insert Object, {inserted: time}, []

      object = mongo.retrieve(Object, mongo.query{|o| o.id == id.to_s }).first
      retrieved_time = object["inserted"]
      expect(retrieved_time.to_f).to be_within(0.001).of time.to_f
    end

    describe 'serialization' do
      let(:object) { Object.new }
      let(:foo_attribute) { double('Attribute', name: :foo) }
      let(:baz_attribute) { double('Attribute', name: :baz) }
      let(:mapper) { double('Mapper',
                            mapped_class: Object,
                            mapper_registry: {},
                            attribute_set: Set[foo_attribute, baz_attribute],
                            data_source: mongo,
                           ) }

      before do
        object.instance_variable_set :@foo, 'bar'
        object.instance_variable_set :@baz, 'quux'
      end

      it 'serializes objects' do
        expect(mongo.serialize(object, mapper)).to be == {
          'foo' => 'bar',
          'baz' => 'quux'
        }
      end

      it 'can serialize only modified attributes of objects' do
        updated = object.dup
        updated.instance_variable_set :@foo, 'foo'

        serialized = mongo.serialize_changed_attributes(updated, object, mapper)
        expect(serialized).to be == { 'foo' => 'foo' }
      end
    end

    describe 'serializable objects' do
      let(:serializable_values) { [nil, true, false, 1, 1.2, '', [], {}, Time.now] }

      it 'can insert serializable values' do
        serializable_values.each do |value|
          expect(mongo.insert(Object, {value: value}, [])).to be_a Moped::BSON::ObjectId
          expect(mongo.can_serialize?(value)).to be_truthy
        end
      end
    end

    it 'generates a new query DSL object' do
      expect(mongo.query { |object| object.whatever == 1 }).to respond_to :to_db
    end

    describe 'indexing' do
      let(:collection) { Object }
      let(:key) { 'object_id' }

      before { mongo.index collection, key }
      after { mongo.drop_collection collection }

      it 'adds indexes for the specified key on the specified collection' do
        indexes = mongo.indexes(collection).select{ |index| index.attribute == 'object_id' }
        expect(indexes).not_to be_empty
        expect(indexes.first.order).to be :ascending
      end

      it 'adds descending-order indexes' do
        index = mongo.index collection, 'hash', order: :descending
        expect(index.order).to be :descending
      end

      it 'creates indexes on the database collection' do
        mongo.delete_all collection
        index = mongo.index collection, 'real_index', order: :descending, unique: true
        mongo.activate_index! index

        expect(mongo.active_indexes(collection)).to include index
      end

      it 'removes indexes' do
        mongo.drop_collection collection
        index = mongo.index collection, 'real_index', order: :descending, unique: true
        mongo.activate_index! index
        mongo.remove_index index
        expect(mongo.active_indexes(collection)).not_to include index
      end
    end

    describe 'atomic operations' do
      it 'increments the value of an attribute' do
        id = mongo.insert klass, { count: 1 }, []
        mongo.increment klass, id, :count
        mongo.increment klass, id, :count, 10
        query = mongo.query { |o| o.id == id }
        expect(mongo.retrieve(klass, query).first['count']).to be == 12
        mongo.increment klass, id, :count, -1
        expect(mongo.retrieve(klass, query).first['count']).to be == 11
      end
    end

    describe 'operation errors' do
      let(:data) { { foo: 'bar' } }
      let(:index) { mongo.index Object, :foo, unique: true }

      before do
        mongo.delete_all Object
        mongo.activate_index! index
      end

      after { mongo.drop_collection Object }

      it 'raises an exception when insertion fails' do
        mongo.insert Object, data, []

        expect { mongo.insert Object, data, [] }.to raise_error DuplicateKeyError,
          'Tried to insert Object with duplicate unique index: foo => "bar"'
      end
    end
  end
end
