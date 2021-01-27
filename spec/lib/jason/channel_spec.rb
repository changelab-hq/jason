RSpec.describe Jason::Channel, type: :channel do
  let(:post) { Post.create! }

  let!(:user1) { User.create! }
  let!(:user2) { User.create! }
  let!(:comment1) { Comment.create!(post: post, user: user1 )}
  let!(:comment2) { Comment.create!(post: post, user: user2 )}

  let!(:like1) { Like.create!(comment: comment1, user: user1 )}
  let!(:like2) { Like.create!(comment: comment2, user: user2 )}

  it "subscribes to a stream when room id is provided" do
    subscribe()

    expect(subscription).to be_confirmed

    perform :receive, { 'createSubscription' => { 'model' => 'post', 'includes' => ['comments'] } }
  end
end