RSpec.describe Jason::GraphHelper do
  let(:graph_helper) { Jason::GraphHelper.new('abc123', Jason::IncludesHelper.new(tree)) }

  context "complex tree" do
    let(:tree) { { 'post' => { 'comments' => ['likes', { 'user' => ['roles'] } ] } } }

    it 'can find orphans' do
      graph_helper.add_edges(['post', 'comment', 'user'], [
        [1, 1, 1],
        [1, 2, 2],
      ])

      expect(graph_helper.find_orphans).to eq([])

      graph_helper.remove_edge('post', 1, 'comment', 2)

      expect(graph_helper.find_orphans).to match_array(['comment:2', 'user:2'])
    end
  end
end