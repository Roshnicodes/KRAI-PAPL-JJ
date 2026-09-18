require "test_helper"

class DemonstrationMethodReportTest < ActiveSupport::TestCase
  setup do
    @vrp = build_vrp("Demo VRP")
    @vrp.save!(validate: false)
    @second = build_vrp("Zero entries")
    @second.save!(validate: false)
    @targets = [target(@vrp, 3), target(@vrp, 4), target(@second, nil)]
    target(@vrp, 99, "July")
    [" General Training/Meeting ", "INPUT DEMO INM", "Input Demo PM", "FFS", "Other"].each do |method|
      entry(@vrp, method)
    end
    entry(@vrp, "FFS", "July")
    entry(@second, "FFS", "July")
  end

  test "de-duplicates targets per village and formats method target done values" do
    report = DemonstrationMethodReport.new(targets: @targets)
    assert_equal 2, report.rows.size
    first = report.rows.find { |row| row["vrp_id"] == @vrp.id }
    # View list OPG target is village-deduped per JJ: both @vrp targets (3 and 4)
    # share village_id "1", so the JJ total is MAX(3, 4) = 4, not the row SUM of 7.
    assert_equal "16 / 4", first["OPG Target / Done"]
    ["General Training/Meeting", "Input Demo INM", "Input Demo PM", "FFS"].each do |method|
      assert_equal "4 / 1", first[method]
    end
    zero = report.rows.find { |row| row["vrp_id"] == @second.id }
    ["General Training/Meeting", "Input Demo INM", "Input Demo PM", "FFS"].each do |method|
      assert_equal "0 / 0", zero[method]
    end
    assert_equal 1, report.summary.size
    # FCO summary also de-duplicates OPG target per village (MAX per village_id,
    # then SUM per FCO) => MAX(3, 4) = 4.
    assert_equal 4, report.summary.first["OPG Target"]
    assert_equal 1, report.summary.first["FFS"]
  end

  test "only includes supplied target scope and selected month" do
    report = DemonstrationMethodReport.new(targets: [@targets.last])
    assert_equal [@second.id], report.rows.map { |row| row["vrp_id"] }
    assert_equal 0, report.summary.first["FFS"]
    assert_empty DemonstrationMethodReport.new(targets: @targets, month: "July").rows
    assert_empty DemonstrationMethodReport.new(targets: []).summary
  end

  test "summary and view list both trim padded creator IDs" do
    ModuleRecord.create!(module_slug: "training-form", data: { created_by_id: " #{@vrp.id} ", month: "August", training_method: "FFS" })
    report = DemonstrationMethodReport.new(targets: @targets)
    assert_equal 2, report.summary.first["FFS"]
    # The view list now trims created_by_id too, so this padded record is counted
    # alongside the original FFS record => FFS done count 2.
    assert_equal "4 / 2", report.rows.find { |row| row["vrp_id"] == @vrp.id }["FFS"]
  end

  test "view list counts training form records without expanding farmer arrays" do
    shared = { created_by_id: " #{@vrp.id} ", month: " AUGUST ", training_method: " FFS " }
    ModuleRecord.create!(module_slug: "training-form", data: shared.merge(selected_farmer_ids: ["11", "11", "12", nil, ""]))
    ModuleRecord.create!(module_slug: "training-form", data: shared.merge(selected_farmer_ids: ["12", "13"]))
    ModuleRecord.create!(module_slug: "training-form", data: shared.merge(selected_farmer_ids: []))
    ModuleRecord.create!(module_slug: "training-form", data: shared.merge(created_by_id: "999999", selected_farmer_ids: ["99"]))
    report = DemonstrationMethodReport.new(targets: @targets)
    row = report.rows.find { |item| item["vrp_id"] == @vrp.id }
    # The original FFS entry plus three August FFS records count as four done records.
    assert_equal "4 / 4", row["FFS"]
    assert_equal 4, report.summary.first["FFS"]
    assert_equal "4 / 5", DemonstrationMethodReport.new(targets: @targets, month: "all").rows.find { |item| item["vrp_id"] == @vrp.id }["FFS"]
  end

  private

  def build_vrp(name)
    Vrp.new(name: name, aadhar_no: "123456789012", account_no: "1234", address: "Test", branch: "Test",
      date_of_birth: Date.new(1990, 1, 1), date_of_joining: Date.current, email: "#{SecureRandom.hex(4)}@example.com",
      experience_in_years: 1, father_husband_name: "Test", gender: :male, ifsc_code: "SBIN0001234",
      mobile_no: "9876543210", office_detail_id: 1, to_office_detail_id: 1)
  end

  def target(vrp, amount, month = " August ")
    TargetMapping.create!(vrp: vrp, fco_id: "demo", fco_name: "Demo FCO", ics_id: "1", village_id: "1",
      month_name: month, main_activity_name: "Training", activity_name: "Demo", target_quantity: 0,
      opg_training_target: amount,
      week_wise_opg_target: amount,
      input_demo_inm_target: amount,
      input_demo_pm_target: amount,
      ffs_target: amount)
  end

  def entry(vrp, method, month = " AUGUST ")
    ModuleRecord.create!(module_slug: "training-form", data: { created_by_id: vrp.id.to_s, month: month, training_method: method })
  end
end
