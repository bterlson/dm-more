require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'

if HAS_SQLITE3 || HAS_MYSQL || HAS_POSTGRES
  describe 'DataMapper::Is::List' do

    class User
      include DataMapper::Resource

      property :id, Serial
      property :name, String

      has n, :todos
    end

    class Todo
      include DataMapper::Resource

      property :id, Serial
      property :title, String

      belongs_to :user

      is :list, :scope => [:user_id]
    end
    
    before :each do
      User.auto_migrate!
      Todo.auto_migrate!
      
      @u1 = User.create(:name => "Johnny")
      @u2 = User.create(:name => "Freddy")
    end

    describe '#create' do
      describe 'with an empty list' do
        before do
          @todo = Todo.create(:user => @u1)
        end

        it "should set the first list item to position 1" do
          @todo.position.should == 1
        end
      end

      describe 'with an existing list' do
        before do
          @todo_1 = Todo.create(:user => @u1) 
          @todo_2 = Todo.create(:user => @u1)
        end 

        it "should set the position to be the end of the list" do
          @todo_2.position.should == 2
        end
      end

      describe 'with different scopes' do
        before do
          @todo_1 = Todo.create(:user => @u1)
          @todo_2 = Todo.create(:user => @u2)
        end

        it 'should set the position properly regardless of other scopes' do
          @todo_1.position.should == 1
          @todo_2.position.should == 1
        end
      end
    end

    describe '#update' do
      before do
        @todo_1 = Todo.create(:user => @u1)
        @todo_2 = Todo.create(:user => @u1)
        @todo_3 = Todo.create(:user => @u1)
        @todo_4 = Todo.create(:user => @u2)
        @todo_5 = Todo.create(:user => @u2)
      end

      describe 'when not changing the position' do
        it 'should not change the position' do
          lambda {
            @todo_1.title = "Determine if the cake is a lie"
            @todo_1.save
          }.should_not change(@todo_1, :position)
        end
      end
      
      describe 'when changing the position' do
        it 'should rearrange the list' do
          @todo_1.position = 2
          @todo_1.save
          
          Todo.get(1).position.should == 2
          Todo.get(2).position.should == 1
          Todo.get(3).position.should == 3
        end

        it 'should not affect other scopes' do
          @todo_1.position = 3
          @todo_1.save

          Todo.get(4).position.should == 1
          Todo.get(5).position.should == 2
        end

        it 'should not set the position to be less than the first position' do
          pending
          
          @todo_1.position = -1
          @todo_1.save

          Todo.get(1).position.should == 1
        end

        it 'should not set the position to be greater than the number of items in the list' do
          @todo_3.position = 100
          @todo_3.save

          Todo.get(3).position.should == 3
        end

        it 'should work properly when setting the position multiple times' do
          @todo_3.position = 1
          @todo_3.save

          Todo.get(3).position.should == 1
          Todo.get(1).position.should == 2
          Todo.get(2).position.should == 3

          @todo_3.position = 2
          @todo_3.save

          Todo.get(1).position.should == 1
          Todo.get(3).position.should == 2
          Todo.get(2).position.should == 3
        end
      end

      describe 'when changing the scope' do
        it 'should should detach the list item from its previous list' do
          @todo_1.user = @u2
          @todo_1.save

          Todo.get(2).position.should == 1
          Todo.get(3).position.should == 2
        end

        it 'should move the item to the same position in the new list' do
          @todo_1.user = @u2
          @todo_1.save

          Todo.get(1).position.should == 1
        end

        describe 'when position is empty' do
          it 'should move the item to the bottom of the new list' do
            @todo_1.user = @u2
            @todo_1.position = nil
            @todo_1.save

            Todo.get(1).position.should == 3
          end
        end
      end
    end

    describe '#delete' do
      before do
        @todo_1 = Todo.create(:user => @u1)
        @todo_2 = Todo.create(:user => @u2)
      end

      it 'should detach the deleted item from its list' do
        @todo_1.destroy

        Todo.get(2).position.should == 1
      end
    end

    describe '#move' do
      before do
        @todo_1 = Todo.create(:user => @u1)
        @todo_2 = Todo.create(:user => @u1)
        @todo_3 = Todo.create(:user => @u1)
        @todo_4 = Todo.create(:user => @u2)
        @todo_5 = Todo.create(:user => @u2)
      end

      it 'should return true if the move was successful' do
        @todo_1.move(2).should be_true
      end

      it 'should return false if the move was unsuccessful' do
        @todo_1.move(:below => @todo_5).should be_false
      end
      
      describe 'with a position' do
        it 'should rearrange the list' do
          @todo_1.move(2)
          
          Todo.get(1).position.should == 2
          Todo.get(2).position.should == 1
          Todo.get(3).position.should == 3
        end

        it 'should not affect other scopes' do
          @todo_1.move(3)

          Todo.get(4).position.should == 1
          Todo.get(5).position.should == 2
        end

        it 'should not set the position to be less than the first position' do
          pending

          @todo_1.move(-1)

          Todo.get(1).position.should == 1
        end

        it 'should not set the position to be greater than the number of items in the list' do
          @todo_3.move(20)

          Todo.get(3).position.should == 3
        end

        it 'should work when moving multiple times' do
          @todo_3.move(1)

          Todo.get(3).position.should == 1
          Todo.get(1).position.should == 2
          Todo.get(2).position.should == 3

          @todo_3.move(2)

          Todo.get(1).position.should == 1
          Todo.get(3).position.should == 2
          Todo.get(2).position.should == 3
        end
      end
      
      it 'should move to the highest position' do
        @todo_3.move(:highest)
        
        Todo.get(3).position.should == 1
        Todo.get(1).position.should == 2
        Todo.get(2).position.should == 3
      end

      it 'should move to the lowest position' do
        @todo_1.move(:lowest)

        Todo.get(2).position.should == 1
        Todo.get(3).position.should == 2
        Todo.get(1).position.should == 3
      end

      it 'should move higher/up' do
        @todo_2.move(:up)
              
        Todo.get(2).position.should == 1
        Todo.get(1).position.should == 2
      end

      it 'should move lower/down' do
        @todo_2.move(:lower)

        Todo.get(3).position.should == 2
        Todo.get(2).position.should == 3
      end

      describe 'when moving above a specified item' do
        it 'should adjust the list' do
          @todo_1.move(:above => @todo_3)

          Todo.get(2).position.should == 1
          Todo.get(1).position.should == 2
          Todo.get(3).position.should == 3
        end
        
        it 'should not move above an item in another scope' do
          @todo_1.move(:above => @todo_4)
          
          Todo.get(1).position.should == 1
          Todo.get(2).position.should == 2
          Todo.get(3).position.should == 3
        end
      end

      describe 'when moving below a specified item' do
        it 'should adjust the list' do
          @todo_1.move(:below => @todo_3)
         
          Todo.get(2).position.should == 1
          Todo.get(3).position.should == 2
          Todo.get(1).position.should == 3
        end
        
        it 'should not move below an item in another scope' do
          @todo_1.move(:below => @todo_4)

          Todo.get(1).position.should == 1
          Todo.get(2).position.should == 2
          Todo.get(3).position.should == 3
        end
      end

      describe 'moving to a specific position' do
        it 'should update the position' do
          pending

          # This does not work.
          
          @todo_1.move(:to => 3)
          
          Todo.get(1).position.should == 3
        end

        it 'should rearrange the list' do
          pending

          # This is broken due to 'should update the position'.

          @todo_1.move(:to => 2)
          
          Todo.get(1).position.should == 2
          Todo.get(2).position.should == 1
          Todo.get(3).position.should == 3
        end

        it 'should not set the position to be less than the first position' do
          @todo_1.move(:to => -1)

          Todo.get(1).position.should == 1
        end

        it 'should not set the position to be greater than the number of items in the list' do
          @todo_3.move(:to => 20)

          Todo.get(3).position.should == 3
        end

        it 'should work properly moving multiple times' do
          pending

          # This is broken due to 'should update the position'.

          @todo_3.move(:to => 1)
          
          Todo.get(3).position.should == 1
          Todo.get(1).position.should == 2
          Todo.get(2).position.should == 3
          
          @todo_1.move(:to => 2)
          
          Todo.get(1).position.should == 1
          Todo.get(3).position.should == 2
          Todo.get(2).position.should == 3
        end
      end
    end
    
    describe '#list_scope' do
      describe 'with no scope' do
        class Property
          include DataMapper::Resource
          
          property :id, Serial

          is :list
        end

        before do
          @property = Property.new
        end

        it 'should return an empty hash' do
          @property.list_scope.should == {}
        end

      end

      describe 'with a scope' do
        before do
          @todo_1 = Todo.create(:user => @u1) 
        end

        it 'should know the scope of the list the item belongs to' do
          @todo_1.list_scope.should == {:user_id => @u1.id }
        end
      end
    end

    describe '#original_list_scope' do
      before do
        @todo_1 = Todo.create(:user => @u1)
        @todo_1.user = @u2
      end

      it 'should know the original list scope after the scope changes' do
        @todo_1.original_list_scope.should == {:user_id => @u1.id }
      end
    end

    describe '#list_query' do
      before do
        @todo_1 = Todo.create(:user => @u1)
      end

      it 'should return a hash with conditions to get the entire list this item belongs to' do
        @todo_1.list_query.should == {:user_id => @u1.id, :order => [:position.asc]}
      end
    end

    describe '#list' do
      before do
        @todo_1 = Todo.create(:user => @u1)
        @todo_2 = Todo.create(:user => @u1)
        @todo_3 = Todo.create(:user => @u2)
      end

      describe 'with no arguments' do
        it 'should return all list items in the current list item\'s scope' do
          @todo_1.list.should == [@todo_1, @todo_2]
        end
      end

      describe 'when specifying a scope' do
        it 'should return all items in the specified scope' do
          @todo_1.list({:user_id => @u2.id}).should == [@todo_3]
        end
      end
    end

    describe '#left_sibling' do
      before do
        @todo_1 = Todo.create(:user => @u1)
        @todo_2 = Todo.create(:user => @u1)
      end

      describe "with no left sibling" do
        it 'should return nil' do
          @todo_1.left_sibling.should be_nil
        end
      end


      describe "with a left sibling" do
        it 'should return the list item to the left' do
          @todo_2.left_sibling.should == @todo_1
        end
      end
    end

    describe '#right_sibling' do
      before do
        @todo_1 = Todo.create(:user => @u1)
        @todo_2 = Todo.create(:user => @u1)
      end

      describe 'with no right sibling' do
        it 'should return nil' do
          @todo_2.right_sibling.should be_nil
        end
      end

      describe 'with a right sibling' do
        it 'should return the list item to the right' do
          @todo_1.right_sibling.should == @todo_2
        end
      end
    end

    describe '#detatch' do
      before do
        @todo_1 = Todo.create(:user => @u1)
        @todo_2 = Todo.create(:user => @u1)
        @todo_3 = Todo.create(:user => @u1)
        
        @todo_2.detach
      end

      it 'should remove the list item from the list' do
        @todo_2.position.should be_nil
        
        Todo.get(1).position.should == 1
        Todo.get(3).position.should == 2
      end
    end

    describe '#reorder_list' do
      before do
        @todo_1 = Todo.create(:user => @u1, :title => "Clean the house")
        @todo_2 = Todo.create(:user => @u1, :title => "Brush the dogs")
        @todo_3 = Todo.create(:user => @u1, :title => "Arrange bookshelf")
        
        @todo_1.reorder_list([:title.asc])
      end

      it 'should reorder the list by the specified attribute' do
        pending

        # This is currently broken, the list is broken afterwords (duplicate positions, etc.)
        
        Todo.get(3).position.should == 1
        Todo.get(2).position.should == 2
        Todo.get(1).position.should == 3
      end
    end
  end
end
