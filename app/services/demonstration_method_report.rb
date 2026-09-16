# Uses the same target population for both the FCO summary and VRP drill-down.
class DemonstrationMethodReport
  # View List (per-JJ drill-down) columns. Target values are village-deduped
  # per JJ before being displayed beside the matching training-form entry count.
  HEADERS = ["fco_id", "fco_name", "Cluster Coordinator", "vrp_id", "VRP Name", "OPG Target / Done",
    "General Training/Meeting", "Input Demo INM", "Input Demo PM", "FFS"].freeze
  # Dashboard summary-card metrics (FCO level). Kept separate from HEADERS because
  # the summary reports one count per method, not the Count/Farmer split above.
  METRICS = ["OPG Target", "Total Target / Done", "General Training/Meeting", "Input Demo INM", "Input Demo PM", "FFS"].freeze
  TARGET_DONE_COLUMNS = ["OPG Target / Done", "General Training/Meeting", "Input Demo INM", "Input Demo PM", "FFS"].freeze

  def initialize(targets:, month: "August")
    @target_ids = Array(targets).map(&:id).uniq
    @month = month.to_s.strip.downcase
  end

  def rows
    @rows ||= begin
      connection = TargetMapping.connection
      scope = TargetMapping.where(id: @target_ids)
      scope = scope.where("LOWER(TRIM(month_name)) = ?", @month) unless @month.blank? || @month == "all"
      month_filter = if @month.blank? || @month == "all"
        "TRUE"
      else
        "LOWER(TRIM(mr.data::jsonb ->> 'month')) = #{connection.quote(@month)}"
      end
      rows = connection.select_all(<<~SQL).to_a
        WITH scoped_targets AS (
          #{scope.to_sql}
        ), village_target AS (
          -- Ek village ka target sirf ek baar (village_id ke hisaab se MAX)
          SELECT t.fco_id, t.fco_name, t.vrp_id, t.village_id,
            MAX(COALESCE(t.opg_training_target, 0)) AS opg_training_target,
            MAX(COALESCE(t.week_wise_opg_target, 0)) AS general_training_target,
            MAX(COALESCE(t.input_demo_inm_target, 0)) AS input_demo_inm_target,
            MAX(COALESCE(t.input_demo_pm_target, 0)) AS input_demo_pm_target,
            MAX(COALESCE(t.ffs_target, 0)) AS ffs_target
          FROM scoped_targets t
          GROUP BY t.fco_id, t.fco_name, t.vrp_id, t.village_id
        ), vrp_target AS (
          SELECT fco_id, fco_name, vrp_id,
            SUM(opg_training_target) AS opg_training_target,
            SUM(general_training_target) AS general_training_target,
            SUM(input_demo_inm_target) AS input_demo_inm_target,
            SUM(input_demo_pm_target) AS input_demo_pm_target,
            SUM(ffs_target) AS ffs_target
          FROM village_target
          GROUP BY fco_id, fco_name, vrp_id
        ), entry_data AS (
          SELECT TRIM(mr.data::jsonb ->> 'created_by_id') AS vrp_id,
            COUNT(*) FILTER (
              WHERE LOWER(TRIM(mr.data::jsonb ->> 'training_method')) = 'general training/meeting'
            ) AS general_training_done,
            COUNT(*) FILTER (
              WHERE LOWER(TRIM(mr.data::jsonb ->> 'training_method')) = 'input demo inm'
            ) AS input_demo_inm_done,
            COUNT(*) FILTER (
              WHERE LOWER(TRIM(mr.data::jsonb ->> 'training_method')) = 'input demo pm'
            ) AS input_demo_pm_done,
            COUNT(*) FILTER (
              WHERE LOWER(TRIM(mr.data::jsonb ->> 'training_method')) = 'ffs'
            ) AS ffs_done
          FROM module_records mr
          WHERE mr.module_slug = 'training-form' AND #{month_filter}
          GROUP BY TRIM(mr.data::jsonb ->> 'created_by_id')
        )
        SELECT vt.fco_id, vt.fco_name,
          COALESCE(v.cluster_incharge, '') AS "Cluster Coordinator",
          vt.vrp_id,
          COALESCE(v.name, '') AS "VRP Name",
          (
            (
              vt.general_training_target +
              vt.input_demo_inm_target +
              vt.input_demo_pm_target +
              vt.ffs_target
            )::text || ' / ' ||
            (
              COALESCE(ed.general_training_done, 0) +
              COALESCE(ed.input_demo_inm_done, 0) +
              COALESCE(ed.input_demo_pm_done, 0) +
              COALESCE(ed.ffs_done, 0)
            )::text
          ) AS "OPG Target / Done",
          (
            vt.general_training_target::text || ' / ' ||
            COALESCE(ed.general_training_done, 0)::text
          ) AS "General Training/Meeting",
          (
            vt.input_demo_inm_target::text || ' / ' ||
            COALESCE(ed.input_demo_inm_done, 0)::text
          ) AS "Input Demo INM",
          (
            vt.input_demo_pm_target::text || ' / ' ||
            COALESCE(ed.input_demo_pm_done, 0)::text
          ) AS "Input Demo PM",
          (
            vt.ffs_target::text || ' / ' ||
            COALESCE(ed.ffs_done, 0)::text
          ) AS "FFS"
        FROM vrp_target vt
        LEFT JOIN vrps v ON v.id::text = vt.vrp_id::text
        LEFT JOIN entry_data ed ON ed.vrp_id = vt.vrp_id::text
        ORDER BY vt.fco_id, "Cluster Coordinator", vt.vrp_id
      SQL
      rows.each { |row| clean_target_done_columns!(row) }
    end
  end

  def summary
    @summary ||= begin
      connection = TargetMapping.connection
      scope = TargetMapping.where(id: @target_ids)
      scope = scope.where("LOWER(TRIM(month_name)) = ?", @month) unless @month.blank? || @month == "all"
      month_filter = @month.blank? || @month == "all" ? "TRUE" : "LOWER(TRIM(mr.data::jsonb ->> 'month')) = #{connection.quote(@month)}"
      connection.select_all(<<~SQL).to_a
        WITH scoped_targets AS (
          #{scope.to_sql}
        ), village_target AS (
          -- Ek village ka target sirf ek baar (village_id ke hisaab se MAX)
          SELECT t.fco_id, t.fco_name, t.village_id,
            MAX(COALESCE(t.opg_training_target, 0)) AS opg_training_target,
            MAX(COALESCE(t.week_wise_opg_target, 0)) AS general_training_target,
            MAX(COALESCE(t.input_demo_inm_target, 0)) AS input_demo_inm_target,
            MAX(COALESCE(t.input_demo_pm_target, 0)) AS input_demo_pm_target,
            MAX(COALESCE(t.ffs_target, 0)) AS ffs_target
          FROM scoped_targets t
          GROUP BY t.fco_id, t.fco_name, t.village_id
        ), fco_target AS (
          SELECT fco_id, fco_name,
            SUM(opg_training_target) AS opg_training_target,
            SUM(general_training_target) AS general_training_target,
            SUM(input_demo_inm_target) AS input_demo_inm_target,
            SUM(input_demo_pm_target) AS input_demo_pm_target,
            SUM(ffs_target) AS ffs_target
          FROM village_target GROUP BY fco_id, fco_name
        ), vrp_fco AS (
          SELECT DISTINCT t.fco_id, t.fco_name, t.vrp_id
          FROM scoped_targets t
        ), training_entries AS MATERIALIZED (
          -- Large form payloads are decoded before the FCO join and reused by
          -- all four counters, instead of decoding JSON again in each FILTER.
          SELECT TRIM(mr.data::jsonb ->> 'created_by_id') AS vrp_id,
            LOWER(TRIM(mr.data::jsonb ->> 'training_method')) AS training_method
          FROM module_records mr
          WHERE mr.module_slug = 'training-form' AND #{month_filter}
            AND TRIM(mr.data::jsonb ->> 'created_by_id') IN (
              SELECT DISTINCT vf.vrp_id::text FROM vrp_fco vf
            )
        ), entry_data AS (
          SELECT vf.fco_id, vf.fco_name,
            COUNT(*) FILTER (WHERE te.training_method = 'general training/meeting') AS general_training_meeting,
            COUNT(*) FILTER (WHERE te.training_method = 'input demo inm') AS input_demo_inm,
            COUNT(*) FILTER (WHERE te.training_method = 'input demo pm') AS input_demo_pm,
            COUNT(*) FILTER (WHERE te.training_method = 'ffs') AS ffs
          FROM training_entries te
          INNER JOIN vrp_fco vf
            ON vf.vrp_id::text = te.vrp_id
          GROUP BY vf.fco_id, vf.fco_name
        )
        SELECT ft.fco_id, ft.fco_name, ft.opg_training_target AS "OPG Target",
          (
            ft.general_training_target +
            ft.input_demo_inm_target +
            ft.input_demo_pm_target +
            ft.ffs_target
          ) AS "Total Target",
          (
            COALESCE(ed.general_training_meeting, 0) +
            COALESCE(ed.input_demo_inm, 0) +
            COALESCE(ed.input_demo_pm, 0) +
            COALESCE(ed.ffs, 0)
          ) AS "Total Done",
          ft.general_training_target AS "General Training/Meeting Target",
          COALESCE(ed.general_training_meeting, 0) AS "General Training/Meeting",
          COALESCE(ed.general_training_meeting, 0) AS "General Training/Meeting Done",
          ft.input_demo_inm_target AS "Input Demo INM Target",
          COALESCE(ed.input_demo_inm, 0) AS "Input Demo INM",
          COALESCE(ed.input_demo_inm, 0) AS "Input Demo INM Done",
          ft.input_demo_pm_target AS "Input Demo PM Target",
          COALESCE(ed.input_demo_pm, 0) AS "Input Demo PM",
          COALESCE(ed.input_demo_pm, 0) AS "Input Demo PM Done",
          ft.ffs_target AS "FFS Target",
          COALESCE(ed.ffs, 0) AS "FFS",
          COALESCE(ed.ffs, 0) AS "FFS Done"
        FROM fco_target ft
        LEFT JOIN entry_data ed ON ed.fco_id::text = ft.fco_id::text
        ORDER BY ft.fco_id
      SQL
    end
  end

  private

  def clean_target_done_columns!(row)
    TARGET_DONE_COLUMNS.each do |column|
      row[column] = row[column].to_s.gsub(/\d+(?:\.\d+)?/) { |number| trim_decimal_zeroes(number) }
    end
  end

  def trim_decimal_zeroes(number)
    number.sub(/(\.\d*?)0+\z/, "\\1").sub(/\.\z/, "")
  end
end
