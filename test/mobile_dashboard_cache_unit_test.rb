# Database-free: bin/rails runner test/mobile_dashboard_cache_unit_test.rb
require "minitest/autorun"

class MobileDashboardCacheUnitTest < Minitest::Test
  def setup
    @old_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    @calls = Hash.new(0)
    @web = Object.new
    calls = @calls
    { mapped: 10, no_training: 2, yellow: 3, green: 5 }.each do |kind, total|
      method = kind == :no_training ? "farmer_training_no_training_count_and_popups" : "farmer_training_#{kind}_farmer_count_and_popups"
      @web.define_singleton_method(method) do |**|
        calls[kind] += 1
        [total, [], []]
      end
    end
    @web.define_singleton_method(:farmer_training_participation_rows_from_sql) do |status, **|
      calls[status] += 1
      [{ status: status }]
    end
  end

  def teardown
    Rails.cache = @old_cache
  end

  def controller(status, month = "August", user = "1")
    c = Api::V1::JeevikaJankarDashboardController.new
    c.request = ActionDispatch::TestRequest.create
    c.request.set_header("QUERY_STRING", "status=#{status}&month=#{month}")
    c.params = ActionController::Parameters.new(status: status, month: month)
    web = @web
    c.define_singleton_method(:mobile_participation_calculator) { web }
    c.define_singleton_method(:cache_table_version) { |_| "1" }
    c.define_singleton_method(:cache_module_records_version) { |_| "1" }
    c.define_singleton_method(:current_api_user_payload) { { "id" => user, "user_type" => "admin" } }
    c.define_singleton_method(:exact_admin_dashboard_data) { raise "Unexpected full dashboard calculation" }
    c
  end

  def test_status_requests_share_cards_and_cache_lists
    %w[summary red green yellow pending].each do |status|
      result = controller(status).send(:mobile_participation_payload, "admin")
      assert_equal [10, 2, 3, 5], result[:cards].map { |card| card[:value] }
    end
    %i[mapped no_training yellow green].each { |key| assert_equal 1, @calls[key] }
    assert_equal 1, @calls["red"]
    assert_equal 1, @calls["green"]
    assert_equal 1, @calls["yellow"]
    controller("green").send(:mobile_participation_payload, "admin")
    assert_equal 1, @calls["green"]
  end

  def test_cards_remain_isolated_by_month_and_user
    controller("summary").send(:mobile_participation_payload, "admin")
    controller("summary", "July").send(:mobile_participation_payload, "admin")
    controller("summary", "August", "2").send(:mobile_participation_payload, "admin")
    assert_equal 3, @calls[:mapped]
  end

  def test_fco_and_gender_widgets_share_only_their_calculation
    web = @web
    calls = @calls
    web.define_singleton_method(:dashboard_vrps) { [] }
    web.define_singleton_method(:dashboard_fco_active_vrp_records) do |fco, *_|
      calls[:gender] += 1
      [Struct.new(:gender).new("male")]
    end
    web.define_singleton_method(:normalize_dashboard_text) { |value| value.downcase }
    web.define_singleton_method(:dashboard_jj_requirement_items) do |fco, *_|
      [{ title: "#{fco} Required", value: 2 }, { title: "#{fco} Active", value: 1 }, { title: "#{fco} Vacant", value: 1 }]
    end
    c = controller("summary")
    c.define_singleton_method(:prepare_lightweight_admin_dashboard_context) { { web: web, targets: [] } }
    { "sausar_male" => 1, "turekela_female" => 0, "sausar_required" => 2 }.each do |widget, expected|
      config = c.send(:admin_dashboard_widget_catalog).fetch(widget)
      assert_equal expected, c.send(:lower_admin_widget_response, widget, config)[:value]
    end
    assert_equal 2, @calls[:gender]
  end

  def test_billing_widget_never_builds_full_dashboard
    @web.define_singleton_method(:dashboard_billing_records) { [:approved, :pending] }
    @web.define_singleton_method(:dashboard_bill_approved?) { |bill| bill == :approved }
    @web.define_singleton_method(:dashboard_bill_pending?) { |bill| bill == :pending }
    c = controller("summary")
    %w[bill_approved bill_pending].each do |widget|
      config = c.send(:admin_dashboard_widget_catalog).fetch(widget)
      assert_equal 1, c.send(:lower_admin_widget_response, widget, config)[:value]
    end
  end
end
