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
  end
end