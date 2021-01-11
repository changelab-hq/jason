RSpec.describe Jason do
  it "has a version number" do
    expect(Jason::VERSION).not_to be nil
  end

  it "can be configured" do
    Jason.setup do |config|
      config.schema = { posts: { subscribed_fields: [:name] } }
    end
    expect(Jason.schema).to eq({ posts: { subscribed_fields: [:name] } })
  end
end
