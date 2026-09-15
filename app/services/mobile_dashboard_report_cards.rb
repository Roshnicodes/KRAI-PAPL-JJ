# Additive display data; the legacy report arrays and SQL column names remain intact.
class MobileDashboardReportCards
  DEMONSTRATION = {
    "opg_training_target" => ["OPG Training Target", "OPG Target"],
    "general_training_meeting" => ["General Training/Meeting", "General Training/Meeting"],
    "input_demo_inm" => ["Input Demo INM", "Input Demo INM"],
    "input_demo_pm" => ["Input Demo PM", "Input Demo PM"],
    "ffs_exposure" => ["FFS Exposure", "FFS"]
  }.freeze

  def self.demonstration_cards(rows)
    DEMONSTRATION.map do |key, (heading, metric)|
      total = rows.sum { |row| row[metric].to_f }
      { key: key, heading: heading, value: total == total.to_i ? total.to_i : total }
    end
  end

  def self.cc_jj_rows(rows)
    rows.map do |row|
      row.merge("fco_name" => { "1004" => "Sausar", "1006" => "Turekela" }[row["fco_id"].to_s],
        "total_cc" => row["toatl_cc"].to_i, "total_jj" => row["toatl_jj"].to_i)
    end
  end

  def self.cc_jj_groups(rows)
    { "1004" => "Sausar", "1006" => "Turekela" }.map do |id, name|
      statuses = %w[Red Completed].to_h do |status|
        row = rows.find { |item| item["fco_id"].to_s == id && item["status"].to_s.casecmp?(status) } || {}
        [status.downcase.to_sym, { cc: row["toatl_cc"].to_i, jj: row["toatl_jj"].to_i }]
      end
      { fco_id: id, fco_name: name, **statuses }
    end
  end
end
