require "minitest/autorun"
require_relative "../app/services/mobile_dashboard_report_cards"

class MobileDashboardReportCardsUnitTest < Minitest::Test
  def test_cc_jj_uses_legacy_columns_and_groups_by_fco
    rows = [
      { "fco_id" => "1004", "status" => "Red", "toatl_cc" => 4, "toatl_jj" => 6 },
      { "fco_id" => "1004", "status" => "Completed", "toatl_cc" => 2, "toatl_jj" => 28 },
      { "fco_id" => "1006", "status" => "Red", "toatl_cc" => 3, "toatl_jj" => 7 },
      { "fco_id" => "1006", "status" => "Completed", "toatl_cc" => 2, "toatl_jj" => 17 }
    ]
    normalized = MobileDashboardReportCards.cc_jj_rows(rows)
    assert_equal 4, normalized.first["total_cc"]
    assert_equal 6, normalized.first["total_jj"]
    assert_equal 4, normalized.first["toatl_cc"]
    assert_equal "Sausar", normalized.first["fco_name"]
    groups = MobileDashboardReportCards.cc_jj_groups(rows)
    assert_equal %w[Sausar Turekela], groups.map { |group| group[:fco_name] }
    assert_equal({ cc: 4, jj: 6 }, groups[0][:red])
    assert_equal({ cc: 2, jj: 28 }, groups[0][:completed])
    assert_equal({ cc: 3, jj: 7 }, groups[1][:red])
    assert_equal({ cc: 2, jj: 17 }, groups[1][:completed])
  end

  def test_missing_statuses_are_zero
    assert MobileDashboardReportCards.cc_jj_groups([]).all? { |group| group[:red] == { cc: 0, jj: 0 } && group[:completed] == { cc: 0, jj: 0 } }
  end

  def test_demonstration_totals_parse_decimal_strings_and_preserve_ffs_metric
    cards = MobileDashboardReportCards.demonstration_cards([
      { "OPG Target" => "10.5", "General Training/Meeting" => 3, "FFS" => 2 },
      { "OPG Target" => "2.5", "General Training/Meeting" => 1, "FFS" => 3 }
    ])
    assert_equal [13, 4, 0, 0, 5], cards.map { |card| card[:value] }
    assert_equal "ffs_exposure", cards.last[:key]
  end
end
