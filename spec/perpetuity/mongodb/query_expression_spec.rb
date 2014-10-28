require 'perpetuity/mongodb/query_expression'

module Perpetuity
  describe MongoDB::QueryExpression do
    let(:expression) { MongoDB::QueryExpression.new :attribute, :equals, :value }

    describe 'translation to Mongo expressions' do
      it 'equality expression' do
        expect(expression.to_db).to be == { attribute: :value }
      end

      it 'less-than expression' do
        expression.comparator = :less_than
        expect(expression.to_db).to be == { attribute: { '$lt' => :value } }
      end

      it 'less-than-or-equal-to expression' do
        expression.comparator = :lte
        expect(expression.to_db).to be == { attribute: { '$lte' => :value } }
      end

      it 'greater-than expression' do
        expression.comparator = :greater_than
        expect(expression.to_db).to be == { attribute: { '$gt' => :value } }
      end

      it 'greater-than-or-equal-to expression' do
        expression.comparator = :gte
        expect(expression.to_db).to be == { attribute: { '$gte' => :value } }
      end

      it 'not-equal' do
        expression.comparator = :not_equal
        expect(expression.to_db).to be == { attribute: { '$ne' => :value } }
      end

      it 'checks for inclusion' do
        expression.comparator = :in
        expect(expression.to_db).to be == { attribute: { '$in' => :value } }
      end

      it 'checks for regexp matching' do
        expression.comparator = :matches
        expect(expression.to_db).to be == { attribute: :value }
      end
    end

    describe 'unions' do
      let(:lhs) { MongoDB::QueryExpression.new :first, :equals, :one }
      let(:rhs) { MongoDB::QueryExpression.new :second, :equals, :two }

      it 'converts | to an $or query' do
        expect((lhs | rhs).to_db).to be == { '$or' => [{first: :one}, {second: :two}] }
      end
    end

    describe 'intersections' do
      let(:lhs) { MongoDB::QueryExpression.new :first, :equals, :one }
      let(:rhs) { MongoDB::QueryExpression.new :second, :equals, :two }

      it 'converts & to an $and query' do
        expect((lhs & rhs).to_db).to be == { '$and' => [{first: :one}, {second: :two}] }
      end
    end
  end
end
