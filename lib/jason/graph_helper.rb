class Jason::GraphHelper
  attr_reader :id, :includes_helper

  def initialize(id, includes_helper)
    @id = id
    @includes_helper = includes_helper
  end

  def add_edge(parent_model, parent_id, child_model, child_id)
    edge = "#{parent_model}:#{parent_id}/#{child_model}:#{child_id}"
    $redis_jason.sadd("jason:subscriptions:#{id}:graph", edge)
  end

  def remove_edge(parent_model, parent_id, child_model, child_id)
    edge = "#{parent_model}:#{parent_id}/#{child_model}:#{child_id}"
    $redis_jason.srem("jason:subscriptions:#{id}:graph", edge)
  end

  def add_edges(all_models, instance_ids)
    edges = build_edges(all_models, instance_ids)
    $redis_jason.sadd("jason:subscriptions:#{id}:graph", edges)
  end

  def remove_edges(all_models, instance_ids)
    edges = build_edges(all_models, instance_ids)
    $redis_jason.srem("jason:subscriptions:#{id}:graph", edges)
  end

  # Add and remove edges, return graph before and after
  def apply_update(add: nil, remove: nil)
    add_edges = []
    remove_edges = []

    if add.present?
      add.each do |edge_set|
        add_edges += build_edges(edge_set[:model_names], edge_set[:instance_ids])
      end
    end

    if remove.present?
      remove.each do |edge_set|
        remove_edges += build_edges(edge_set[:model_names], edge_set[:instance_ids])
      end
    end

    old_edges, new_edges = Jason::LuaGenerator.new.update_set_with_diff("jason:subscriptions:#{id}:graph", add_edges.flatten, remove_edges.flatten)

    old_graph = build_graph_from_edges(old_edges)
    new_graph = build_graph_from_edges(new_edges)

    old_nodes = (old_graph.values + old_graph.keys).flatten.uniq - ['root']
    new_nodes = (new_graph.values + new_graph.keys).flatten.uniq - ['root']
    orphan_nodes = find_orphans_in_graph(new_graph)

    added_nodes = new_nodes - old_nodes - orphan_nodes
    removed_nodes = old_nodes - new_nodes + orphan_nodes

    orphaned_edges = orphan_nodes.map do |node|
      find_edges_with_node(new_edges, node)
    end.flatten

    if orphaned_edges.present?
      $redis_jason.srem("jason:subscriptions:#{id}:graph", orphaned_edges)
    end

    ids_to_add = {}
    ids_to_remove = {}

    added_nodes.each do |node|
      model_name, instance_id = node.split(':')
      ids_to_add[model_name] ||= []
      ids_to_add[model_name].push(instance_id)
    end

    removed_nodes.each do |node|
      model_name, instance_id = node.split(':')
      ids_to_remove[model_name] ||= []
      ids_to_remove[model_name].push(instance_id)
    end

    { ids_to_remove: ids_to_remove, ids_to_add: ids_to_add }
  end

  def find_edges_with_node(edges, node)
    edges.select do |edge|
      parent, child = edge.split('/')
      parent == node || child == node
    end
  end

  def find_orphans
    edges = $redis_jason.smembers("jason:subscriptions:#{id}:graph")
    graph = build_graph_from_edges(edges)
    find_orphans_in_graph(graph)
  end

  def find_orphans_in_graph(graph)
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

  def build_graph_from_edges(edges)
    graph = {}
    edges.each do |edge|
      parent, child = edge.split('/')
      graph[parent] ||= []
      graph[parent].push(child)
    end
    graph
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

    edges
  end
end