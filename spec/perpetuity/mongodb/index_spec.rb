require 'perpetuity/mongodb/index'

module Perpetuity
  class MongoDB
    describe Index do
      let(:attribute) { double(name: 'name') }
      let(:index) { Index.new(Object, attribute) }

      it 'is not active by default' do
        expect(index).not_to be_active
      end

      it 'can be activated' do
        index.activate!
        expect(index).to be_active
      end

      it 'can be unique' do
        index = Index.new(Object, attribute, unique: true)
        expect(index).to be_unique
      end

      it 'is not unique by default' do
        expect(index).not_to be_unique
      end

      describe 'index ordering' do
        it 'can be ordered in ascending order' do
          index = Index.new(Object, attribute, order: :ascending)
          expect(index.order).to be :ascending
        end

        it 'is ordered ascending by default' do
          expect(index.order).to be :ascending
        end

        it 'can be ordered in descending order' do
          index = Index.new(Object, attribute, order: :descending)
          expect(index.order).to be :descending
        end
      end
    end
  end
end
