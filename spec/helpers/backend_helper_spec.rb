require 'rails_helper'

RSpec.describe BackendHelper, type: :helper do
  describe '#backend_options_for_select' do
    it 'returns array of options' do
      options = helper.backend_options_for_select
      expect(options).to be_an(Array)
      expect(options).not_to be_empty
    end

    it 'includes all backends from BackendRegistry' do
      options = helper.backend_options_for_select
      backend_keys = options.map { |opt| opt[1] }

      BackendRegistry::BACKENDS.keys.each do |key|
        expect(backend_keys).to include(key)
      end
    end

    it 'includes backend name in label' do
      options = helper.backend_options_for_select
      dp_option = options.find { |opt| opt[1] == 'dp_sandbox' }

      expect(dp_option[0]).to include('Differential Privacy')
    end

    it 'includes "Mocked" label for mocked backends' do
      options = helper.backend_options_for_select
      mpc_option = options.find { |opt| opt[1] == 'mpc_backend' }

      expect(mpc_option[0]).to include('(Mocked)')
    end

    it 'excludes "Mocked" label for non-mocked backends' do
      options = helper.backend_options_for_select
      he_option = options.find { |opt| opt[1] == 'he_backend' }

      expect(he_option[0]).not_to include('(Mocked)')
    end

    it 'includes backend description in label' do
      options = helper.backend_options_for_select
      dp_option = options.find { |opt| opt[1] == 'dp_sandbox' }

      expect(dp_option[0]).to include('Privacy-preserving')
    end

    it 'includes HTML data attributes with availability' do
      options = helper.backend_options_for_select
      dp_option = options.find { |opt| opt[1] == 'dp_sandbox' }

      data_attrs = dp_option[2]
      expect(data_attrs[:'data-available']).to be true
    end

    it 'includes HTML data attributes with mocked status' do
      options = helper.backend_options_for_select
      mpc_option = options.find { |opt| opt[1] == 'mpc_backend' }

      data_attrs = mpc_option[2]
      expect(data_attrs[:'data-mocked']).to be true
    end

    it 'includes HTML data attributes with features' do
      options = helper.backend_options_for_select
      dp_option = options.find { |opt| opt[1] == 'dp_sandbox' }

      data_attrs = dp_option[2]
      expect(data_attrs[:'data-features']).to be_a(String)
      expect(data_attrs[:'data-features']).to include('COUNT')
    end

    it 'formats features as comma-separated list in data attribute' do
      options = helper.backend_options_for_select
      dp_option = options.find { |opt| opt[1] == 'dp_sandbox' }

      data_attrs = dp_option[2]
      features = data_attrs[:'data-features'].split(', ')
      expect(features.length).to be > 1
    end

    it 'has value as second element (backend key)' do
      options = helper.backend_options_for_select
      keys = options.map { |opt| opt[1] }

      expect(keys).to all(be_a(String))
      expect(keys.first).to match(/^[a-z_]+$/)
    end

    it 'has label as first element (string)' do
      options = helper.backend_options_for_select
      labels = options.map { |opt| opt[0] }

      expect(labels).to all(be_a(String))
      expect(labels).not_to include(nil)
    end

    it 'has data attributes as third element (hash)' do
      options = helper.backend_options_for_select
      data_attrs = options.map { |opt| opt[2] }

      expect(data_attrs).to all(be_a(Hash))
    end
  end

  describe '#backend_status_badge' do
    it 'returns HTML content tag' do
      result = helper.backend_status_badge('dp_sandbox')
      expect(result).to be_html_safe
    end

    it 'returns "Unknown" badge for invalid backend' do
      result = helper.backend_status_badge('nonexistent_backend')
      expect(result).to include('Unknown')
      expect(result).to include('badge-secondary')
    end

    it 'returns "Functional" badge for available non-mocked backend' do
      result = helper.backend_status_badge('dp_sandbox')
      expect(result).to include('Functional')
      expect(result).to include('badge-success')
    end

    it 'returns "Mocked" badge for available mocked backend' do
      result = helper.backend_status_badge('mpc_backend')
      expect(result).to include('Mocked')
      expect(result).to include('badge-warning')
    end

    it 'returns "Not Available" badge for unavailable backend' do
      result = helper.backend_status_badge('enclave_backend')
      expect(result).to include('Not Available')
      expect(result).to include('badge-danger')
    end

    it 'includes title attribute for functional backend' do
      result = helper.backend_status_badge('dp_sandbox')
      expect(result).to include('title="Fully operational"')
    end

    it 'includes title attribute for mocked backend' do
      result = helper.backend_status_badge('mpc_backend')
      expect(result).to include('title="Returns simulated results"')
    end

    it 'includes title attribute for unavailable backend' do
      result = helper.backend_status_badge('enclave_backend')
      expect(result).to include('title="Not implemented"')
    end

    it 'uses correct Bootstrap badge classes' do
      dp_result = helper.backend_status_badge('dp_sandbox')
      expect(dp_result).to include('badge')
      expect(dp_result).to include('badge-success')
    end

    it 'includes emoji indicator in badge' do
      dp_result = helper.backend_status_badge('dp_sandbox')
      expect(dp_result).to include('✅')

      mpc_result = helper.backend_status_badge('mpc_backend')
      expect(mpc_result).to include('⚠️')

      enclave_result = helper.backend_status_badge('enclave_backend')
      expect(enclave_result).to include('❌')
    end
  end

  describe '#backend_icon' do
    it 'returns icon for dp_sandbox' do
      icon = helper.backend_icon('dp_sandbox')
      expect(icon).to eq('🔒')
    end

    it 'returns icon for mpc_backend' do
      icon = helper.backend_icon('mpc_backend')
      expect(icon).to eq('🤝')
    end

    it 'returns icon for he_backend' do
      icon = helper.backend_icon('he_backend')
      expect(icon).to eq('🔐')
    end

    it 'returns icon for enclave_backend' do
      icon = helper.backend_icon('enclave_backend')
      expect(icon).to eq('🛡️')
    end

    it 'returns question mark for unknown backend' do
      icon = helper.backend_icon('unknown_backend')
      expect(icon).to eq('❓')
    end

    it 'returns string emoji' do
      icon = helper.backend_icon('dp_sandbox')
      expect(icon).to be_a(String)
      expect(icon.length).to be > 0
    end
  end

  describe '#backend_description' do
    it 'returns description for valid backend' do
      description = helper.backend_description('dp_sandbox')
      expect(description).to be_a(String)
      expect(description).not_to be_empty
      expect(description).to include('Privacy')
    end

    it 'returns description for mpc_backend' do
      description = helper.backend_description('mpc_backend')
      expect(description).to include('Collaborative')
    end

    it 'returns description for he_backend' do
      description = helper.backend_description('he_backend')
      expect(description).to include('homomorphic')
    end

    it 'returns "Unknown backend" for invalid backend' do
      description = helper.backend_description('nonexistent_backend')
      expect(description).to eq('Unknown backend')
    end

    it 'returns string' do
      description = helper.backend_description('dp_sandbox')
      expect(description).to be_a(String)
    end

    it 'returns different descriptions for different backends' do
      dp_desc = helper.backend_description('dp_sandbox')
      mpc_desc = helper.backend_description('mpc_backend')
      he_desc = helper.backend_description('he_backend')

      expect(dp_desc).not_to eq(mpc_desc)
      expect(mpc_desc).not_to eq(he_desc)
    end
  end

  describe '#backend_features' do
    it 'returns comma-separated list of features' do
      features = helper.backend_features('dp_sandbox')
      expect(features).to be_a(String)
      expect(features).to include(',')
    end

    it 'includes COUNT for dp_sandbox' do
      features = helper.backend_features('dp_sandbox')
      expect(features).to include('COUNT')
    end

    it 'includes SUM for dp_sandbox' do
      features = helper.backend_features('dp_sandbox')
      expect(features).to include('SUM')
    end

    it 'includes AVG for dp_sandbox' do
      features = helper.backend_features('dp_sandbox')
      expect(features).to include('AVG')
    end

    it 'includes MIN for dp_sandbox' do
      features = helper.backend_features('dp_sandbox')
      expect(features).to include('MIN')
    end

    it 'includes MAX for dp_sandbox' do
      features = helper.backend_features('dp_sandbox')
      expect(features).to include('MAX')
    end

    it 'returns limited features for mpc_backend' do
      features = helper.backend_features('mpc_backend')
      expect(features).to include('COUNT')
      expect(features).to include('SUM')
      expect(features).to include('AVG')
      expect(features).not_to include('MIN')
      expect(features).not_to include('MAX')
    end

    it 'returns limited features for he_backend' do
      features = helper.backend_features('he_backend')
      expect(features).to include('COUNT')
      expect(features).to include('SUM')
      expect(features).not_to include('AVG')
    end

    it 'returns extended features for enclave_backend' do
      features = helper.backend_features('enclave_backend')
      expect(features).to include('COUNT')
      expect(features).to include('SUM')
      expect(features).to include('AVG')
      expect(features).to include('JOIN')
    end

    it 'returns empty string for invalid backend' do
      features = helper.backend_features('nonexistent_backend')
      expect(features).to eq('')
    end

    it 'returns string' do
      features = helper.backend_features('dp_sandbox')
      expect(features).to be_a(String)
    end

    it 'separates features with ", " (comma and space)' do
      features = helper.backend_features('dp_sandbox')
      parts = features.split(', ')
      expect(parts.length).to be > 1
      expect(features).to match(/\w+, \w+/)
    end
  end

  describe '#backend_privacy_guarantee' do
    it 'returns privacy guarantee for valid backend' do
      guarantee = helper.backend_privacy_guarantee('dp_sandbox')
      expect(guarantee).to be_a(String)
      expect(guarantee).not_to be_empty
    end

    it 'includes differential privacy for dp_sandbox' do
      guarantee = helper.backend_privacy_guarantee('dp_sandbox')
      expect(guarantee).to include('differential')
    end

    it 'includes cryptographic security for mpc_backend' do
      guarantee = helper.backend_privacy_guarantee('mpc_backend')
      expect(guarantee).to include('Cryptographic')
      expect(guarantee).to include('secret sharing')
    end

    it 'includes cryptographic security for he_backend' do
      guarantee = helper.backend_privacy_guarantee('he_backend')
      expect(guarantee).to include('Cryptographic')
      expect(guarantee).to include('homomorphic')
    end

    it 'includes hardware-based for enclave_backend' do
      guarantee = helper.backend_privacy_guarantee('enclave_backend')
      expect(guarantee).to include('Hardware-based')
    end

    it 'returns empty string for invalid backend' do
      guarantee = helper.backend_privacy_guarantee('nonexistent_backend')
      expect(guarantee).to eq('')
    end

    it 'returns different guarantees for different backends' do
      dp_guarantee = helper.backend_privacy_guarantee('dp_sandbox')
      mpc_guarantee = helper.backend_privacy_guarantee('mpc_backend')
      he_guarantee = helper.backend_privacy_guarantee('he_backend')

      expect(dp_guarantee).not_to eq(mpc_guarantee)
      expect(mpc_guarantee).not_to eq(he_guarantee)
    end

    it 'returns string' do
      guarantee = helper.backend_privacy_guarantee('dp_sandbox')
      expect(guarantee).to be_a(String)
    end
  end

  describe '#backend_card_class' do
    it 'returns CSS class string' do
      css_class = helper.backend_card_class('dp_sandbox')
      expect(css_class).to be_a(String)
      expect(css_class).to start_with('backend-card-')
    end

    it 'returns "backend-card-available" for available non-mocked backend' do
      css_class = helper.backend_card_class('dp_sandbox')
      expect(css_class).to eq('backend-card-available')
    end

    it 'returns "backend-card-available" for he_backend' do
      css_class = helper.backend_card_class('he_backend')
      expect(css_class).to eq('backend-card-available')
    end

    it 'returns "backend-card-mocked" for available mocked backend' do
      css_class = helper.backend_card_class('mpc_backend')
      expect(css_class).to eq('backend-card-mocked')
    end

    it 'returns "backend-card-unavailable" for unavailable backend' do
      css_class = helper.backend_card_class('enclave_backend')
      expect(css_class).to eq('backend-card-unavailable')
    end

    it 'returns "backend-card-unknown" for invalid backend' do
      css_class = helper.backend_card_class('nonexistent_backend')
      expect(css_class).to eq('backend-card-unknown')
    end

    it 'uses consistent naming convention' do
      classes = [
        helper.backend_card_class('dp_sandbox'),
        helper.backend_card_class('mpc_backend'),
        helper.backend_card_class('enclave_backend'),
        helper.backend_card_class('invalid')
      ]

      classes.each do |css_class|
        expect(css_class).to start_with('backend-card-')
      end
    end

    it 'is useful for conditional CSS styling' do
      available = helper.backend_card_class('dp_sandbox')
      mocked = helper.backend_card_class('mpc_backend')
      unavailable = helper.backend_card_class('enclave_backend')

      # All different, so CSS can style them differently
      expect([available, mocked, unavailable].uniq.length).to eq(3)
    end
  end

  describe 'integration between helpers' do
    it 'backend icon and status badge can be combined' do
      icon = helper.backend_icon('dp_sandbox')
      badge = helper.backend_status_badge('dp_sandbox')

      # Both should return valid output
      expect(icon).not_to be_empty
      expect(badge).to be_html_safe
    end

    it 'features and privacy guarantee are compatible' do
      features = helper.backend_features('dp_sandbox')
      guarantee = helper.backend_privacy_guarantee('dp_sandbox')

      # Both should exist for available backends
      expect(features).not_to be_empty
      expect(guarantee).not_to be_empty
    end

    it 'card class, description, and icon work together' do
      %w[dp_sandbox mpc_backend he_backend enclave_backend].each do |backend|
        css_class = helper.backend_card_class(backend)
        description = helper.backend_description(backend)
        icon = helper.backend_icon(backend)

        expect(css_class).not_to be_empty
        expect(description).not_to be_empty
        expect(icon).not_to be_empty
      end
    end

    it 'all backends in options_for_select have corresponding helpers work' do
      options = helper.backend_options_for_select
      options.each do |label, key, data_attrs|
        # All keys should work with other helpers
        expect { helper.backend_icon(key) }.not_to raise_error
        expect { helper.backend_description(key) }.not_to raise_error
        expect { helper.backend_features(key) }.not_to raise_error
        expect { helper.backend_privacy_guarantee(key) }.not_to raise_error
        expect { helper.backend_status_badge(key) }.not_to raise_error
        expect { helper.backend_card_class(key) }.not_to raise_error
      end
    end
  end

  describe 'edge cases' do
    it 'handles nil backend name gracefully' do
      expect { helper.backend_icon(nil) }.not_to raise_error
      expect { helper.backend_description(nil) }.not_to raise_error
      expect { helper.backend_features(nil) }.not_to raise_error
      expect { helper.backend_privacy_guarantee(nil) }.not_to raise_error
      expect { helper.backend_status_badge(nil) }.not_to raise_error
      expect { helper.backend_card_class(nil) }.not_to raise_error
    end

    it 'handles empty string backend name gracefully' do
      expect { helper.backend_icon('') }.not_to raise_error
      expect { helper.backend_description('') }.not_to raise_error
      expect { helper.backend_features('') }.not_to raise_error
      expect { helper.backend_privacy_guarantee('') }.not_to raise_error
      expect { helper.backend_status_badge('') }.not_to raise_error
      expect { helper.backend_card_class('') }.not_to raise_error
    end

    it 'handles case sensitivity for backend keys' do
      # Backend keys are case-sensitive and should be lowercase
      expect(helper.backend_icon('DP_SANDBOX')).to eq('❓')
      expect(helper.backend_icon('dp_sandbox')).to eq('🔒')
    end

    it 'options_for_select returns consistent ordering' do
      options1 = helper.backend_options_for_select
      options2 = helper.backend_options_for_select

      keys1 = options1.map { |opt| opt[1] }
      keys2 = options2.map { |opt| opt[1] }

      expect(keys1).to eq(keys2)
    end
  end

  describe 'HTML safety' do
    it 'backend_status_badge returns HTML safe content' do
      result = helper.backend_status_badge('dp_sandbox')
      expect(result).to be_html_safe
    end

    it 'backend_icon returns plain string (not HTML)' do
      icon = helper.backend_icon('dp_sandbox')
      expect(icon).not_to be_html_safe
      # But it contains emoji which is safe to display
      expect(icon).to match(/[^\w\s]/)
    end

    it 'backend_description returns plain string' do
      description = helper.backend_description('dp_sandbox')
      expect(description).to be_a(String)
      expect(description).not_to be_html_safe
    end

    it 'backend_features returns plain string' do
      features = helper.backend_features('dp_sandbox')
      expect(features).to be_a(String)
      expect(features).not_to be_html_safe
    end

    it 'backend_privacy_guarantee returns plain string' do
      guarantee = helper.backend_privacy_guarantee('dp_sandbox')
      expect(guarantee).to be_a(String)
      expect(guarantee).not_to be_html_safe
    end

    it 'backend_card_class returns plain string' do
      css_class = helper.backend_card_class('dp_sandbox')
      expect(css_class).to be_a(String)
      expect(css_class).not_to be_html_safe
    end
  end
end
