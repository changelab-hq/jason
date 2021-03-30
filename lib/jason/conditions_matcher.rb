class Jason::ConditionsMatcher
  attr_reader :klass

  def initialize(klass)
    @klass = klass
  end

  # key, rules = 'post_id', 123
  # key, rules = 'post_id', { 'value': [123,C456], 'type': 'between' }
  # key, rules = 'post_id', { 'value': [123,456], 'type': 'between', 'not': true }
  # key, rules = 'post_id', { 'value': 123, 'type': 'equals', 'not': true }
  def test_match(key, rules, previous_changes)
    return nil if !previous_changes.keys.include?(key)

    if rules.is_a?(Hash)
      matches = false
      value = convert_to_datatype(key, rules['value'])

      if rules['type'] == 'equals'
        matches = previous_changes[key][1] == value
      elsif rules['type'] == 'between'
        matches = (value[0]..value[1]).cover?(previous_changes[key][1])
      else
        raise "Unrecognized rule type #{rules['type']}"
      end

      if rules['not']
        return !matches
      else
        return matches
      end

    elsif rules.is_a?(Array)
      value = convert_to_datatype(key, rules)
      return previous_changes[key][1].includes?(value)
    else
      value = convert_to_datatype(key, rules)
      return previous_changes[key][1] == value
    end
  end

  # conditions = { 'post_id' => 123, 'created_at' => { 'type' => 'between', 'value' => ['2020-01-01', '2020-01-02'] } }
  def apply_conditions(relation, conditions)
    conditions.each do |key, rules|
      relation = apply_condition(relation, key, rules)
    end

    relation
  end

  private

  def apply_condition(relation, key, rules)
    if rules.is_a?(Hash)
      value = convert_to_datatype(key, rules['value'])

      if rules['type'] == 'equals'
        arg = { key => value }
      elsif rules['type'] == 'between'
        arg = { key => value[0]..value[1] }
      else
        raise "Unrecognized rule type #{rules['type']}"
      end

      if rules['not']
        return relation.where.not(arg)
      else
        return relation.where(arg)
      end
    else
      value = convert_to_datatype(key, rules)
      return relation.where({ key => value })
    end
  end

  def convert_to_datatype(key, value)
    datatype = klass.type_for_attribute(key).type
    if datatype == :datetime || datatype == :date
      if value.is_a?(Array)
        value.map { |v| v&.to_datetime }
      else
        value&.to_datetime
      end
    else
      value
    end
  end
end