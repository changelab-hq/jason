RSpec.describe "API Requests", type: 'request' do
  describe "POST create_subscription" do
    it "Creates a simple subscription" do
      post '/jason/api/create_subscription' , params: {
        config: {
          model: 'user'
        }
      }
      subscription = Jason::Subscription.all.first
      expect(subscription.config).to eq({
        'model' => 'user',
        'conditions' => {},
        'includes' => {}
      })
      expect(response.body).to eq({ channelName: subscription.channel }.to_json)
    end

    it "Creates a subscription with nesting" do
      post '/jason/api/create_subscription' , params: {
        config: {
          model: "user",
          conditions: {id: "1"},
          includes: ['comments']
        }
      }

      subscription = Jason::Subscription.all.first
      expect(subscription.config).to eq({
        'model' => 'user',
        'conditions' => { 'id' => '1' },
        'includes' => ['comments']
      })
      expect(response.body).to eq({ channelName: subscription.channel }.to_json)
    end

    it "Creates a complex subscription" do
      post '/jason/api/create_subscription' , params: {
        config: {
          model: "user",
          conditions: {id: "1"},
          includes: { comments: ["post"] }
        }
      }

      subscription = Jason::Subscription.all.first
      expect(subscription.config).to eq({
        'model' => 'user',
        'conditions' => { 'id' => '1' },
        'includes' => { 'comments' => ['post'] }
      })
      expect(response.body).to eq({ channelName: subscription.channel }.to_json)
    end

    context "using authorization service" do
      before do
        Jason.authorization_service = TestAuthorizationService
      end

      after do
        Jason.authorization_service = nil
      end

      it "rejects the subscription request with no user" do
        post '/jason/api/create_subscription' , params: {
          config: {
            model: 'user'
          }
        }
        expect(response.code).to eq('403')
      end

      it "allows the subscription request with admin" do
        user = User.create!
        user.roles.create!(name: 'admin')

        post '/jason/api/create_subscription' , params: {
          config: {
            model: 'user'
          }
        }
        expect(response.code).to eq('200')
      end

      it "allows the subscription request with user for posts" do
        user = User.create!
        user.roles.create!(name: 'user')

        post '/jason/api/create_subscription' , params: {
          config: {
            model: 'post'
          }
        }
        expect(response.code).to eq('200')
      end

      it "doesn't allow the subscription request with user for posts including comments" do
        user = User.create!
        user.roles.create!(name: 'user')

        post '/jason/api/create_subscription' , params: {
          config: {
            model: 'post',
            includes: [ 'comments' ]
          }
        }
        expect(response.code).to eq('403')
      end

      it "doesn't allow the subscription request with user for all comments" do
        user = User.create!
        user.roles.create!(name: 'user')

        post '/jason/api/create_subscription' , params: {
          config: {
            model: 'comments'
          }
        }
        expect(response.code).to eq('403')
      end

      it "allows the subscription request for comment they own, but not another" do
        user = User.create!
        post = Post.create!
        user.roles.create!(name: 'user')
        comment = Comment.create!(user: user, post: post)
        comment2 = Comment.create!(user: nil, post: post)

        post '/jason/api/create_subscription' , params: {
          config: {
            model: 'comment',
            conditions: { 'id' => comment.id }
          }
        }
        expect(response.code).to eq('200')

        post '/jason/api/create_subscription' , params: {
          config: {
            model: 'comment',
            conditions: { 'id' => comment2.id }
          }
        }
        expect(response.code).to eq('403')
      end

      it "doesn't allow the subscription request for comment they own, including submodels that aren't like" do
        user = User.create!
        post = Post.create!
        user.roles.create!(name: 'user')
        comment = Comment.create!(user: user, post: post)
        comment2 = Comment.create!(user: nil, post: post)

        post '/jason/api/create_subscription' , params: {
          config: {
            model: 'comment',
            conditions: { 'id' => comment.id },
            includes: ['likes']
          }
        }
        expect(response.code).to eq('200')

        post '/jason/api/create_subscription' , params: {
          config: {
            model: 'comment',
            conditions: { 'id' => comment.id },
            includes: [{ 'likes' => 'user' }]
          }
        }
        expect(response.code).to eq('403')
      end
    end
  end

  describe "POST get_payload" do
    let!(:user) { User.create! }
    let!(:subscription) { Jason::Subscription.upsert_by_config('user') }

    before do
      subscription.add_consumer('abc123')
    end

    it "works without auth" do
      post '/jason/api/get_payload' , params: {
        config: {
          model: 'user'
        }
      }
      subscription = Jason::Subscription.all.first
      expect(subscription.config).to eq({
        'model' => 'user',
        'conditions' => {},
        'includes' => {}
      })

      expect(response.body).to eq({ "user": {
        "type":"payload",
        "model":"user",
        "payload":[
          {"id": user.id}
        ],
        "md5Hash": subscription.id,
        "idx":0
      } }.to_json)
    end

    it "applies auth" do
      Jason.authorization_service = TestAuthorizationService

      post '/jason/api/get_payload' , params: {
        config: {
          model: 'user'
        }
      }
      subscription = Jason::Subscription.all.first
      expect(subscription.config).to eq({
        'model' => 'user',
        'conditions' => {},
        'includes' => {}
      })

      expect(response.body).to eq("")
      expect(response.code).to eq('403')

      Jason.authorization_service = nil

    end
  end
end

class TestAuthorizationService
  attr_reader :user, :model, :conditions, :sub_models

  def self.call(...)
    new(...).call
  end

  def initialize(user, model, conditions, sub_models)
    @user = user
    @model = model
    @conditions = conditions
    @sub_models = sub_models
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
    if model == 'post'
      if sub_models.blank?
        return true
      else
        return false
      end
    elsif model == 'comment'
      if conditions.blank?
        return false
      else
        if Comment.find(conditions['id']).user_id == user.id
          if (sub_models - ['like']).blank?
            return true
          else
            return false
          end
        else
          return false
        end
      end
    else
      return false
    end

    return false
  end
end