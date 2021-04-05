RSpec.describe "API Update Requests", type: 'request' do
  describe "POST action" do
    it "Creates a Post" do
      post '/jason/api/action' , params: {
        type: 'posts/upsert',
        payload: {
          id: SecureRandom.uuid,
          name: 'Hello'
        }
      }

      expect(Post.count).to eq(1)
    end

    it "Updates a Post" do
      post_instance = Post.create!(name: 'Test')
      post '/jason/api/action' , params: {
        type: 'posts/upsert',
        payload: {
          id: post_instance.id,
          name: 'Updated!'
        }
      }

      expect(Post.count).to eq(1)
      expect(Post.first.name).to eq("Updated!")
    end

    it "Destroys a Post" do
      post_instance = Post.create!(name: 'Test')
      post '/jason/api/action', params: {
        type: 'posts/remove',
        payload: post_instance.id
      }

      expect(Post.count).to eq(0)
    end
  end

  context "using authorization service" do
    before do
      Jason.update_authorization_service = TestUpdateAuthorizationService
    end

    after do
      Jason.update_authorization_service = nil
    end

    it "rejects the upsert request with no user" do
      post '/jason/api/action' , params: {
        type: 'posts/upsert',
        payload: {
          id: SecureRandom.uuid,
          name: 'Hello'
        }
      }

      expect(response.code).to eq('403')
    end

    it "allows the upsert request with admin" do
      user = User.create!
      user.roles.create!(name: 'admin')

      post '/jason/api/action' , params: {
        type: 'posts/upsert',
        payload: {
          id: SecureRandom.uuid,
          name: 'Hello'
        }
      }

      expect(Post.count).to eq(1)
      expect(response.code).to eq('200')
    end

    it "doesn't allow the upsert request with user" do
      user = User.create!
      user.roles.create!(name: 'user')

      post '/jason/api/action' , params: {
        type: 'posts/upsert',
        payload: {
          id: SecureRandom.uuid,
          name: 'Hello'
        }
      }

      expect(response.code).to eq('403')
    end

    it "allows the upsert request with user if comment exists and belongs to user" do
      user = User.create!
      user.roles.create!(name: 'user')
      post = Post.create!
      comment = Comment.create!(post: post, user: user, body: 'Test')

      post '/jason/api/action' , params: {
        type: 'comments/upsert',
        payload: {
          id: comment.id,
          body: 'Updated!'
        }
      }

      expect(response.code).to eq('200')
      expect(Comment.first.body).to eq('Updated!')
    end

    it "doesn't allow the upsert request with user if comment doesn't belong to user" do
      user = User.create!
      user2 = User.create!
      user.roles.create!(name: 'user')
      post = Post.create!
      comment = Comment.create!(post: post, user: user2, body: 'Test')

      post '/jason/api/action' , params: {
        type: 'comments/upsert',
        payload: {
          id: comment.id,
          body: 'Updated!'
        }
      }

      expect(response.code).to eq('403')
    end
  end

end

class TestUpdateAuthorizationService
  attr_reader :user, :model, :action, :instance, :params

  def self.call(...)
    new(...).call
  end

  def initialize(user, model, action, instance, params)
    @user = user
    @model = model
    @action = action
    @instance = instance
    @params = params
  end

  def call
    return false if user.blank?
    if user.roles.map(&:name).include?('admin')
      return true
    elsif user.roles.map(&:name).include?('user')
      return can_user_access?
    else
      return false
    end
  end

  def can_user_access?
    if model == 'comment'
      if !instance || instance.user_id == user.id
        return true
      end
    else
      return false
    end

    return false
  end
end