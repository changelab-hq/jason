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

      # Don't expect these to be included
      let!(:post2) { Post.create! }
      let!(:comment3) { Comment.create!(post: post2, user: user2 )}

      before do
        subscription.add_consumer('cde456')
      end

      it "assigns the correct IDs and subscriptions" do
        expect(subscription.ids('post')).to eq([post.id])
        expect(subscription.ids('comment')).to match_array([comment1.id, comment2.id])
        expect(subscription.ids('like')).to match_array([like1.id, like2.id])
        expect(subscription.ids('user')).to match_array([user1.id, user2.id])

        expect(Jason::Subscription.for_instance('post', post.id)).to eq([subscription.id])
        expect(Jason::Subscription.for_instance('comment', comment1.id)).to eq([subscription.id])
        expect(Jason::Subscription.for_instance('comment', comment2.id)).to eq([subscription.id])
        expect(Jason::Subscription.for_instance('like', like1.id)).to eq([subscription.id])
        expect(Jason::Subscription.for_instance('like', like2.id)).to eq([subscription.id])
        expect(Jason::Subscription.for_instance('user', user1.id)).to eq([subscription.id])
        expect(Jason::Subscription.for_instance('user', user2.id)).to eq([subscription.id])

        expect(Jason::Subscription.for_instance('comment', comment3.id)).to eq([])
      end

      it "assigns nested instances to the subscription" do
        new_user = User.create!
        new_comment = post.comments.create!(body: "Hello", user: new_user)

        expect(subscription.ids('comment')).to match_array([new_comment.id, comment1.id, comment2.id])
        expect(subscription.ids('user')).to match_array([new_user.id, user1.id, user2.id])
      end

      it "removes nested instances from the subscription" do
        Comment.find(comment2.id).destroy

        expect(subscription.ids('comment')).to match_array([comment1.id])
      end

      it "removes two-level nested instances from the subscription" do
        # TODO: Find out why this is failing
        $pry = true
        like2.destroy

        expect(subscription.ids('like')).to match_array([like1.id])
      end

      it "clears up the IDs and subscriptions" do
        subscription.remove_consumer('cde456')

        expect(subscription.ids('post')).to eq([])
        expect(subscription.ids('comment')).to match_array([])
        expect(subscription.ids('like')).to match_array([])
        expect(subscription.ids('user')).to match_array([])

        expect(Jason::Subscription.for_instance('post', post.id)).to eq([])
        expect(Jason::Subscription.for_instance('comment', comment1.id)).to eq([])
        expect(Jason::Subscription.for_instance('comment', comment2.id)).to eq([])
        expect(Jason::Subscription.for_instance('like', like1.id)).to eq([])
        expect(Jason::Subscription.for_instance('like', like2.id)).to eq([])
        expect(Jason::Subscription.for_instance('user', user1.id)).to eq([])
        expect(Jason::Subscription.for_instance('user', user2.id)).to eq([])

        expect(Jason::Subscription.for_instance('comment', comment3.id)).to eq([])
      end
    end

    context "even deeply nested models" do
      let!(:user1) { User.create! }
      let!(:user2) { User.create! }
      let!(:comment1) { Comment.create!(post: post, user: user1 )}
      let!(:comment2) { Comment.create!(post: post, user: user2 )}

      let!(:role1) { Role.create!(user: user1, name: 'admin' )}
      let!(:role2) { Role.create!(user: user2, name: 'user' )}

      let(:subscription) { Jason::Subscription.upsert_by_config('post', conditions: { id: post.id }, includes: { comments: { likes: [],  user: ['roles'] } }) }

      before do
        subscription.add_consumer('cde456')
      end

      it "assigns nested instances to the subscription" do
        new_role = Role.create!(user: user1, name: 'test')

        expect(subscription.ids('role')).to match_array([new_role.id, role1.id, role2.id])
      end
    end

  end

  context "instances changing nested ID" do
    let(:post1) { Post.create! }
    let(:post2) { Post.create! }
    let(:post3) { Post.create! }
    let(:user1) { User.create! }
    let(:user2) { User.create! }
    let(:user3) { User.create! }
    let!(:comment1) { Comment.create!(post: post1, user: user1 )}
    let!(:comment2) { Comment.create!(post: post2, user: user2 )}
    let!(:comment3) { Comment.create!(post: post3, user: user3 )}

    let(:subscription) { Jason::Subscription.upsert_by_config('post', conditions: { id: [post1.id, post2.id] }, includes: { comments: [:likes, :user] }) }

    before do
      subscription.add_consumer('cde456')
    end

    # TODO - what happens when model changing is the root model? E.g.
    # sub = comment:all
    # change = comment#123.user_id

    context "when change doesn't affect subscription" do
      it "keeps the IDs the same" do
        # comment changes post ID
        expect(subscription.ids('comment')).to match_array([comment1.id, comment2.id])
        expect(Jason::Subscription.for_instance('comment', comment1.id)).to eq([subscription.id])
        expect(Jason::Subscription.for_instance('comment', comment2.id)).to eq([subscription.id])

        Jason::Subscription.update_ids('comment', comment1.id, 'post', post1.id, post2.id)

        expect(subscription.ids('comment')).to match_array([comment1.id, comment2.id])
        expect(Jason::Subscription.for_instance('comment', comment1.id)).to eq([subscription.id])
        expect(Jason::Subscription.for_instance('comment', comment2.id)).to eq([subscription.id])
      end
    end

    context "when change causes instance to be added" do
      it "adds the ID and sub-IDs" do
        Jason::Subscription.update_ids('comment', comment3.id, 'post', post3.id, post1.id)

        expect(subscription.ids('comment')).to match_array([comment1.id, comment2.id, comment3.id])
        expect(Jason::Subscription.for_instance('comment', comment1.id)).to eq([subscription.id])
        expect(Jason::Subscription.for_instance('comment', comment2.id)).to eq([subscription.id])
        expect(Jason::Subscription.for_instance('comment', comment3.id)).to eq([subscription.id])

        expect(Jason::Subscription.for_instance('user', user1.id)).to eq([subscription.id])
        expect(Jason::Subscription.for_instance('user', user2.id)).to eq([subscription.id])
        expect(Jason::Subscription.for_instance('user', user3.id)).to eq([subscription.id])
      end
    end

    context "when change causes instance to be removed" do
      # The eventual intention intention is to do a tree-diff when this sort of update happens to
      # determine which IDs can be removed, but at the moment we just handle removing dangling IDs
      # with a regular cleanup task
      it "doesn't remove child IDs referenced by other instances the ID and sub-IDs" do
        # user2 also referenced by comment2, so shouldn't be removed from the sub
        comment1.update!(user: user2)

        expect(Jason::Subscription.for_instance('user', user1.id)).to eq([subscription.id])
        expect(Jason::Subscription.for_instance('user', user2.id)).to eq([subscription.id])

        Jason::Subscription.update_ids('comment', comment1.id, 'post', post1.id, post3.id)

        expect(subscription.ids('comment')).to match_array([comment2.id])
        expect(Jason::Subscription.for_instance('comment', comment1.id)).to eq([])
        expect(Jason::Subscription.for_instance('comment', comment2.id)).to eq([subscription.id])

        expect(Jason::Subscription.for_instance('user', user1.id)).to eq([subscription.id])
        expect(Jason::Subscription.for_instance('user', user2.id)).to eq([subscription.id])
      end
    end
  end

  context "integration testing subscriptions" do
    let(:post) { Post.create! }

    let!(:user1) { User.create! }
    let!(:user2) { User.create! }
    let!(:comment1) { Comment.create!(post: post, user: user1 )}
    let!(:comment2) { Comment.create!(post: post, user: user2 )}

    let!(:like1) { Like.create!(comment: comment1, user: user1 )}
    let!(:like2) { Like.create!(comment: comment2, user: user2 )}

    let(:subscription) { Jason::Subscription.upsert_by_config('post', conditions: { id: post.id }, includes: { comments: [:likes, :user] }) }

    # Don't expect these to be included
    let!(:post2) { Post.create! }
    let!(:comment3) { Comment.create!(post: post2, user: user2 )}

    before do
      subscription.add_consumer('cde456')
    end

    it "broadcasts on update" do
      expect(ActionCable.server).to receive(:broadcast).with("jason:#{subscription.id}", {
        :id=>post.id,
        :model=>"post",
        :payload=>{"id"=>post.id, "name"=>"Test"},
        :md5Hash=>subscription.id,
        :idx=>1}
      )
      post.update!(name: 'Test')

      expect(ActionCable.server).to receive(:broadcast).with("jason:#{subscription.id}", {
        :id=>post.id,
        :model=>"post",
        :payload=>{"id"=>post.id, "name"=>"Test me out"},
        :md5Hash=>subscription.id,
        :idx=>2}
      )
      post.update!(name: 'Test me out')
    end

    it "broadcasts nested on create" do
      new_comment_id = SecureRandom.uuid

      expect(ActionCable.server).to receive(:broadcast).with("jason:#{subscription.id}", {
        :id=>new_comment_id,
        :model=>"comment",
        :payload=>{"id"=>new_comment_id},
        :md5Hash=>subscription.id,
        :idx=>1}
      )

      new_comment = post.comments.create!(id: new_comment_id, body: "Hello", user: User.first)
    end

    it "broadcasts on destroy" do
      expect(ActionCable.server).to receive(:broadcast).with("jason:#{subscription.id}", {
        :id=>comment2.id,
        :model=>"comment",
        :md5Hash=>subscription.id,
        :idx=>1,
        :destroy=>true
      })

      expect(subscription.ids('comment')).to match_array([comment1.id, comment2.id])
      comment2.destroy
    end

    context "getting subscriptions" do
      it "gets all the models in the sub" do
        expect(subscription.get).to include({
          idx: 0,
          md5Hash: subscription.id,
          model: 'comment',
          payload: match_array([
            a_hash_including({ 'id' => comment1.id }),
            a_hash_including({ 'id' => comment2.id })
          ]),
          type: 'payload'
        })
      end
    end
  end
end