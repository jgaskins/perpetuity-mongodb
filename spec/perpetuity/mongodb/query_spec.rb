require 'perpetuity/mongodb/query'

module Perpetuity
  describe MongoDB::Query do
    let(:query) { MongoDB::Query }

    it 'generates Mongo equality expressions' do
      expect(query.new{ |user| user.name == 'Jamie' }.to_db).to be == {name: 'Jamie'}
    end

    it 'generates Mongo less-than expressions' do
      expect(query.new{ |v| v.quantity < 10 }.to_db).to be == {quantity: { '$lt' => 10}}
    end

    it 'generates Mongo less-than-or-equal expressions' do
      expect(query.new{ |v| v.quantity <= 10 }.to_db).to be == {quantity: { '$lte' => 10}}
    end

    it 'generates Mongo greater-than expressions' do
      expect(query.new{ |v| v.quantity > 10 }.to_db).to be == {quantity: { '$gt' => 10}}
    end

    it 'generates Mongo greater-than-or-equal expressions' do
      expect(query.new{ |v| v.quantity >= 10 }.to_db).to be == {quantity: { '$gte' => 10}}
    end

    it 'generates Mongo inequality expressions' do
      expect(query.new{ |user| user.name.not_equal? 'Jamie' }.to_db).to be == {
        name: {'$ne' => 'Jamie'}
      }
    end

    it 'generates Mongo regexp expressions' do
      expect(query.new{ |user| user.name =~ /Jamie/ }.to_db).to be == {name: /Jamie/}
    end

    describe 'negated queries' do
      it 'negates an equality query' do
        q = query.new { |user| user.name == 'Jamie' }
        expect(q.negate.to_db).to be == { name: { '$ne' => 'Jamie' } }
      end

      it 'negates a not-equal query' do
        q = query.new { |account| account.balance != 10 }
        expect(q.negate.to_db).to be == { balance: { '$not' => { '$ne' => 10 } } }
      end

      it 'negates a less-than query' do
        q = query.new { |account| account.balance < 10 }
        expect(q.negate.to_db).to be == { balance: { '$not' => { '$lt' => 10 } } }
      end

      it 'negates a less-than-or-equal query' do
        q = query.new { |account| account.balance <= 10 }
        expect(q.negate.to_db).to be == { balance: { '$not' => { '$lte' => 10 } } }
      end

      it 'negates a greater-than query' do
        q = query.new { |account| account.balance > 10 }
        expect(q.negate.to_db).to be == { balance: { '$not' => { '$gt' => 10 } } }
      end

      it 'negates a greater-than-or-equal query' do
        q = query.new { |account| account.balance >= 10 }
        expect(q.negate.to_db).to be == { balance: { '$not' => { '$gte' => 10 } } }
      end

      it 'negates a regex query' do
        q = query.new { |account| account.name =~ /Jamie/ }
        expect(q.negate.to_db).to be == { name: { '$not' => /Jamie/ } }
      end

      it 'negates a inclusion query' do
        q = query.new { |article| article.tags.in ['tag1', 'tag2'] }
        expect(q.negate.to_db).to be == { tags: { '$not' => { '$in' => ['tag1', 'tag2'] } } }
      end
    end
  end
end
