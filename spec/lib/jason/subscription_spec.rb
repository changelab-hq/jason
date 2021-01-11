RSpec.describe Jason::Subscription do
  context "initializing subscriptions" do
    it "works with just model" do
      subscription = Jason::Subscription.upsert_by_config('post')

      expected_config = { 'model' => 'post', 'conditions' => {}, 'includes' => {} }
      expect(subscription.config).to eq(expected_config)
      expect(Jason::Subscription.find_by_id(subscription.id).config).to eq(expected_config)
    end

    it "works with model and conditions" do
      subscription = Jason::Subscription.upsert_by_config('post', conditions: { id: 'abc123' })

      expected_config = { 'model' => 'post', 'conditions' => { 'id' => 'abc123' }, 'includes' => {} }
      expect(subscription.config).to eq(expected_config)
      expect(Jason::Subscription.find_by_id(subscription.id).config).to eq(expected_config)
    end

    it "works with model, conditions and includes" do
      subscription = Jason::Subscription.upsert_by_config('post', conditions: { id: 'abc123' }, includes: ['comments'])

      expected_config = { 'model' => 'post', 'conditions' => { 'id' => 'abc123' }, 'includes' => ['comments'] }
      expect(subscription.config).to eq(expected_config)
      expect(Jason::Subscription.find_by_id(subscription.id).config).to eq(expected_config)
    end
  end

  context "assigning IDs" do
    let(:post) { Post.create! }
    let(:subscription) { Jason::Subscription.upsert_by_config('post', conditions: { id: post.id }) }

    context "a single model" do
      it "assigns ID for single model" do
        expect(subscription.ids('post')).to eq([])

        subscription.add_consumer('cde456')
        expect(subscription.ids('post')).to eq([post.id])
        expect(Jason::Subscription.for_instance('post', post.id)).to eq([subscription.id])
      end

      it "clears IDs for a single model" do
        subscription.add_consumer('cde456')
        subscription.remove_consumer('cde456')

        expect(subscription.ids('post')).to eq([])
        expect(Jason::Subscription.for_instance('post', post.id)).to eq([])
      end

      it "doesn't clear IDs if there are still consumers remaining" do
        subscription.add_consumer('cde456')
        subscription.add_consumer('def567')
        subscription.remove_consumer('cde456')

        expect(subscription.ids('post')).to eq([post.id])
        expect(Jason::Subscription.for_instance('post', post.id)).to eq([subscription.id])
      end

      it "assigns ALL ID for a single model" do
        subscription = Jason::Subscription.upsert_by_config('post')
        subscription.add_consumer('cde456')

        expect(Jason::Subscription.for_instance('post', post.id)).to eq([subscription.id])
        post2 = Post.create!
        expect(Jason::Subscription.for_instance('post', post2.id)).to eq([subscription.id])
      end

      it "clears ALL ID for a single model" do
        subscription = Jason::Subscription.upsert_by_config('post')
        subscription.add_consumer('cde456')
        subscription.remove_consumer('cde456')

        expect(Jason::Subscription.for_instance('post', post.id)).to eq([])
        post2 = Post.create!
        expect(Jason::Subscription.for_instance('post', post2.id)).to eq([])
      end
    end

    context "multiple nested models" do
      let!(:user1) { User.create! }
      let!(:user2) { User.create! }
      let!(:comment1) { Comment.create!(post: post, user: user1 )}
      let!(:comment2) { Comment.create!(post: post, user: user2 )}
      let!(:like1) { Like.create!(comment: comment1, user: user1 )}
      let!(:like2) { Like.create!(comment: comment2, user: user2 )}

      let(:subscription) { Jason::Subscription.upsert_by_config('post', conditions: { id: post.id }, includes: { comments: [:likes, :user] }) }

      it "assigns the correct IDs" do
        subscription.add_consumer('cde456')
        expect(subscription.ids('post')).to eq([post.id])
        expect(subscription.ids('comment')).to match_array([comment1.id, comment2.id])
        expect(subscription.ids('like')).to match_array([like1.id, like2.id])
        expect(subscription.ids('user')).to match_array([user1.id, user2.id])
      end
    end
  end
end