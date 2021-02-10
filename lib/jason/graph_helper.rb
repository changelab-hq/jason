class Jason::GraphHelper
  attr_reader :id, :includes_helper

  def initialize(id, includes_helper)
    @id = id
    @includes_helper = includes_helper
  end

  def add_edges(all_models, instance_ids)
    edges = build_edges(all_models, instance_ids)
    $redis_jason.sadd("jason:subscriptions:#{id}:graph", edges)
  end

  def remove_edge(parent_model, parent_id, child_model, child_id)
    edge = "#{parent_model}:#{parent_id}/#{child_model}:#{child_id}"
    $redis_jason.srem("jason:subscriptions:#{id}:graph", edge)
  end

  def find_orphans
    edges = $redis_jason.smembers("jason:subscriptions:#{id}:graph")
    graph = {}
    edges.each do |edge|
      parent, child = edge.split('/')
      graph[parent] ||= []
      graph[parent].push(child)
    end

    reachable_nodes = get_reachable_nodes(graph)
    all_nodes = (graph.values + graph.keys).flatten.uniq - ['root']
    all_nodes - reachable_nodes
  end

  def get_reachable_nodes(graph, parent = 'root')
    reached_nodes = graph[parent] || []
    reached_nodes.each do |child|
      reached_nodes += get_reachable_nodes(graph, child)
    end
    reached_nodes
  end

  private

  def build_edges(all_models, instance_ids)
    # Build the tree
    # Find parent -> child model relationships
    edges = []

    all_models.each_with_index do |parent_model, parent_idx|
      all_models.each_with_index do |child_model, child_idx|
        next if parent_model == child_model
        next if !includes_helper.in_sub(parent_model, child_model)

        pairs = instance_ids.map { |row| [row[parent_idx], row[child_idx]] }
          .uniq
          .reject{ |pair| pair[0].blank? || pair[1].blank? }

        edges += pairs.map.each do |pair|
          "#{parent_model}:#{pair[0]}/#{child_model}:#{pair[1]}"
        end
      end
    end

    root_model = includes_helper.root_model

    if all_models.include?(root_model)
      root_idx = all_models.find_index(root_model)
      root_ids = instance_ids.map { |row| row[root_idx] }.uniq.compact

      edges += root_ids.map do |id|
        "root/#{root_model}:#{id}"
      end
    end
  end
end