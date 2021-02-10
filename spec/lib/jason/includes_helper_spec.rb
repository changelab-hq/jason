RSpec.describe Jason::IncludesHelper do
  let(:includes_helper) { Jason::IncludesHelper.new(tree) }

  context "simple tree" do
    let(:tree) { { 'post' => [] } }

    it '#assoc_name returns the correct values' do
      expect(includes_helper.get_assoc_name('post')).to eq('post')
    end

    it "#all_models returns the correct values" do
      expect(includes_helper.all_models).to match_array(['post'])
      expect(includes_helper.all_models('post')).to match_array(['post'])
    end

    it "#get_tree_for returns the correct values" do
      expect(includes_helper.get_tree_for('post')).to eq([])
    end
  end

  context "one depth tree" do
    let(:tree) { { 'post' => ['comments'] } }

    it '#assoc_name returns the correct values' do
      expect(includes_helper.get_assoc_name('post')).to eq('post')
      expect(includes_helper.get_assoc_name('comment')).to eq('comments')
    end

    it "#all_models returns the correct values" do
      expect(includes_helper.all_models).to match_array(['post', 'comment'])
      expect(includes_helper.all_models('post')).to match_array(['post', 'comment'])
      expect(includes_helper.all_models('comment')).to match_array(['comment'])
    end

    it "#get_tree_for returns the correct values" do
      expect(includes_helper.get_tree_for('post')).to eq(['comments'])
      expect(includes_helper.get_tree_for('comment')).to eq([])
    end

    it "#in_sub returns the correct values" do
      expect(includes_helper.in_sub('post', 'comment')).to be(true)
      expect(includes_helper.in_sub('comment', 'post')).to be(false)
    end
  end

  context "complex tree" do
    let(:tree) { { 'post' => { 'comments' => ['likes', { 'user' => ['roles'] } ] } } }

    it '#assoc_name returns the correct values' do
      expect(includes_helper.get_assoc_name('post')).to eq('post')
      expect(includes_helper.get_assoc_name('comment')).to eq('comments')
      expect(includes_helper.get_assoc_name('like')).to eq('likes')
      expect(includes_helper.get_assoc_name('user')).to eq('user')
      expect(includes_helper.get_assoc_name('role')).to eq('roles')
    end

    it "#all_models returns the correct values" do
      # Order is important, because we'll use for graph building
      expect(includes_helper.all_models).to eq(['post', 'comment', 'like', 'user', 'role'])
      expect(includes_helper.all_models('post')).to eq(['post', 'comment', 'like', 'user', 'role'])
      expect(includes_helper.all_models('comment')).to eq(['comment', 'like', 'user', 'role'])
      expect(includes_helper.all_models('like')).to eq(['like'])
      expect(includes_helper.all_models('user')).to eq(['user', 'role'])
      expect(includes_helper.all_models('role')).to eq(['role'])
    end

    it "#get_tree_for returns the correct values" do
      expect(includes_helper.get_tree_for('post')).to eq({ 'comments' => ['likes', { 'user' => ['roles'] } ] })
      expect(includes_helper.get_tree_for('comment')).to eq(['likes', { 'user' => ['roles'] } ])
      expect(includes_helper.get_tree_for('like')).to eq([])
      expect(includes_helper.get_tree_for('user')).to eq(['roles'])
      expect(includes_helper.get_tree_for('role')).to eq([])
    end

    it "#in_sub returns the correct values" do
      expect(includes_helper.in_sub('post', 'comment')).to be(true)
      expect(includes_helper.in_sub('comment', 'post')).to be(false)

      expect(includes_helper.in_sub('comment', 'like')).to be(true)
      expect(includes_helper.in_sub('like', 'comment')).to be(false)

      expect(includes_helper.in_sub('comment', 'like')).to be(true)
      expect(includes_helper.in_sub('like', 'comment')).to be(false)

      expect(includes_helper.in_sub('comment', 'user')).to be(true)
      expect(includes_helper.in_sub('user', 'comment')).to be(false)

      expect(includes_helper.in_sub('user', 'role')).to be(true)
      expect(includes_helper.in_sub('role', 'user')).to be(false)

      expect(includes_helper.in_sub('like', 'user')).to be(false)
      expect(includes_helper.in_sub('user', 'like')).to be(false)

      # Direct children only
      expect(includes_helper.in_sub('post', 'user')).to be(false)
    end
  end
end