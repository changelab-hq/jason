# Helper to provide other modules with information about the includes of a subscription

class Jason::IncludesHelper
  attr_accessor :main_tree

  def initialize(main_tree)
    raise "Root must be hash" if !main_tree.is_a?(Hash)
    raise "Only one root key allowed" if main_tree.keys.size != 1
    @main_tree = main_tree
  end

  def all_models_recursive(tree)
    sub_models = if tree.is_a?(Hash)
      tree.map do |k,v|
        [k, all_models_recursive(v)]
      end
    elsif tree.is_a?(Array)
      tree.map do |v|
        all_models_recursive(v)
      end
    else
      tree
    end
  end

  def all_models(model_name = nil)
    model_name = model_name.presence || root_model
    assoc_name = get_assoc_name(model_name)
    tree = get_tree_for(assoc_name)
    [model_name, all_models_recursive(tree)].flatten.uniq.map(&:to_s).map(&:singularize)
  end

  def root_model
    main_tree.keys[0]
  end

  # assoc could be plural or not, so need to scan both.
  def get_assoc_name(model_name, haystack = main_tree)
    if haystack.is_a?(Hash)
      haystack.each do |assoc_name, includes_tree|
        if model_name.pluralize == assoc_name.to_s.pluralize
          return assoc_name
        else
          found_assoc = get_assoc_name(model_name, includes_tree)
          return found_assoc if found_assoc
        end
      end
    elsif haystack.is_a?(Array)
      haystack.each do |element|
        if element.is_a?(String)
          if model_name.pluralize == element.pluralize
            return element
          end
        else
          found_assoc = get_assoc_name(model_name, element)
          return found_assoc if found_assoc
        end
      end
    else
      if model_name.pluralize == haystack.to_s.pluralize
        return haystack
      end
    end

    return nil
  end

  def get_tree_for(needle, assoc_name = nil, haystack = main_tree)
    return haystack if needle.to_s.pluralize == assoc_name.to_s.pluralize

    if haystack.is_a?(Hash)
      haystack.each do |assoc_name, includes_tree|
        found_haystack = get_tree_for(needle, assoc_name, includes_tree)
        return found_haystack if found_haystack.present?
      end
    elsif haystack.is_a?(Array)
      haystack.each do |includes_tree|
        found_haystack = get_tree_for(needle, nil, includes_tree)
        return found_haystack if found_haystack.present?
      end
    elsif haystack.is_a?(String)
      found_haystack = get_tree_for(needle, haystack, nil)
      return found_haystack if found_haystack.present?
    end

    return []
  end

  def in_sub(parent_model, child_model)
    tree = get_tree_for(parent_model)

    if tree.is_a?(Hash)
      return tree.keys.map(&:singularize).include?(child_model)
    elsif tree.is_a?(Array)
      tree.each do |element|
        if element.is_a?(String)
          return true if element.singularize == child_model
        elsif element.is_a?(Hash)
          return true if element.keys.map(&:singularize).include?(child_model)
        end
      end
    elsif tree.is_a?(String)
      return tree.singularize == child_model
    end

    return false
  end
end