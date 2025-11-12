# frozen_string_literal: true

# BackendHelper provides view helpers for backend selection and display
module BackendHelper
  def backend_options_for_select
    BackendRegistry::BACKENDS.map do |key, config|
      label = "#{config[:name]}"
      label += " (Mocked)" if config[:mocked]
      label += " - #{config[:description]}"

      [
        label,
        key,
        {
          'data-available': config[:available],
          'data-mocked': config[:mocked],
          'data-features': config[:features].join(", ")
        }
      ]
    end
  end

  def backend_status_badge(backend_name)
    backend = BackendRegistry::BACKENDS[backend_name]
    return content_tag(:span, "Unknown", class: "badge badge-secondary") unless backend

    if backend[:available]
      if backend[:mocked]
        content_tag(:span, "⚠️ Mocked", class: "badge badge-warning", title: "Returns simulated results")
      else
        content_tag(:span, "✅ Functional", class: "badge badge-success", title: "Fully operational")
      end
    else
      content_tag(:span, "❌ Not Available", class: "badge badge-danger", title: "Not implemented")
    end
  end

  def backend_icon(backend_name)
    icons = {
      "dp_sandbox" => "🔒",
      "mpc_backend" => "🤝",
      "he_backend" => "🔐",
      "enclave_backend" => "🛡️"
    }
    icons[backend_name] || "❓"
  end

  def backend_description(backend_name)
    BackendRegistry::BACKENDS[backend_name]&.dig(:description) || "Unknown backend"
  end

  def backend_features(backend_name)
    backend = BackendRegistry::BACKENDS[backend_name]
    return "" unless backend

    features = backend[:features] || []
    features.join(", ")
  end

  def backend_privacy_guarantee(backend_name)
    backend = BackendRegistry::BACKENDS[backend_name]
    return "" unless backend

    backend[:privacy_guarantee] || "Unknown"
  end

  def backend_card_class(backend_name)
    backend = BackendRegistry::BACKENDS[backend_name]
    return "backend-card-unknown" unless backend

    if backend[:available]
      backend[:mocked] ? "backend-card-mocked" : "backend-card-available"
    else
      "backend-card-unavailable"
    end
  end
end
