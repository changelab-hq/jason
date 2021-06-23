class Jason::ConsistencyChecker
  attr_reader :subscription
  attr_reader :inconsistent

  def self.check_all(fix: false)
    Jason::Subscription.all.each do |sub|
      next if sub.consumer_count == 0
      checker = Jason::ConsistencyChecker.new(sub)
      result = checker.check
      if checker.inconsistent?
        pp sub.config
        pp result
        if fix
          sub.reset!(hard: true)
        end
      end
    end
  end

  def self.fix_all
    check_all(fix: true)
  end

  def wipe_all_subs

  end

  def initialize(subscription)
    @subscription = subscription
    @inconsistent = false
  end

  def inconsistent?
    inconsistent
  end

  # Take a subscription, get the current cached payload, and compare it to the data retrieved from the database
  def check
    cached_payload = subscription.get
    edge_set = subscription.load_ids_for_sub_models(subscription.model, nil)

    result = cached_payload.map do |model_name, data|
      cached_payload_instance_ids = data[:payload].map { |row| row['id'] }

      model_idx = edge_set[:model_names].index(model_name)
      if model_idx.present?
        edge_set_instance_ids = edge_set[:instance_ids].map { |row| row[model_idx] }
      else
        next
      end

      missing = edge_set_instance_ids - cached_payload_instance_ids
      intruding = cached_payload_instance_ids - edge_set_instance_ids

      if missing.present? || intruding.present?
        @inconsistent = true
      end

      [model_name, {
        'missing' => missing,
        'intruding' => intruding
      }]
    end.compact.to_h
  end
end