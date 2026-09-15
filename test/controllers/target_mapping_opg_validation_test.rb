require "test_helper"

class TargetMappingOpgValidationTest < ActiveSupport::TestCase
  def error_for(training_targets)
    controller = TargetMappingsController.new
    controller.define_singleton_method(:training_target_mode?) { true }
    controller.define_singleton_method(:target_mapping_params) do
      ActionController::Parameters.new(training_targets: training_targets).permit!
    end
    controller.send(:training_target_opg_error)
  end

  test "exposure widget uses the existing FFS dashboard value" do
    catalog = Api::V1::JeevikaJankarDashboardController.new.send(:admin_dashboard_widget_catalog)
    assert_equal catalog.fetch("ffs")[:path], catalog.fetch("ffs_exposure")[:path]
    assert_equal "FFS Exposure", catalog.fetch("ffs_exposure")[:heading]
  end

  test "requires every training field even when supplied values add up" do
    assert error_for("opg_training" => "20", "week_wise_opg" => "20")
    assert error_for({})
    assert error_for(nil)
  end

  test "blocks when the four breakdown boxes exceed OPG Training" do
    error = error_for(
      "opg_training" => "20", "week_wise_opg" => "10",
      "input_demo_inm" => "10", "input_demo_pm" => "10", "ffs" => "10"
    )
    assert error, "expected a validation error for 40 > 20"
    assert_includes error, "(40)"
    assert_includes error, "(20)"
  end

  test "allows when the breakdown total equals OPG Training" do
    assert_nil error_for(
      "opg_training" => "20", "week_wise_opg" => "5",
      "input_demo_inm" => "5", "input_demo_pm" => "5", "ffs" => "5"
    )
  end

  test "requires the full OPG allocation before saving" do
    assert error_for("opg_training" => "20", "week_wise_opg" => "5", "input_demo_inm" => "5")
  end

  test "blocks when a single box alone exceeds OPG Training" do
    assert error_for("opg_training" => "20", "week_wise_opg" => "21")
  end

  test "requires OPG when breakdown values are present" do
    assert error_for("week_wise_opg" => "5", "ffs" => "5")
  end
  test "rejects negative and fractional breakdown values" do
    assert error_for("opg_training" => "20", "week_wise_opg" => "-1", "ffs" => "21")
    assert error_for("opg_training" => "20", "week_wise_opg" => "19.5")
  end

  test "allows a zero allocation in unused categories" do
    assert_nil error_for("opg_training" => "20", "week_wise_opg" => "20", "input_demo_inm" => "0", "input_demo_pm" => "0", "ffs" => "0")
  end

end
