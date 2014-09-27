require 'perpetuity'
require 'moped'
require 'perpetuity/mongodb/query'
require 'perpetuity/mongodb/nil_query'
require 'perpetuity/mongodb/index'
require 'perpetuity/mongodb/serializer'
require 'set'
require 'perpetuity/exceptions/duplicate_key_error'
require 'perpetuity/attribute'

module Perpetuity
  class MongoDB
    attr_accessor :host, :port, :db, :pool_size, :username, :password

    def initialize options
      @host       = options.fetch(:host, 'localhost')
      @port       = options.fetch(:port, 27017)
      @db         = options.fetch(:db)
      @pool_size  = options.fetch(:pool_size, 5)
      @username   = options[:username]
      @password   = options[:password]
      @session    = nil
      @indexes    = Hash.new { |hash, key| hash[key] = active_indexes(key) }
      @connected  = false
    end

    def session
      @session ||= Moped::Session.new(["#{host}:#{port}"]).with(safe: true)
    end

    def connect
      session.login(@username, @password) if @username and @password
      @connected = true
      session
    end

    def connected?
      !!@connected
    end

    def database
      session.use db
      connect unless connected?
      session
    end

    def collection klass
      database[klass.to_s]
    end

    def insert klass, objects, _
      if objects.is_a? Array
        objects.each do |object|
          object[:_id] = object.delete('id') || BSON::ObjectId.new
        end

        collection(klass).insert objects
        objects.map { |object| object[:_id] }
      else
        insert(klass, [objects], _).first
      end

    rescue Moped::Errors::OperationFailure => e
      if e.message =~ /duplicate key/
        e.message =~ /\$(\w+)_\d.*dup key: { : (.*) }/
        key = $1
        value = $2.gsub("\\\"", "\"")
        raise DuplicateKeyError, "Tried to insert #{klass} with duplicate unique index: #{key} => #{value}"
      end
    end

    def count klass, criteria=nil_query, &block
      q = block_given? ? query(&block).to_db : criteria.to_db
      collection(klass).find(q).count
    end

    def delete_all klass
      collection(klass.to_s).find.remove_all
    end

    def first klass
      document = collection(klass.to_s).find.limit(1).first
      document[:id] = document.delete("_id")

      document
    end

    def retrieve klass, criteria, options = {}
      # MongoDB uses '_id' as its ID field.
      criteria = to_bson_id(criteria.to_db)

      skipped = options.fetch(:skip) { 0 }

      query = collection(klass.to_s)
                .find(criteria)
                .skip(skipped)
                .limit(options[:limit])

      sort(query, options).map do |document|
        document[:id] = document.delete("_id")
        document
      end
    end

    def increment klass, id, attribute, count=1
      find(klass, id).update '$inc' => { attribute => count }
    end

    def find klass, id
      collection(klass).find(to_bson_id(_id: id))
    end

    def to_bson_id criteria
      criteria = criteria.dup

      # Check for both string and symbol ID in criteria
      if criteria.has_key?('id')
        criteria['_id'] = ObjectId(criteria['id']) rescue criteria['id']
        criteria.delete 'id'
      end

      if criteria.has_key?(:id)
        criteria[:_id] = ObjectId(criteria[:id]) rescue criteria[:id]
        criteria.delete :id
      end

      if criteria[:_id].is_a?(String) and !criteria[:_id].empty?
        criteria[:_id] = BSON::ObjectId.from_string(criteria[:_id])
      elsif criteria[:id].is_a?(String) and !criteria[:id].empty?
        criteria['_id'] = BSON::ObjectId.from_string(criteria['_id'])
      end

      criteria
    end

    def sort query, options
      return query unless options[:attribute] &&
                          options[:direction]

      sort_orders = { ascending: 1, descending: -1 }
      sort_field = options[:attribute]
      sort_direction = options[:direction]
      sort_criteria = { sort_field => sort_orders[sort_direction] }
      query.sort(sort_criteria)
    end

    def all klass
      retrieve klass, nil_query, {}
    end

    def delete ids, klass
      ids = Array(ids)
      if ids.one?
        collection(klass.to_s).find("_id" => ids.first).remove
      elsif ids.none?
        # Nothing to delete
      else
        collection(klass.to_s).find("_id" => { "$in" => ids }).remove_all
      end
    end

    def update klass, id, new_data
      find(klass, id).update('$set' => new_data)
    end

    def can_serialize? value
      serializable_types.include? value.class
    end

    def drop_collection to_be_dropped
      collection(to_be_dropped.to_s).drop
    end

    def query &block
      Query.new(&block)
    end

    def nil_query
      NilQuery.new
    end

    def negate_query &block
      Query.new(&block).negate
    end

    def index klass, attribute, options={}
      @indexes[klass] ||= Set.new

      index = Index.new(klass, attribute, options)
      @indexes[klass] << index
      index
    end

    def indexes klass
      @indexes[klass]
    end

    def active_indexes klass
      collection(klass).indexes.map do |index|
        key = index['key'].keys.first
        direction = index['key'][key]
        unique = index['unique']
        Index.new(klass, Attribute.new(key), order: Index::KEY_ORDERS[direction], unique: unique)
      end.to_set
    end

    def activate_index! index
      attribute = index.attribute.to_s
      order = index.order == :ascending ? 1 : -1
      unique = index.unique?

      collection(index.collection).indexes.create({attribute => order}, unique: unique)
      index.activate!
    end

    def remove_index index
      coll = collection(index.collection)
      db_indexes = coll.indexes.select do |db_index|
        db_index['name'] =~ /\A#{index.attribute}/
      end.map { |idx| idx['key'] }

      if db_indexes.any?
        collection(index.collection).indexes.drop db_indexes.first
      end
    end

    def serialize object, mapper
      Serializer.new(mapper).serialize object
    end

    def serialize_changed_attributes object, original, mapper
      Serializer.new(mapper).serialize_changes object, original
    end

    def unserialize data, mapper
      Serializer.new(mapper).unserialize data
    end

    private
    def serializable_types
      @serializable_types ||= [NilClass, TrueClass, FalseClass, Fixnum, Float, String, Array, Hash, Time]
    end
  end
end
