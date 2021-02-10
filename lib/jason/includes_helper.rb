class Jason::IncludesHelper
  attr_accessor :includes, :model

  def initialize(model, includes)
    @model = model
    @includes = includes
  end

  def all_models(tree = includes)
    sub_models = if tree.is_a?(Hash)
      tree.map do |k,v|
        [k, all_models(v)]
      end
    else
      tree
    end

    pp ([model] + [sub_models]).flatten.uniq.map(&:to_s).map(&:singularize)
    ([model] + [sub_models]).flatten.uniq.map(&:to_s).map(&:singularize)
  end

  # assoc could be plural or not, so need to scan both.
  def get_assoc_name(model_name, haystack = includes)
    return model_name if model_name == model

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
      haystack.each do |assoc_name|
        if model_name.pluralize == assoc_name.to_s.pluralize
          return assoc_name
        end
      end
    else
      if model_name.pluralize == haystack.to_s.pluralize
        return haystack
      end
    end

    return nil
  end

  def get_tree_for(needle, assoc_name = nil, haystack = includes)
    return includes if needle == model
    return haystack if needle.to_s == assoc_name.to_s

    if haystack.is_a?(Hash)
      haystack.each do |assoc_name, includes_tree|
        found_haystack = get_tree_for(needle, assoc_name, includes_tree)
        return found_haystack if found_haystack
      end
    end

    return nil
  end
end