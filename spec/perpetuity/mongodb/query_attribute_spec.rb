require 'perpetuity/mongodb/query_attribute'

module Perpetuity
  describe MongoDB::QueryAttribute do
    let(:attribute) { MongoDB::QueryAttribute.new :attribute_name }

    it 'stores the attribute name' do
      expect(attribute.name).to be == :attribute_name
    end

    it 'allows checking subattributes' do
      expect(attribute.title.name).to be == :'attribute_name.title'
    end

    it 'wraps .id subattribute in metadata' do
      expect(attribute.id.name).to be == :'attribute_name.__metadata__.id'
    end

    it 'wraps .klass subattribute in metadata' do
      expect(attribute.klass.name).to be == :'attribute_name.__metadata__.class'
    end

    it 'checks for equality' do
      expect(attribute == 1).to be_a MongoDB::QueryExpression
    end

    it 'checks for less than' do
      expect(attribute < 1).to be_a MongoDB::QueryExpression
    end

    it 'checks for <=' do
      expect(attribute <= 1).to be_a MongoDB::QueryExpression
    end

    it 'checks for greater than' do
      expect(attribute > 1).to be_a MongoDB::QueryExpression
    end

    it 'checks for >=' do
      expect(attribute >= 1).to be_a MongoDB::QueryExpression
    end

    it 'checks for inequality' do
      expect(attribute != 1).to be_a MongoDB::QueryExpression
    end

    it 'checks for regexp matches' do
      expect(attribute =~ /value/).to be_a MongoDB::QueryExpression
    end

    it 'checks for inclusion' do
      expect(attribute.in [1, 2, 3]).to be_a MongoDB::QueryExpression
    end

    it 'checks for existence in an array' do
      expect(attribute.any?.to_db).to be == { attribute_name: { '$ne' => [] } }
    end

    it 'checks for nonexistence in an array' do
      expect(attribute.none?.to_db).to be == { attribute_name: [] }
    end

    it 'checks for its own truthiness' do
      expect(attribute.to_db).to be == ((attribute != false) & (attribute != nil)).to_db
    end
  end
end
