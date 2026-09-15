module Api
  module V1
    class JeevikaJankarDashboardController < BaseController
      def show
        if request.path.end_with?("/admin-dashboard") && !admin_dashboard_request?
          return render json: { success: false, message: "Admin login required." }, status: :forbidden
        end

        return render_admin_dashboard if admin_dashboard_request?

        vrp = current_dashboard_vrp
        return render json: { success: false, message: "Valid Jeevika Jankar login required." }, status: :unprocessable_entity unless vrp

        context = jj_dashboard_context(vrp)
        progress = web_parity_progress(context[:targets], vrp)

        render json: {
          success: true,
          message: "Jeevika Jankar dashboard fetched successfully.",
          jeevika_jankar: { id: vrp.id, name: vrp.name, user_name: vrp.user_name, mobile_no: vrp.mobile_no },
          dashboard_type: "jeevika_jankar",
          months: context[:months],
          selected_month: context[:month],
          cards: vrp_dashboard_widget_catalog.keys.to_h { |key| [key, jj_widget_value(key, vrp)] },
          target_progress: progress,
          weekly_target_plan: jj_weekly_rows(vrp),
          selected_week: jj_selected_week,
          generated_at: Time.current.iso8601
        }, status: :ok
      end

      def list
        unless admin_dashboard_request?
          return render json: { success: false, message: "Admin login required." }, status: :forbidden
        end

        payload = cached_admin_dashboard_list_payload(params[:list_type])
        return render json: { success: false, message: "Invalid dashboard list type.", available_list_types: admin_dashboard_list_catalog.keys }, status: :unprocessable_entity unless payload

        render json: {
          success: true,
          message: "#{payload[:title]} fetched successfully.",
          dashboard_type: "admin",
          list_type: params[:list_type],
          title: payload[:title],
          filters: admin_filter_payload,
          count: payload[:records].size,
          records: payload[:records]
        }, status: :ok
      end

      # A mobile-only XLSX export. The web dashboard routes and views are not used.
      def export
        unless admin_dashboard_request?
          return render json: { success: false, message: "Admin login required." }, status: :forbidden
        end

        payload = cached_admin_dashboard_list_payload(params[:list_type])
        return render json: { success: false, message: "Invalid dashboard list type.", available_list_types: admin_dashboard_list_catalog.keys }, status: :unprocessable_entity unless payload

        send_dashboard_list_export(payload)
      end

      # Dynamic one-box endpoint for React Native dashboard cards.
      def widget
        unless admin_dashboard_request?
          return render json: { success: false, message: "Admin login required." }, status: :forbidden
        end

        config = admin_dashboard_widget_catalog[params[:widget]]
        return render json: { success: false, message: "Invalid dashboard widget.", available_widgets: admin_dashboard_widget_catalog.keys }, status: :unprocessable_entity unless config

        if report_widget?(params[:widget])
          return render json: report_widget_response(params[:widget], config, "admin")
        end

        dashboard = cached_admin_dashboard_summary
        value = config[:path].reduce(dashboard) { |data, key| data.respond_to?(:[]) ? data[key] || data[key.to_s] : nil }
        value = value.size if config[:count]
        render json: { success: true, dashboard_type: "admin", widget: params[:widget], heading: config[:heading], value: value, filters: dashboard[:filters], generated_at: Time.current.iso8601 }
      end

      # Dropdown data for the React Native Admin dashboard. This is separate
      # from the web form and dynamically reflects the current database.
      def filters
        unless admin_dashboard_request?
          return render json: { success: false, message: "Admin login required." }, status: :forbidden
        end

        render json: mobile_dashboard_filters_payload("admin")
      end

      def farmer_training_participation
        unless admin_dashboard_request?
          return render json: { success: false, message: "Admin login required." }, status: :forbidden
        end

        response = mobile_participation_payload("admin")

        render json: response, status: :ok
      end

      # JJ dashboard table/card drill-downs for the React Native app.
      def vrp_list
        vrp = current_dashboard_vrp
        return render json: { success: false, message: "Valid Jeevika Jankar login required." }, status: :unprocessable_entity unless vrp

        payload = vrp_dashboard_list_payload(vrp, params[:list_type])
        return render json: { success: false, message: "Invalid dashboard list type.", available_list_types: vrp_dashboard_list_catalog.keys }, status: :unprocessable_entity unless payload

        render json: { success: true, dashboard_type: "jeevika_jankar", list_type: params[:list_type], **payload, generated_at: Time.current.iso8601 }
      end

      def vrp_export
        vrp = current_dashboard_vrp
        return render json: { success: false, message: "Valid Jeevika Jankar login required." }, status: :unprocessable_entity unless vrp

        payload = vrp_dashboard_list_payload(vrp, params[:list_type])
        return render json: { success: false, message: "Invalid dashboard list type.", available_list_types: vrp_dashboard_list_catalog.keys }, status: :unprocessable_entity unless payload

        send_dashboard_list_export(payload)
      end

      def vrp_widget
        vrp = current_dashboard_vrp
        return render json: { success: false, message: "Valid Jeevika Jankar login required." }, status: :unprocessable_entity unless vrp

        config = vrp_dashboard_widget_catalog[params[:widget]]
        return render json: { success: false, message: "Invalid dashboard widget.", available_widgets: vrp_dashboard_widget_catalog.keys }, status: :unprocessable_entity unless config

        context = jj_dashboard_context(vrp)
        value = jj_widget_value(params[:widget], vrp)
        render json: { success: true, dashboard_type: "jeevika_jankar", widget: params[:widget], heading: config, value: value, filters: { month: context[:month] }, generated_at: Time.current.iso8601 }
      end

      def vrp_filters
        vrp = current_dashboard_vrp
        return render json: { success: false, message: "Valid Jeevika Jankar login required." }, status: :unprocessable_entity unless vrp

        context = jj_dashboard_context(vrp)
        render json: { success: true, dashboard_type: "jeevika_jankar", months: context[:months], selected_month: context[:month],
          weeks: [{ value: "all", label: "All Weeks" }] + (1..4).map { |week| { value: "week_#{week}", label: "Week #{week}" } },
          selected_week: jj_selected_week }
      end

      private

      def admin_dashboard_request?
        user = current_api_user_payload
        user["user_type"].to_s.casecmp("admin").zero? &&
          (request.path.include?("/admin-dashboard") || filter_param(:vrp_id).blank?)
      end

      def vrp_dashboard_list_catalog
        {
          "mapped_villages" => "Mapped Villages List",
          "main_activities" => "Main Activities List",
          "sub_activities" => "Sub Activities List",
          "assigned_target" => "Assigned Target Progress List",
          "mapped_farmers" => "Assigned Farmers List",
          "achieved_target" => "Achieved Target List",
          "pending_target" => "Pending Target List",
          "target_progress" => "Assigned Target Progress List",
          "weekly_target_plan" => "Weekly Target Plan"
        }
      end

      DEMONSTRATION_WIDGET_METRICS = {
        "opg_training_target" => "OPG Target", "general_training_meeting" => "General Training/Meeting",
        "input_demo_inm" => "Input Demo INM", "input_demo_pm" => "Input Demo PM",
        "ffs" => "FFS", "ffs_exposure" => "FFS"
      }.freeze

      def report_widget?(widget)
        %w[cc_jj_work_status demonstration_method].include?(widget) || DEMONSTRATION_WIDGET_METRICS.key?(widget)
      end

      # All five demonstration cards share one report fill, without building unrelated sections.
      def report_widget_response(widget, config, dashboard_type)
        kind = widget == "cc_jj_work_status" ? widget : "demonstration_method"
        payload = cache_admin_dashboard_payload("#{dashboard_type}/report-widget/#{kind}") do
          web = mobile_participation_calculator
          if kind == "cc_jj_work_status"
            rows = CcJjWorkStatusReport.new(calculator: web).summary
          else
            if dashboard_type == "user"
              _, targets, = filtered_scope(web)
            else
              context = prepare_lightweight_admin_dashboard_context
              targets = context[:targets]
            end
            rows = DemonstrationMethodReport.new(targets: targets,
              month: params.key?(:month) ? filter_param(:month) : Date.current.prev_month.strftime("%B")).summary
          end
          { rows: rows, filters: admin_filter_payload.merge(
            month: params.key?(:month) ? filter_param(:month) : Date.current.prev_month.strftime("%B")) }
        end
        rows = payload[:rows]
        metric = DEMONSTRATION_WIDGET_METRICS[widget]
        value = metric ? number(rows.sum { |row| row[metric].to_f }) : rows
        extra = kind == "cc_jj_work_status" ? { groups: MobileDashboardReportCards.cc_jj_groups(rows) } :
          { cards: MobileDashboardReportCards.demonstration_cards(rows) }
        { success: true, dashboard_type: dashboard_type, widget: widget, heading: config[:heading],
          value: value, filters: payload[:filters], **extra, generated_at: Time.current.iso8601 }
      end

      def vrp_dashboard_widget_catalog
        {
          "mapped_villages" => "Mapped Villages",
          "main_activities" => "Main Activities",
          "sub_activities" => "Sub Activities",
          "assigned_target" => "Assigned Target",
          "mapped_farmers" => "Assigned Farmers",
          "achieved_target" => "Achieved Target",
          "pending_target" => "Pending Target"
        }
      end

      def admin_dashboard_widget_catalog
        {
          "cc_jj_work_status" => { heading: "CC and JJ Work Status", path: %i[cc_jj_work_status] },
          "demonstration_method" => { heading: "Demonstration Method", path: %i[demonstration_method] },
          "total_ics_count" => { heading: "Total ICS Count", path: [ :mobile_widget_values, "Total ICS Count" ] },
          "total_registered" => { heading: "Total Registered Jeevika Jankar", path: %i[sections registration total_registered] },
          "final_approved" => { heading: "Final Approved", path: %i[sections registration final_approved] },
          "pending_approval" => { heading: "Pending Approval", path: %i[sections registration pending_approval] },
          "target_records" => { heading: "Target Records", path: %i[sections target_assignment target_records] },
          "without_target" => { heading: "Without Target", path: %i[sections target_assignment without_target] },
          "activities_assigned" => { heading: "Activities Assigned", path: %i[sections target_assignment activities_assigned] },
          "without_activity" => { heading: "Without Activity", path: %i[sections target_assignment without_activity] },
          "level_2_users" => { heading: "Level 2 Users", path: %i[sections billing level_2_users] },
          "bill_approved" => { heading: "Bill Approved", path: %i[sections billing bill_approved] },
          "bill_pending" => { heading: "Bill Pending", path: %i[sections billing bill_pending] },
          "total_villages_count" => { heading: "Total Villages Count", path: [ :mobile_widget_values, "Total Villages Count" ] },
          "total_farmer_count" => { heading: "Total Farmer Count", path: [ :mobile_widget_values, "Total Farmer Count" ] },
          "total_mapped_main_activities" => { heading: "Total Mapped Main Major Work Indicators", path: [ :mobile_widget_values, "Total Mapped Main Activities" ] },
          "total_mapped_sub_activities" => { heading: "Total Mapped Sub-Major Work Indicators", path: [ :mobile_widget_values, "Total Mapped Sub-Activities" ] },
          "mapped_farmer" => { heading: "Mapped Farmer", path: %i[farmer_training_participation_status total_unique_farmers_distinct] },
          "no_training" => { heading: "No Training", path: [ :mobile_widget_values, "No Training" ] },
          "only_1_training" => { heading: "Only 1 Training", path: [ :mobile_widget_values, "Yellow" ] },
          "one_plus_trainings" => { heading: "1+ Trainings", path: [ :mobile_widget_values, "Green" ] },
          "opg_training_target" => { heading: "OPG Training Target", path: [ :mobile_widget_values, "OPG Training Target" ] },
          "opg_training_achievement" => { heading: "OPG Training Achievement", path: [ :mobile_widget_values, "OPG Training Achievement" ] },
          "general_training_meeting" => { heading: "General Training/Meeting", path: [ :mobile_widget_values, "General Training/Meeting" ] },
          "input_demo_inm" => { heading: "Input Demo INM", path: [ :mobile_widget_values, "Input Demo INM" ] },
          "ffs_exposure" => { heading: "FFS Exposure", path: [ :mobile_widget_values, "FFS Exposure" ] },
          "ffs" => { heading: "FFS", path: [ :mobile_widget_values, "FFS Exposure" ] },
          "input_demo_pm" => { heading: "Input Demo PM", path: [ :mobile_widget_values, "Input Demo PM" ] },
          "sausar_required" => { heading: "Sausar Required", path: [ :mobile_widget_values, "Sausar Required" ] },
          "sausar_active" => { heading: "Sausar Active", path: [ :mobile_widget_values, "Sausar Active" ] },
          "sausar_vacant" => { heading: "Sausar Vacant", path: [ :mobile_widget_values, "Sausar Vacant" ] },
          "turekela_required" => { heading: "Turekela Required", path: [ :mobile_widget_values, "Turekela Required" ] },
          "turekela_active" => { heading: "Turekela Active", path: [ :mobile_widget_values, "Turekela Active" ] },
          "turekela_vacant" => { heading: "Turekela Vacant", path: [ :mobile_widget_values, "Turekela Vacant" ] },
          "sausar_male" => { heading: "Sausar Male", path: [ :mobile_widget_values, "Sausar Male" ] },
          "sausar_female" => { heading: "Sausar Female", path: [ :mobile_widget_values, "Sausar Female" ] },
          "turekela_male" => { heading: "Turekela Male", path: [ :mobile_widget_values, "Turekela Male" ] },
          "turekela_female" => { heading: "Turekela Female", path: [ :mobile_widget_values, "Turekela Female" ] }
        }
      end

      # Mobile-only cascade. Load visible mappings, without calculating dashboard reports.
      def mobile_dashboard_filters_payload(dashboard_type)
        calculator = ModulesController.new
        calculator.request = request
        calculator.instance_variable_set(:@current_app_user, current_api_user_payload)
        targets = calculator.send(:dashboard_target_mappings).to_a
        mobile_dashboard_filter_options(targets, calculator).merge(
          success: true, dashboard_type: dashboard_type, generated_at: Time.current.iso8601
        )
      end

      def mobile_dashboard_filter_options(targets, calculator)
        values = ->(rows, &block) { rows.filter_map { |row| block.call(row).to_s.strip.presence }.uniq.sort }
        matches = ->(actual, selected) {
          calculator.send(:normalize_dashboard_text, actual) == calculator.send(:normalize_dashboard_text, selected)
        }
        months = values.call(targets, &:month_name).sort_by { |month| [calculator.send(:dashboard_month_index, month), month] }
        month = params.key?(:month) ? filter_param(:month) : Date.current.prev_month.strftime("%B")
        rows = month.present? ? targets.select { |row| matches.call(row.month_name, month) } : targets
        mains = values.call(rows, &:main_activity_name)
        main = params.key?(:main_activity) ? filter_param(:main_activity) : default_farmer_activity_filter(calculator, mains)
        rows = rows.select { |row| matches.call(row.main_activity_name, main) } if main.present?
        subs = values.call(rows, &:activity_name)
        sub = filter_param(:sub_activity)
        sub = nil unless subs.any? { |value| matches.call(value, sub) }
        rows = rows.select { |row| matches.call(row.activity_name, sub) } if sub.present?
        fcos = values.call(rows) { |row| row.vrp&.fcoc }
        fco = filter_param(:fcoc, :fco)
        fco = nil unless fcos.any? { |value| matches.call(value, fco) }
        rows = rows.select { |row| matches.call(row.vrp&.fcoc, fco) } if fco.present?
        ics_names = values.call(rows) { |row| row.ics_name.presence || row.ics_id }
        ics = filter_param(:ics, :ics_name)
        ics = nil unless ics_names.any? { |value| matches.call(value, ics) }
        {
          filters: dashboard_filter_groups(main_activities: mains, sub_activities: subs,
            fcos: fcos, ics_names: ics_names, months: months),
          applied_filters: { month: month, main_activity: main, sub_activity: sub, fco: fco, ics: ics },
          filter_order: %w[month main_activity sub_activity fco ics]
        }
      end

      def dashboard_filter_groups(main_activities:, sub_activities:, fcos:, ics_names:, months:)
        [
          { key: "main_activity", heading: "Main Major Work Indicator", all_option: "All Main Major Work Indicators", options: Array(main_activities) },
          { key: "sub_activity", heading: "Sub Major Work Indicator", all_option: "All Sub Major Work Indicators", options: Array(sub_activities) },
          { key: "fco", heading: "FCO", all_option: "All FCO", options: Array(fcos) },
          { key: "ics", heading: "ICS Name", all_option: "All ICS", options: Array(ics_names) },
          { key: "month", heading: "Month", all_option: "All Months", options: Array(months) }
        ]
      end

      def vrp_dashboard_list_payload(vrp, list_type)
        return unless vrp_dashboard_list_catalog.key?(list_type)

        context = jj_dashboard_context(vrp)
        targets = context[:targets]
        calculator = context[:calculator]
        records = case list_type
        when "mapped_villages"
          progress_by_village = jj_raw_progress(vrp).group_by do |row|
            calculator.send(:dashboard_target_village_key, row[:target_record])
          end
          targets_by_id = targets.index_by(&:id)
          calculator.send(:vrp_dashboard_village_rows, vrp, [], targets).map do |village|
            key = calculator.send(:dashboard_target_village_key, targets_by_id.fetch(village[:mapping_id]))
            rows = progress_by_village.fetch(key, [])
            village.merge(target_records: rows.size, assigned: number(rows.sum { |row| row[:target].to_f }),
              achieved: number(rows.sum { |row| row[:completed].to_f }), pending: number(rows.sum { |row| row[:pending].to_f }))
          end
        when "mapped_farmers"
          ids = jj_raw_progress(vrp).flat_map { |row| Array(row[:assigned_farmer_ids]) }.map(&:to_s).reject(&:blank?).uniq
          farmers = Afl.where(id: ids).index_by { |farmer| farmer.id.to_s }
          ids.map do |id|
            farmer = farmers[id]
            { farmer_id: id, assignment_status: "Assigned", farmer_name: farmer&.farmer_name,
              father_name: farmer&.father_name, tracenet_no: farmer&.tracenet_no,
              ics: farmer&.ics_name.presence || farmer&.ics_id,
              village: farmer&.village_name.presence || farmer&.village_id }
          end
        when "main_activities", "sub_activities"
          field = list_type == "main_activities" ? :main_activity : :sub_activity
          web_parity_progress(targets, vrp).group_by { |row| row[field].to_s }.map do |name, rows|
            { field => name, target_records: rows.size, assigned: number(rows.sum { |row| row[:assigned].to_f }),
              achieved: number(rows.sum { |row| row[:achieved].to_f }), pending: number(rows.sum { |row| row[:pending].to_f }) }
          end
        when "achieved_target"
          web_parity_progress(targets, vrp).select { |row| row[:achieved].to_f.positive? }
        when "pending_target"
          web_parity_progress(targets, vrp).select { |row| row[:pending].to_f.positive? }
        when "weekly_target_plan"
          jj_weekly_rows(vrp)
        else
          web_parity_progress(targets, vrp)
        end
        { title: vrp_dashboard_list_catalog.fetch(list_type), count: records.size, records: records,
          filters: { month: context[:month], target_week: jj_selected_week },
          total: vrp_dashboard_widget_catalog.key?(list_type) ? jj_widget_value(list_type, vrp) : records.size }
      end

      def jj_dashboard_context(vrp)
        @jj_dashboard_context ||= begin
          calculator = ModulesController.new
          calculator.set_request!(request)
          calculator.params = params.dup
          identity = app_user_session_payload(vrp)
          calculator.define_singleton_method(:current_app_user) { identity }
          calculator.instance_variable_set(:@current_vrp_record, vrp)
          targets = calculator.send(:vrp_dashboard_targets, vrp)
          months = calculator.send(:dashboard_month_options_for_targets, targets)
          requested = params[:month].presence || params[:training_month].presence
          month = requested.present? ? (all_filter_value?(requested) ? nil : requested.to_s.strip) : calculator.send(:default_vrp_dashboard_month, months, targets)
          targets = targets.select { |target| same_text?(target.month_name, month) } if month.present?
          { calculator: calculator, targets: targets, months: months, month: month }
        end
      end

      def jj_raw_progress(vrp)
        @jj_raw_progress ||= begin
          context = jj_dashboard_context(vrp)
          calculator = context[:calculator]
          calculator.send(:preload_training_farmers_for_targets!, context[:targets])
          calculator.send(:vrp_dashboard_target_progress_rows, context[:targets], calculator.send(:vrp_dashboard_bills, vrp))
        end
      end

      def jj_widget_value(key, vrp)
        context = jj_dashboard_context(vrp)
        targets = context[:targets]
        case key
        when "mapped_villages" then context[:calculator].send(:vrp_dashboard_village_rows, vrp, [], targets).size
        when "main_activities" then unique_count(targets, :main_activity_name)
        when "sub_activities" then unique_count(targets, :activity_name)
        when "mapped_farmers" then jj_raw_progress(vrp).flat_map { |row| Array(row[:assigned_farmer_ids]) }.map(&:to_s).reject(&:blank?).uniq.size
        else
          totals = context[:calculator].send(:vrp_dashboard_target_totals, jj_raw_progress(vrp))
          number(totals.fetch({ "assigned_target" => :assigned, "achieved_target" => :achieved, "pending_target" => :pending }.fetch(key)))
        end
      end

      def jj_selected_week
        value = params[:target_week].to_s
        %w[week_1 week_2 week_3 week_4].include?(value) ? value : "all"
      end

      def jj_weekly_rows(vrp)
        jj_raw_progress(vrp).map do |row|
          item = row.slice(:target_mapping_id, :month, :village, :main_activity, :activity, :main_activities, :sub_activities,
            :target, :week_1, :week_2, :week_3, :week_4, :week_1_achieved, :week_2_achieved, :week_3_achieved, :week_4_achieved,
            :completed, :pending, :completion_date)
          if jj_selected_week != "all"
            item = item.merge(selected_week: jj_selected_week, week_plan: row[jj_selected_week.to_sym], week_achieved: row["#{jj_selected_week}_achieved".to_sym],
              week_pending: [row[jj_selected_week.to_sym].to_f - row["#{jj_selected_week}_achieved".to_sym].to_f, 0].max)
          end
          item
        end
      end

      def render_admin_dashboard
        dashboard = cached_admin_dashboard_summary

        render json: {
          success: true,
          message: "Admin dashboard fetched successfully.",
          dashboard_type: "admin",
          user: current_api_user_payload,
          **dashboard,
          generated_at: Time.current.iso8601
        }, status: :ok
      end

      def cached_admin_dashboard_summary
        @cached_admin_dashboard_summary ||= cache_admin_dashboard_payload("summary") { exact_admin_dashboard_data }
      end

      def cached_admin_dashboard_list_payload(list_type)
        return unless admin_dashboard_list_catalog.key?(list_type)

        cache_admin_dashboard_payload("list/#{list_type}") do
          if lightweight_admin_dashboard_list_type?(list_type)
            prepare_lightweight_admin_dashboard_context
          else
            exact_admin_dashboard_data
          end
          admin_dashboard_list_payload(list_type)
        end
      end

      # Reuse the current web card and drill-down calculations without rendering HTML.
      def mobile_participation_calculator
        ModulesController.new.tap do |web|
          web.request = request
          web.instance_variable_set(:@current_app_user, current_api_user_payload)
        end
      end

      def mobile_participation_payload(dashboard_type)
        web = mobile_participation_calculator
        month = filter_param(:participation_month, :training_month, :month)
        month = Date.current.prev_month.strftime("%B") unless %i[participation_month training_month month].any? { |key| params.key?(key) }
        fco = filter_param(:participation_fcoc, :training_fcoc, :fcoc, :fco)
        week = params[:week].presence || params[:weekly_target_week]
        week = (1..4).include?(week.to_i) ? week.to_i : nil
        args = { month_name: month, fcoc_name: fco }
        mapped, mapped_popups = web.send(:farmer_training_mapped_farmer_count_and_popups, **args)
        red, red_popups, breakdown = web.send(:farmer_training_no_training_count_and_popups, **args)
        yellow, yellow_popups = web.send(:farmer_training_yellow_farmer_count_and_popups, **args)
        green, green_popups = web.send(:farmer_training_green_farmer_count_and_popups, **args)
        status = params[:status].to_s.presence || "unique"
        status = { "mapped" => "unique", "pending" => "red", "only_1_training" => "yellow",
          "one_plus_trainings" => "green" }.fetch(status, status)
        supported = %w[summary unique red yellow green no_activity no_training_mapping training_mapped_no_entry]
        # Preserve legacy total/training list requests.
        return cached_admin_dashboard_participation_payload unless supported.include?(status)

        rows = status == "summary" ? [] : web.send(:farmer_training_participation_rows_from_sql,
          status, **args, week_number: week)
        cards = [
          { key: "mapped_farmer", title: "Mapped Farmer", status: "unique", value: mapped, popups: mapped_popups },
          { key: "no_training", title: "Pending", status: "red", value: red, popups: red_popups },
          { key: "only_1_training", title: "Only 1 Training", status: "yellow", value: yellow, popups: yellow_popups },
          { key: "one_plus_trainings", title: "1+ Trainings", status: "green", value: green, popups: green_popups }
        ]
        {
          success: true, dashboard_type: dashboard_type, title: "Farmer Training Participation Status",
          status: status, selected_month: month, selected_fcoc: fco, selected_week: week,
          cards: cards, red_fco_details: breakdown,
          totals: { total_unique_farmers_distinct: mapped, red: red, yellow: yellow, green: green, pending: red },
          count: rows.size, farmers: rows, generated_at: Time.current.iso8601
        }
      end

      def cached_admin_dashboard_participation_payload
        cache_admin_dashboard_payload("farmer-training-participation/#{normalize_participation_list_status(params[:status])}") do
          exact_admin_dashboard_data
          context = @admin_dashboard_api_context
          web = context[:web]
          status = normalize_participation_list_status(params[:status])
          records = context[:participation_records]
          population = context[:participation_population]
          trained_rows = web.send(:training_participation_farmer_rows_from_records, records)
          unique_rows = web.send(:training_afl_farmer_rows_for_participation,
            month_name: context[:participation_month], fcoc_name: filter_param(:participation_fcoc, :training_fcoc))
          status_counts = web.send(:training_participation_status_counts_from_rows, population)

          rows = case status
          when "unique" then unique_rows
          when "training_unique", "total" then trained_rows
          when "green", "yellow", "red", "pending"
            population.select { |row| row[:status] == status }
          end

          {
            success: true,
            message: "Farmer Training Participation list fetched successfully.",
            dashboard_type: "admin",
            title: participation_list_title(status),
            status: status,
            selected_month: context[:participation_month_value],
            selected_fcoc: filter_param(:participation_fcoc, :training_fcoc),
            totals: {
              total_training_farmer: web.send(:training_total_farmer_count_from_records, records),
              total_unique_farmers_distinct: unique_rows.size,
              training_unique_farmers: web.send(:training_unique_farmer_count_from_records, records),
              green: status_counts[:green].to_i,
              yellow: status_counts[:yellow].to_i,
              red: status_counts[:red].to_i,
              pending: status_counts[:pending].to_i
            },
            count: rows.size,
            farmers: rows
          }
        end
      end

      def cache_admin_dashboard_payload(suffix)
        fill_key = [suffix, current_api_user_payload, admin_dashboard_cache_filters].to_json
        DashboardCacheFill.synchronize(fill_key) do
          Rails.cache.fetch(admin_dashboard_cache_key(suffix), expires_in: 10.minutes, race_condition_ttl: 30.seconds) { yield }
        end
      rescue StandardError => error
        Rails.logger.warn("Admin dashboard cache skipped: #{error.class}: #{error.message}")
        yield
      end

      def admin_dashboard_cache_key(suffix)
        version_parts = [
          cache_table_version(TargetMapping),
          cache_table_version(VrpIcsMapping),
          cache_table_version(Vrp),
          cache_table_version(Afl),
          cache_module_records_version(%w[
            training-form
            jeevika-jankar-bill-process
            add-vrp
            add-activity
            add-activity-group
            farmer-activity-master
            add-ics
            add-fco
            add-village
          ])
        ]
        filters = admin_dashboard_cache_filters
        user_key = current_api_user_payload.slice("id", "user_id", "username", "user_name", "user_type").sort.to_h
        ["api-v1-admin-dashboard-work-status-v9", suffix, user_key, filters, version_parts].to_json
      end

      def admin_dashboard_cache_filters
        # The widget selects a value from the same summary; it does not change
        # any calculation. All cards with identical filters share a cache fill.
        request.query_parameters.to_h.except("widget", "_").sort.to_h
      end

      def cache_table_version(model)
        Rails.cache.fetch(["api-dashboard/table-version", model.table_name], expires_in: 1.minute) do
          version = model.pick(Arel.sql("COUNT(*)"), Arel.sql("COALESCE(MAX(id), 0)"), Arel.sql("COALESCE(EXTRACT(EPOCH FROM MAX(updated_at))::bigint, 0)"))
          "#{model.table_name}:#{version.join(":")}"
        end
      rescue StandardError
        "#{model.name}:unknown"
      end

      def cache_module_records_version(module_slugs)
        slugs = Array(module_slugs).map(&:to_s).sort
        Rails.cache.fetch(["api-dashboard/module-record-version", slugs], expires_in: 1.minute) do
          scope = ModuleRecord.where(module_slug: slugs)
          version = scope.pick(Arel.sql("COUNT(*)"), Arel.sql("COALESCE(MAX(id), 0)"), Arel.sql("COALESCE(EXTRACT(EPOCH FROM MAX(updated_at))::bigint, 0)"))
          "module_records:#{version.join(":")}"
        end
      rescue StandardError
        "module_records:unknown"
      end

      # Uses the same private calculation methods as ModulesController#dashboard.
      # This keeps the Android JSON totals identical without changing any web action/view.
      def exact_admin_dashboard_data
        return @exact_admin_dashboard_data if defined?(@exact_admin_dashboard_data) && @exact_admin_dashboard_data

        web = ModulesController.new
        web.request = request
        web.instance_variable_set(:@current_app_user, current_api_user_payload)

        all_vrps = web.send(:dashboard_vrps).to_a
        all_targets = web.send(:dashboard_target_mappings).to_a
        preload_dashboard_associations!(all_targets)
        vrps = all_vrps.dup
        targets = all_targets.dup

        search_query = filter_param(:search)
        if search_query.present?
          query = search_query.to_s.downcase.strip
          vrps.select! do |vrp|
            [vrp.name, vrp.mobile_no, vrp.role, vrp.fcoc, vrp.cluster_incharge].any? do |value|
              value.to_s.downcase.include?(query)
            end
          end
          targets.select! do |target|
            [target.vrp&.name, target.month_name, target.village_name, target.main_activity_name, target.activity_name].any? do |value|
              value.to_s.downcase.include?(query)
            end
          end
        end

        options = {}
        options[:main_activities] = targets.map(&:main_activity_name).compact_blank.uniq.sort
        options[:activities] = options[:main_activities]
        selected_main_activity = params.key?(:main_activity) ? filter_param(:main_activity) : default_farmer_activity_filter(web, options[:main_activities])
        selected_sub_activity = filter_param(:sub_activity)
        legacy_activity = filter_param(:activity)
        if selected_main_activity.present?
          normalized_main = web.send(:normalize_dashboard_text, selected_main_activity)
          main_matches = targets.select { |target| web.send(:normalize_dashboard_text, target.main_activity_name) == normalized_main }
          targets = main_matches
        elsif legacy_activity.present?
          targets.select! { |target| target.main_activity_name == legacy_activity || target.activity_name == legacy_activity }
        end
        options[:sub_activities] = web.send(:dashboard_filter_sub_activity_options, targets)
        unless options[:sub_activities].any? { |value| same_text?(value, selected_sub_activity) }
          selected_sub_activity = nil
          params.delete(:sub_activity)
          web.instance_variable_set(:@dashboard_filter_param_cache, {})
        end
        if selected_sub_activity.present?
          normalized_sub = web.send(:normalize_dashboard_text, selected_sub_activity)
          targets.select! { |target| web.send(:normalize_dashboard_text, target.activity_name) == normalized_sub }
        end
        if selected_main_activity.present? || selected_sub_activity.present? || legacy_activity.present?
          vrp_ids = id_lookup(targets, :vrp_id)
          vrps.select! { |vrp| vrp_ids.key?(vrp.id.to_s) }
        end

        selected_fcoc = filter_param(:fcoc, :fco)
        options[:fcos] = vrps.map(&:fcoc).compact_blank.uniq.sort
        if selected_fcoc.present?
          vrps.select! { |vrp| vrp.fcoc == selected_fcoc }
          vrp_ids = id_lookup(vrps)
          targets.select! { |target| target.vrp_id.present? && vrp_ids.key?(target.vrp_id.to_s) }
        end

        options[:cluster_incharges] = vrps.map(&:cluster_incharge).compact_blank.uniq.sort
        selected_cluster_incharge = filter_param(:cluster_incharge)
        if selected_cluster_incharge.present?
          vrps.select! { |vrp| web.send(:cluster_label_matches?, selected_cluster_incharge, vrp.cluster_incharge) }
          vrp_ids = id_lookup(vrps)
          targets.select! { |target| target.vrp_id.present? && vrp_ids.key?(target.vrp_id.to_s) }
        end

        options[:ics] = targets.map { |target| target.ics_name.presence || target.ics_id }.compact_blank.uniq.sort
        selected_ics = filter_param(:ics, :ics_name)
        if selected_ics.present?
          targets.select! { |target| same_text?(target.ics_name.presence || target.ics_id, selected_ics) }
          vrp_ids = id_lookup(targets, :vrp_id)
          vrps.select! { |vrp| vrp_ids.key?(vrp.id.to_s) }
        end

        options[:months] = (targets.map(&:month_name) + web.send(:month_master_month_options)).compact_blank.uniq
          .sort_by { |month| web.send(:dashboard_month_index, month) || 0 }
        selected_month = params.key?(:month) ? filter_param(:month) : Date.current.prev_month.strftime("%B")
        if selected_month.present?
          targets.select! { |target| same_text?(target.month_name, selected_month) }
          vrp_ids = id_lookup(targets, :vrp_id)
          vrps.select! { |vrp| vrp_ids.key?(vrp.id.to_s) }
        end

        selected_post = filter_param(:post, :post_wise_name)
        options[:posts] = vrps.map(&:role).compact_blank.uniq.sort
        if selected_post.present?
          vrps.select! { |vrp| vrp.role == selected_post }
          vrp_ids = id_lookup(vrps)
          targets.select! { |target| target.vrp_id.present? && vrp_ids.key?(target.vrp_id.to_s) }
        end

        options[:jeevika_jankars] = vrps.map { |vrp| { id: vrp.id, name: vrp.name, user_name: vrp.user_name } }
          .uniq { |row| row[:id] }.sort_by { |row| row[:name].to_s.downcase }
        selected_vrp_filter = filter_param(:vrp_id)
        if selected_vrp_filter.present?
          selected_vrp_id = selected_vrp_filter.to_i
          vrps.select! { |vrp| vrp.id == selected_vrp_id }
          targets.select! { |target| target.vrp_id == selected_vrp_id }
        end

        # Web summary SQL reads the resolved month from controller state, not params.
        # Without this, mobile activity cards count mappings across every month.
        web.instance_variable_set(:@dashboard_month_filter_value, selected_month)
        web.instance_variable_set(:@dashboard_main_activity_filter_value, selected_main_activity)
        web.instance_variable_set(:@dashboard_fcoc_filter_value, selected_fcoc)
        web.instance_variable_set(:@filtered_vrps, vrps)
        web.instance_variable_set(:@filtered_targets, targets)
        bills = exact_dashboard_bills(web, vrps)
        web.instance_variable_set(:@filtered_bills, bills)

        months = web.send(:dashboard_month_options_for_targets, targets)
        default_month = web.send(:default_vrp_dashboard_month, months)
        participation_value = filter_param(:participation_month, :training_month) || default_month
        participation_month = participation_value == "all" ? nil : participation_value
        participation_fcoc = filter_param(:participation_fcoc, :training_fcoc)
        participation_records = web.send(:dashboard_training_participation_records, month_name: participation_month, fcoc_name: participation_fcoc)
        population = web.send(:training_participation_population_rows,
          month_name: participation_month, fcoc_name: participation_fcoc, records: participation_records)
        participation_counts = web.send(:training_participation_status_counts_from_rows, population)

        weekly_value = filter_param(:weekly_target_month) || default_month
        weekly_month = weekly_value == "all" ? nil : weekly_value
        weekly_fcoc = filter_param(:weekly_target_fcoc)
        weekly_targets = web.send(:dashboard_targets_for_month, targets, weekly_month)
        if weekly_fcoc.present?
          normalized_fcoc = web.send(:normalize_dashboard_text, weekly_fcoc)
          weekly_targets.select! { |target| web.send(:normalize_dashboard_text, target.vrp&.fcoc) == normalized_fcoc }
        end
        weekly_rows = web.send(:weekly_activity_target_farmer_status_rows,
          weekly_targets,
          month_name: weekly_month,
          fcoc_name: weekly_fcoc,
          week_number: dashboard_list_week_number)
        weekly_status_counts = web.send(:weekly_activity_target_status_counts_for_rows, weekly_rows)
        weekly_summary_totals = web.send(:dashboard_weekly_activity_summary_totals,
          weekly_targets,
          participation_counts,
          week_number: dashboard_list_week_number)
        weekly_counts = {
          target_assigned: weekly_status_counts[:total].to_i,
          completed: weekly_status_counts[:green].to_i,
          partial: weekly_status_counts[:yellow].to_i,
          pending: weekly_status_counts[:red].to_i,
          activity_target_mapping: number(weekly_summary_totals[:target]),
          activity_wise_achievement: number(weekly_summary_totals[:completed]),
          activity_wise_pending_achievement: number(weekly_summary_totals[:pending]),
          target_records: weekly_rows.size
        }

        ics_month_value = filter_param(:ics_report_month) || participation_value
        ics_month = ics_month_value == "all" ? nil : ics_month_value
        ics_targets = web.send(:training_participation_targets_for_dashboard, month_name: ics_month, fcoc_name: participation_fcoc)
        ics_records = web.send(:dashboard_training_participation_records, month_name: ics_month, fcoc_name: participation_fcoc)
        ics_options = web.send(:ics_farmer_report_options, ics_records, ics_targets)
        selected_ics = filter_param(:ics_report_ics)
        ics_rows = selected_ics ? web.send(:ics_farmer_report_rows, ics_targets, ics_records, selected_ics: selected_ics) : []
        target_progress = admin_dashboard_progress(web, targets, vrps)

        card_data = exact_admin_card_data(web, vrps, targets, all_targets, bills)
        web_summary_cards = web.send(:dashboard_summary_cards, targets)
        web_demo_cards = web.send(:demonstration_method_cards)
        web_training_cards = web.send(:training_participation_dashboard_status_cards,
          participation_counts, month_name: participation_month, fcoc_name: participation_fcoc,
          week_number: dashboard_list_week_number)
        web_group_items = web.send(:dashboard_cards).flat_map { |card| Array(card[:items]) }
        mobile_widget_values = (web_summary_cards + web_demo_cards + web_training_cards + web_group_items)
          .each_with_object({}) { |card, values| values[card[:title].to_s] = card[:value] }
        mobile_widget_values["OPG Training Achievement"] = web.send(:dashboard_opg_achievement_count)
        @admin_dashboard_api_context = {
          web: web,
          vrps: vrps,
          targets: targets,
          all_targets: all_targets,
          bills: bills,
          participation_records: participation_records,
          participation_population: population,
          participation_month: participation_month,
          participation_month_value: participation_value,
          weekly_targets: weekly_targets,
          weekly_rows: weekly_rows,
          weekly_summary_totals: weekly_summary_totals,
          ics_rows: ics_rows
        }
        @exact_admin_dashboard_data = {
          filters: admin_filter_payload.merge(main_activity: selected_main_activity, sub_activity: selected_sub_activity, fcoc: selected_fcoc, month: selected_month, post: selected_post),
          filter_options: options,
          cc_jj_work_status: CcJjWorkStatusReport.new(calculator: web).summary,
          demonstration_method: DemonstrationMethodReport.new(targets: targets, month: params.key?(:month) ? filter_param(:month) : Date.current.prev_month.strftime("%B")).summary,
          sections: card_data,
          cards: card_data.values_at(:registration, :target_assignment, :billing).reduce({}, &:merge),
          mobile_widget_values: mobile_widget_values,
          list_endpoints: admin_dashboard_list_catalog.to_h do |type, title|
            [type, { title: title, endpoint: "#{request.base_url}/api/v1/admin-dashboard/lists/#{type}" }]
          end,
          farmer_training_participation_status: {
            selected_month: participation_value,
            selected_fcoc: participation_fcoc,
            month_options: ["all"] + months,
            fco_options: options[:fcos],
            total_unique_farmers_distinct: web.send(:training_afl_farmer_rows_for_participation, month_name: participation_month, fcoc_name: participation_fcoc).size,
            total_training_farmer: web.send(:training_total_farmer_count_from_records, participation_records),
            training_unique_farmers: web.send(:training_unique_farmer_count_from_records, participation_records),
            green: participation_counts[:green].to_i,
            yellow: participation_counts[:yellow].to_i,
            red: participation_counts[:red].to_i,
            pending: participation_counts[:pending].to_i
          },
          target_dashboard: target_dashboard_payload(targets),
          weekly_activity_target_status: weekly_counts.merge(
            selected_month: weekly_value,
            selected_fcoc: weekly_fcoc,
            month_options: ["all"] + months,
            fco_options: options[:fcos]
          ),
          ics_wise_farmer_report: {
            selected_month: ics_month_value,
            selected_ics: selected_ics,
            month_options: ["all"] + months,
            ics_options: ics_options,
            summary: web.send(:ics_farmer_report_summary, ics_rows),
            rows: ics_rows,
            count: ics_rows.size
          },
          monthly_target_summary: monthly_progress_summary(target_progress),
          recent_target_progress: target_progress.first(100)
        }
      end

      def admin_dashboard_progress(web, targets, vrps)
        vrps_by_id = Array(vrps).index_by { |vrp| vrp.id.to_s }
        Array(targets).group_by { |target| target.vrp_id.to_s }.flat_map do |vrp_id, vrp_targets|
          vrp = vrps_by_id[vrp_id]
          next [] unless vrp

          bills = web.send(:vrp_dashboard_bills, vrp)
          web.send(:vrp_dashboard_target_progress_rows, vrp_targets, bills).map do |row|
            assigned = row[:target].to_f
            achieved = [row[:completed].to_f, assigned].min
            {
              target_mapping_id: row[:target_mapping_id],
              target_mapping_ids: row[:target_mapping_ids].presence || [row[:target_mapping_id]],
              jeevika_jankar_id: vrp.id,
              jeevika_jankar_name: vrp.name,
              month: row[:month],
              fco: row[:fco],
              ics: row[:ics],
              village: row[:village],
              main_activity: row[:main_activity],
              sub_activity: row[:activity],
              completion_date: parse_dashboard_date(row[:completion_date]),
              assigned: number(assigned),
              achieved: number(achieved),
              pending: number([assigned - achieved, 0].max),
              progress_percent: assigned.positive? ? ((achieved / assigned) * 100).round(2) : 0
            }
          end
        end
      end

      def monthly_progress_summary(progress)
        Array(progress).group_by { |row| row[:month].presence || "Not Set" }.map do |month, rows|
          {
            month: month,
            target_records: rows.size,
            target_quantity: number(rows.sum { |row| row[:assigned].to_f }),
            achieved: number(rows.sum { |row| row[:achieved].to_f }),
            pending: number(rows.sum { |row| row[:pending].to_f })
          }
        end
      end

      def exact_dashboard_bills(web, _vrps)
        web.send(:dashboard_billing_records)
      end

      def exact_admin_card_data(web, vrps, targets, all_targets, bills)
        assigned_vrp_ids = all_targets.filter_map { |target| target.vrp_id.to_s.presence }.uniq
        activity_vrp_ids = all_targets.filter_map do |target|
          target.vrp_id.to_s.presence if target.main_activity_name.present? || target.activity_name.present?
        end.uniq
        activities = targets.map do |target|
          [web.send(:normalize_dashboard_text, target.main_activity_name), web.send(:normalize_dashboard_text, target.activity_name)]
        end.reject { |main, sub| main.blank? && sub.blank? }.uniq.size

        {
          registration: {
            total_registered: vrps.size,
            final_approved: web.send(:dashboard_approved_vrps, vrps).size,
            pending_approval: web.send(:dashboard_pending_approval_vrps, vrps).size
          },
          target_assignment: {
            target_records: web.send(:dashboard_target_record_count, targets),
            without_target: vrps.count { |vrp| !assigned_vrp_ids.include?(vrp.id.to_s) },
            activities_assigned: activities,
            without_activity: vrps.count { |vrp| !activity_vrp_ids.include?(vrp.id.to_s) }
          },
          billing: {
            level_2_users: web.send(:user_hierarchy_dashboard_summary)[:level_2_total],
            bill_approved: bills.count { |bill| web.send(:dashboard_bill_approved?, bill) },
            bill_pending: bills.count { |bill| web.send(:dashboard_bill_pending?, bill) }
          },
          fco_wise_jeevika_jankar: %w[Sausar Turekela].map do |fco_name|
            matching = vrps.select do |vrp|
              web.send(:normalize_dashboard_text, vrp.fcoc).include?(web.send(:normalize_dashboard_text, fco_name))
            end
            {
              fco: fco_name,
              male: matching.count { |vrp| web.send(:normalize_dashboard_text, vrp.gender) == "male" },
              female: matching.count { |vrp| web.send(:normalize_dashboard_text, vrp.gender) == "female" }
            }
          end
        }
      end

      def admin_dashboard_list_catalog
        {
          "cc_jj_work_status" => "CC and JJ Work Status View List",
          "demonstration_method" => "Demonstration Method View List",
          "total_registered" => "Total Registered Jeevika Jankar List",
          "final_approved" => "Final Approved Jeevika Jankar List",
          "pending_approval" => "Pending Approval Jeevika Jankar List",
          "target_records" => "Jeevika Jankar Target Records List",
          "total_ics_count" => "Total ICS List",
          "total_mapped_villages" => "Total Mapped Villages List",
          "targeted_farmers" => "Targeted Farmers List",
          "total_mapped_main_activities" => "Total Mapped Main Activities List",
          "total_mapped_sub_activities" => "Total Mapped Sub-Activities List",
          "farmer_wise_target_mapping" => "Farmer-wise Target Mapping List",
          "farmer_wise_achievement" => "Farmer-wise Achievement List",
          "farmer_wise_pending_achievement" => "Farmer-wise Pending Achievement List",
          "activity_wise_target_mapping" => "Activity-wise Target Mapping List",
          "activity_wise_achievement" => "Activity-wise Achievement List",
          "activity_wise_pending_achievement" => "Activity-wise Pending Achievement List",
          "without_target" => "Jeevika Jankar Without Target List",
          "activities_assigned" => "Jeevika Jankar Activities Assigned List",
          "without_activity" => "Jeevika Jankar Without Activity List",
          "level_2_users" => "Level 2 Users List",
          "bill_approved" => "Approved Jeevika Jankar Bills List",
          "bill_pending" => "Pending Jeevika Jankar Bills List",
          "fco_sausar" => "Sausar FCO-wise Jeevika Jankar List",
          "fco_turekela" => "Turekela FCO-wise Jeevika Jankar List",
          "training_unique_farmers" => "Total Unique Farmers List",
          "training_total" => "Total Training Farmer List",
          "training_green" => "Green Training Farmers List",
          "training_yellow" => "Yellow Training Farmers List",
          "training_red" => "Red Training Farmers List",
          "training_pending" => "Pending Training Farmers List",
          "weekly_targets" => "Weekly Target List",
          "weekly_target_assigned" => "Weekly Target Assigned List",
          "weekly_completed" => "Weekly Completed List",
          "weekly_partial" => "Weekly Partial List",
          "weekly_pending" => "Weekly Pending List",
          "ics_farmers" => "ICS-wise Farmer List"
        }
      end

      def lightweight_admin_dashboard_list_type?(list_type)
        %w[
          target_records
          total_mapped_villages
          targeted_farmers
          total_mapped_main_activities
          total_mapped_sub_activities
          farmer_wise_achievement
          farmer_wise_pending_achievement
          activities_assigned
        ].include?(list_type.to_s)
      end

      def prepare_lightweight_admin_dashboard_context
        return @admin_dashboard_api_context if @admin_dashboard_api_context

        web = ModulesController.new
        web.request = request
        web.instance_variable_set(:@current_app_user, current_api_user_payload)

        all_vrps = web.send(:dashboard_vrps).to_a
        all_targets = web.send(:dashboard_target_mappings).to_a
        preload_dashboard_associations!(all_targets)
        vrps = all_vrps.dup
        targets = all_targets.dup

        search_query = filter_param(:search)
        if search_query.present?
          query = search_query.to_s.downcase.strip
          vrps.select! do |vrp|
            [vrp.name, vrp.mobile_no, vrp.role, vrp.fcoc, vrp.cluster_incharge].any? { |value| value.to_s.downcase.include?(query) }
          end
          targets.select! do |target|
            [target.vrp&.name, target.month_name, target.village_name, target.main_activity_name, target.activity_name].any? { |value| value.to_s.downcase.include?(query) }
          end
        end

        selected_main_activity = params.key?(:main_activity) ? filter_param(:main_activity) : default_farmer_activity_filter(web, targets.map(&:main_activity_name).compact_blank.uniq.sort)
        selected_sub_activity = filter_param(:sub_activity)
        legacy_activity = filter_param(:activity)
        if selected_main_activity.present?
          normalized_main = web.send(:normalize_dashboard_text, selected_main_activity)
          main_matches = targets.select { |target| web.send(:normalize_dashboard_text, target.main_activity_name) == normalized_main }
          targets = main_matches
        elsif legacy_activity.present?
          targets.select! { |target| target.main_activity_name == legacy_activity || target.activity_name == legacy_activity }
        end

        if selected_sub_activity.present?
          normalized_sub = web.send(:normalize_dashboard_text, selected_sub_activity)
          targets.select! { |target| web.send(:normalize_dashboard_text, target.activity_name) == normalized_sub }
        end

        selected_fcoc = filter_param(:fcoc, :fco)
        if selected_fcoc.present?
          normalized_fcoc = web.send(:normalize_dashboard_text, selected_fcoc)
          vrps.select! { |vrp| web.send(:normalize_dashboard_text, vrp.fcoc) == normalized_fcoc }
          vrp_ids = id_lookup(vrps)
          targets.select! { |target| target.vrp_id.present? && vrp_ids.key?(target.vrp_id.to_s) }
        end

        selected_cluster = filter_param(:cluster_incharge)
        if selected_cluster.present?
          vrps.select! { |vrp| web.send(:cluster_label_matches?, selected_cluster, vrp.cluster_incharge) }
          vrp_ids = id_lookup(vrps)
          targets.select! { |target| vrp_ids.key?(target.vrp_id.to_s) }
        end

        selected_ics = filter_param(:ics, :ics_name)
        targets.select! { |target| same_text?(target.ics_name.presence || target.ics_id, selected_ics) } if selected_ics.present?

        selected_month = params.key?(:month) ? filter_param(:month) : Date.current.prev_month.strftime("%B")
        targets.select! { |target| same_text?(target.month_name, selected_month) } if selected_month.present?

        selected_post = filter_param(:post, :post_wise_name)
        if selected_post.present?
          vrps.select! { |vrp| vrp.role == selected_post }
          vrp_ids = id_lookup(vrps)
          targets.select! { |target| target.vrp_id.present? && vrp_ids.key?(target.vrp_id.to_s) }
        end

        selected_vrp_filter = filter_param(:vrp_id)
        if selected_vrp_filter.present?
          selected_vrp_id = selected_vrp_filter.to_i
          vrps.select! { |vrp| vrp.id == selected_vrp_id }
          targets.select! { |target| target.vrp_id == selected_vrp_id }
        end

        months = web.send(:dashboard_month_options_for_targets, targets)
        default_month = web.send(:default_vrp_dashboard_month, months)
        participation_value = filter_param(:participation_month, :training_month) || default_month
        participation_month = participation_value == "all" ? nil : participation_value

        @admin_dashboard_api_context = {
          web: web,
          vrps: vrps,
          targets: targets,
          all_targets: all_targets,
          bills: [],
          participation_month: participation_month,
          participation_month_value: participation_value
        }
      end

      def admin_dashboard_list_payload(list_type)
        context = @admin_dashboard_api_context
        return unless context

        web = context[:web]
        vrps = context[:vrps]
        targets = context[:targets]
        all_targets = context[:all_targets]
        bills = context[:bills]
        assigned_ids = all_targets.filter_map { |target| target.vrp_id.to_s.presence }.uniq
        activity_ids = all_targets.filter_map do |target|
          target.vrp_id.to_s.presence if target.main_activity_name.present? || target.activity_name.present?
        end.uniq

        records = case list_type
        when "cc_jj_work_status"
          CcJjWorkStatusReport.new(calculator: web).rows
        when "demonstration_method"
          DemonstrationMethodReport.new(targets: targets, month: params.key?(:month) ? filter_param(:month) : Date.current.prev_month.strftime("%B")).rows
        when "total_registered"
          vrps.map { |vrp| admin_vrp_list_row(vrp, assigned_ids, activity_ids) }
        when "final_approved"
          web.send(:dashboard_approved_vrps, vrps).map { |vrp| admin_vrp_list_row(vrp, assigned_ids, activity_ids) }
        when "pending_approval"
          web.send(:dashboard_pending_approval_vrps, vrps).map { |vrp| admin_vrp_list_row(vrp, assigned_ids, activity_ids) }
        when "target_records"
          grouped_admin_targets(targets)
        when "total_ics_count"
          targets.group_by { |target| target.ics_name.presence || target.ics_id }.reject { |name, _| name.blank? }.map do |name, rows|
            { ics: name, target_records: rows.size, jeevika_jankar_count: rows.filter_map(&:vrp_id).uniq.size, villages: rows.filter_map(&:village_name).uniq.size }
          end
        when "total_mapped_villages"
          grouped_admin_villages(targets)
        when "targeted_farmers"
          web.send(:training_afl_farmer_rows_for_participation,
            month_name: dashboard_list_participation_month, fcoc_name: filter_param(:participation_fcoc, :training_fcoc))
        when "total_mapped_main_activities"
          grouped_admin_activities(targets, :main_activity_name, "Main Activity")
        when "total_mapped_sub_activities"
          grouped_admin_activities(targets, :activity_name, "Sub Activity")
        when "farmer_wise_target_mapping"
          dashboard_participation_target_map_rows(web, context)
        when "farmer_wise_achievement"
          dashboard_participation_target_map_rows(web, context).select { |row| row[:completed_activity_count].to_i.positive? }
        when "farmer_wise_pending_achievement"
          dashboard_participation_target_map_rows(web, context).select { |row| row[:completed_activity_count].to_i < row[:assigned_activity_count].to_i }
        when "without_target"
          vrps.reject { |vrp| assigned_ids.include?(vrp.id.to_s) }.map { |vrp| admin_vrp_list_row(vrp, assigned_ids, activity_ids) }
        when "activities_assigned"
          targets.select { |target| target.main_activity_name.present? || target.activity_name.present? }.map { |target| admin_target_list_row(target) }
        when "without_activity"
          vrps.reject { |vrp| activity_ids.include?(vrp.id.to_s) }.map { |vrp| admin_vrp_list_row(vrp, assigned_ids, activity_ids) }
        when "level_2_users"
          web.send(:user_hierarchy_dashboard_summary)[:rows].map.with_index do |row, index|
            { id: index + 1, name: row[0], reports_to: row[1], level: row[2], assignment_status: "Mapped" }
          end
        when "bill_approved"
          bills.select { |bill| web.send(:dashboard_bill_approved?, bill) }.map { |bill| admin_bill_list_row(bill, web) }
        when "bill_pending"
          bills.select { |bill| web.send(:dashboard_bill_pending?, bill) }.map { |bill| admin_bill_list_row(bill, web) }
        when "fco_sausar", "fco_turekela"
          fco_name = list_type.delete_prefix("fco_")
          vrps.select { |vrp| web.send(:normalize_dashboard_text, vrp.fcoc).include?(fco_name) }
            .map { |vrp| admin_vrp_list_row(vrp, assigned_ids, activity_ids) }
        when "training_unique_farmers"
          web.send(:training_afl_farmer_rows_for_participation,
            month_name: dashboard_list_participation_month, fcoc_name: filter_param(:participation_fcoc, :training_fcoc))
        when "training_total"
          web.send(:training_participation_farmer_rows_from_records, context[:participation_records])
        when "training_green", "training_yellow", "training_red", "training_pending"
          status = list_type.delete_prefix("training_")
          context[:participation_population].select { |row| row[:status] == status }
        when "weekly_targets", "weekly_target_assigned", "activity_wise_target_mapping"
          context[:weekly_rows]
        when "weekly_completed", "activity_wise_achievement"
          context[:weekly_rows].select { |row| row[:status_class].to_s == "green" }
        when "weekly_partial"
          context[:weekly_rows].select { |row| row[:status_class].to_s == "yellow" }
        when "weekly_pending", "activity_wise_pending_achievement"
          context[:weekly_rows].select { |row| row[:status_class].to_s == "red" }
        when "ics_farmers"
          context[:ics_rows]
        end
        return unless records

        { title: admin_dashboard_list_catalog.fetch(list_type), records: records, headers: ({ "demonstration_method" => DemonstrationMethodReport::HEADERS, "cc_jj_work_status" => CcJjWorkStatusReport::HEADERS }[list_type]) }
      end

      def send_dashboard_list_export(payload)
        records = Array(payload[:records])
        headers = payload[:headers] || records.flat_map { |record| record.respond_to?(:keys) ? record.keys : [] }.map(&:to_s).uniq
        rows = records.map do |record|
          headers.map { |header| dashboard_export_value(record[header] || record[header.to_sym]) }
        end
        file = XlsxExporter.generate(headers: headers, rows: rows, sheet_name: payload[:title])
        send_data file,
          filename: "#{params[:list_type].to_s.parameterize.presence || 'dashboard-list'}-#{Date.current}.xlsx",
          type: XlsxExporter::MIME_TYPE,
          disposition: "attachment"
      end

      def dashboard_export_value(value)
        value.is_a?(Array) || value.is_a?(Hash) ? value.to_json : value
      end

      def admin_vrp_list_row(vrp, assigned_ids, activity_ids)
        target_assigned = assigned_ids.include?(vrp.id.to_s)
        activity_assigned = activity_ids.include?(vrp.id.to_s)
        {
          id: vrp.id,
          name: vrp.name,
          user_name: vrp.user_name,
          mobile_no: vrp.mobile_no,
          gender: vrp.gender,
          role: vrp.role,
          fco: vrp.fcoc,
          cluster_incharge: vrp.cluster_incharge,
          approval_status: vrp.status,
          target_assigned: target_assigned,
          target_assignment_status: target_assigned ? "Assigned" : "Not Assigned",
          activity_assigned: activity_assigned,
          activity_assignment_status: activity_assigned ? "Assigned" : "Not Assigned"
        }
      end

      def admin_target_list_row(target)
        {
          id: target.id,
          jeevika_jankar_id: target.vrp_id,
          name: target.vrp&.name,
          assignment_status: "Assigned",
          month: target.month_name,
          fco: target.vrp&.fcoc.presence || target.fco_name.presence || target.fco_id,
          ics: target.ics_name.presence || target.ics_id,
          village: target.village_name.presence || target.village_id,
          main_activity: target.main_activity_name,
          sub_activity: target.activity_name,
          target_quantity: number(target.target_quantity.to_f)
        }
      end

      def grouped_admin_targets(targets)
        Array(targets).group_by do |target|
          [
            target.vrp_id,
            target.fco_name.presence || target.fco_id,
            target.ics_name.presence || target.ics_id,
            target.village_name.presence || target.village_id,
            target.month_name,
            target.completion_date,
            target.opg_training_target.to_s,
            target.week_wise_opg_target.to_s,
            target.input_demo_inm_target.to_s,
            target.input_demo_pm_target.to_s,
            target.ffs_target.to_s,
            Array(target.afl_ids).map(&:to_s).reject(&:blank?).sort
          ]
        end.values.map do |rows|
          first = rows.first
          admin_target_list_row(first).merge(
            target_mapping_ids: rows.map(&:id),
            main_activities: rows.map(&:main_activity_name).compact_blank.uniq,
            sub_activities: rows.map(&:activity_name).compact_blank.uniq
          )
        end
      end

      def grouped_admin_villages(targets)
        Array(targets).group_by { |target| [target.village_id.to_s, target.village_name.to_s.downcase.strip] }
          .values.map.with_index(1) do |rows, index|
            first = rows.first
            {
              id: first.village_id.presence || index,
              name: first.village_name.presence || first.village_id,
              assignment_status: "Mapped",
              target_records: rows.size,
              target_quantity: number(rows.sum { |row| row.target_quantity.to_f }),
              fcos: rows.filter_map { |row| row.vrp&.fcoc.presence || row.fco_name.presence || row.fco_id }.uniq,
              ics_names: rows.filter_map { |row| row.ics_name.presence || row.ics_id }.uniq,
              months: rows.filter_map(&:month_name).uniq
            }
          end
      end

      def grouped_admin_activities(targets, attribute, label)
        Array(targets).group_by { |target| target.public_send(attribute).to_s.downcase.strip }
          .reject { |name, _rows| name.blank? }
          .values.map.with_index(1) do |rows, index|
            first = rows.first
            name = first.public_send(attribute)
            {
              id: index,
              name: name,
              activity_type: label,
              assignment_status: "Mapped",
              target_records: rows.size,
              target_quantity: number(rows.sum { |row| row.target_quantity.to_f }),
              jeevika_jankar_count: rows.filter_map(&:vrp_id).uniq.size,
              farmer_count: rows.flat_map { |row| mapped_farmer_ids(row) }.uniq.size,
              months: rows.filter_map(&:month_name).uniq
            }
          end
      end

      def dashboard_participation_target_map_rows(web, context)
        return context[:participation_target_map_rows] if context[:participation_target_map_rows]

        targets = web.send(:training_participation_targets_for_dashboard,
          month_name: dashboard_list_participation_month,
          fcoc_name: filter_param(:participation_fcoc, :training_fcoc))
        context[:participation_target_map_rows] = web.send(:training_participation_target_map_rows, targets, month_name: dashboard_list_participation_month)
      end

      def admin_bill_list_row(bill, web)
        vrp = web.send(:jeevika_bill_vrp, bill)
        status = web.send(:jeevika_bill_status_label, bill)
        {
          id: bill.id,
          jeevika_jankar_id: bill.data["select_vrp"],
          name: bill.data["jeevika_jankar_name"].presence || bill.data["vrp_name"].presence || vrp&.name,
          status: status,
          assignment_status: status,
          bill_month: bill.data["bill_month"],
          financial_year: bill.data["financial_year"],
          total_payment: number(bill.data["total_payment"].to_f)
        }
      end

      def dashboard_list_participation_month
        value = filter_param(:participation_month, :training_month) || @admin_dashboard_api_context&.dig(:participation_month)
        value == "all" ? nil : value
      end

      def normalize_participation_list_status(value)
        status = value.to_s.downcase.presence || "unique"
        aliases = {
          "total_unique" => "unique",
          "training" => "total",
          "training_total" => "total",
          "training_unique" => "training_unique"
        }
        status = aliases.fetch(status, status)
        %w[unique total training_unique green yellow red pending].include?(status) ? status : "unique"
      end

      def participation_list_title(status)
        {
          "unique" => "Total Unique Farmers Farmer List",
          "total" => "Total Training Farmer List",
          "training_unique" => "Training Unique Farmers List",
          "green" => "Green Farmer List",
          "yellow" => "Yellow Farmer List",
          "red" => "Red Farmer List",
          "pending" => "Pending Farmer List"
        }.fetch(status)
      end

      def dashboard_list_week_number
        week = params[:weekly_target_week].to_i if params[:weekly_target_week].present?
        (1..4).include?(week) ? week : nil
      end

      def admin_filter_options(vrps, targets)
        {
          activities: targets.filter_map { |target| target.main_activity_name.to_s.strip.presence }.uniq.sort,
          fcos: vrps.filter_map { |vrp| vrp.fcoc.to_s.strip.presence }.uniq.sort,
          cluster_incharges: vrps.filter_map { |vrp| vrp.cluster_incharge.to_s.strip.presence }.uniq.sort,
          months: (web.send(:month_master_month_options) + targets.filter_map { |target| target.month_name.to_s.strip.presence })
            .uniq { |month| web.send(:normalize_dashboard_text, month) }
            .sort_by { |month| [web.send(:dashboard_month_index, month), month] },
          post_wise_names: vrps.filter_map { |vrp| vrp.role.to_s.strip.presence }.uniq.sort,
          jeevika_jankars: vrps.map { |vrp| { id: vrp.id, name: vrp.name, user_name: vrp.user_name } }
        }
      end

      def filter_admin_vrps(vrps)
        vrps.select do |vrp|
          filter_value_matches?(vrp.fcoc, filter_param(:fco, :fcoc)) &&
            filter_value_matches?(vrp.cluster_incharge, filter_param(:cluster_incharge)) &&
            filter_value_matches?(vrp.role, filter_param(:post_wise_name, :post)) &&
            (filter_param(:vrp_id).blank? || vrp.id.to_s == filter_param(:vrp_id).to_s)
        end
      end

      def filter_admin_targets(targets)
        targets.select do |target|
          filter_value_matches?(target.month_name, filter_param(:month)) &&
            filter_value_matches?(target.main_activity_name, filter_param(:activity, :main_activity)) &&
            filter_value_matches?(target.activity_name, filter_param(:sub_activity))
        end
      end

      def admin_vrp_filters_present?
        %i[fco cluster_incharge post_wise_name vrp_id].any? { |key| filter_param(key).present? }
      end

      def admin_filter_payload
        {
          activity: filter_param(:activity, :main_activity),
          fco: filter_param(:fco, :fcoc),
          cluster_incharge: filter_param(:cluster_incharge),
          month: filter_param(:month),
          post_wise_name: filter_param(:post_wise_name, :post),
          vrp_id: filter_param(:vrp_id),
          sub_activity: filter_param(:sub_activity)
        }.compact
      end

      def default_farmer_activity_filter(web, activity_options)
        Array(activity_options).find do |activity|
          %w[Farmer\ Activity Farmers'\ Training Farmers\ Training].any? do |label|
            web.send(:normalize_dashboard_text, activity) == web.send(:normalize_dashboard_text, label)
          end
        end
      end

      def filter_value_matches?(actual, selected)
        selected.blank? || same_text?(actual, selected)
      end

      def filter_param(*keys)
        keys.each do |key|
          value = params[key].to_s.strip
          next if all_filter_value?(value)

          return value if value.present?
        end
        nil
      end

      def all_filter_value?(value)
        normalized = value.to_s.strip.downcase
        normalized.blank? || normalized == "all" || normalized.start_with?("all ")
      end

      def preload_dashboard_associations!(targets)
        ActiveRecord::Associations::Preloader.new(records: targets, associations: :vrp).call if targets.any?
      rescue StandardError => error
        Rails.logger.debug("Admin dashboard preload skipped: #{error.class}: #{error.message}")
      end

      def id_lookup(records, attribute = :id)
        records.each_with_object({}) { |record, lookup| lookup[record.public_send(attribute).to_s] = true }
      end

      def training_participation_status(targets)
        farmer_ids = targets.flat_map { |target| mapped_farmer_ids(target) }.uniq
        attendance = Hash.new(0)
        ModuleRecord.where(module_slug: "training-form").select { |record| active_record?(record) }.each do |record|
          Array(record.data["selected_farmer_ids"]).map(&:to_s).uniq.each { |farmer_id| attendance[farmer_id] += 1 }
        end
        green = farmer_ids.count { |id| attendance[id] >= 3 }
        yellow = farmer_ids.count { |id| attendance[id].between?(1, 2) }
        untrained = farmer_ids.select { |id| attendance[id].zero? }
        closed_target = targets.any? { |target| target.completion_date.present? && target.completion_date < Date.current }
        red = closed_target ? untrained.size : 0
        pending = closed_target ? 0 : untrained.size
        { total_training_farmers: farmer_ids.size, green: green, yellow: yellow, red: red, pending: pending }
      end

      def target_dashboard_payload(targets)
        @target_achievement_records_by_id = ModuleRecord
          .where(module_slug: %w[training-form seed-distribution-target papl360-target add-farmer-form])
          .where("data::jsonb ->> 'target_mapping_id' IN (?)", targets.map { |target| target.id.to_s })
          .select { |record| active_record?(record) }
          .group_by { |record| record.data["target_mapping_id"].to_s }
        sub_activities = targets.filter_map { |target| target.activity_name.to_s.strip.presence }.uniq.sort
        {
          selected_month: filter_param(:month),
          selected_sub_activity: filter_param(:sub_activity),
          sub_activity_options: sub_activities,
          rows: targets.map { |target| progress_payload(target) }
        }
      end

      def weekly_target_status(progress)
        percentages = progress.map { |row| row[:progress_percent].to_f }
        {
          total_targets: progress.size,
          green: percentages.count { |value| value >= 100 },
          yellow: percentages.count { |value| value >= 75 && value < 100 },
          red: percentages.count { |value| value < 75 }
        }
      end

      def monthly_target_summary(targets)
        targets.group_by { |target| target.month_name.presence || "Not Set" }.map do |month, rows|
          {
            month: month,
            target_records: rows.size,
            target_quantity: number(rows.sum { |target| target.target_quantity.to_f })
          }
        end
      end

      def approved_bill?(bill)
        status = bill.data["approval_status"].presence || bill.data["status"]
        status.to_s.downcase.include?("approved") && !status.to_s.downcase.include?("pending")
      end

      def current_dashboard_vrp
        user = current_api_user_payload
        return Vrp.find_by(id: user["id"]) if user["record_type"] == "Vrp"
        selected_vrp_id = filter_param(:vrp_id)
        return Vrp.find_by(id: selected_vrp_id) if user["user_type"].to_s.casecmp("admin").zero? && selected_vrp_id.present?
      end

      def default_month(months)
        previous = Date.current.prev_month.strftime("%B")
        months.find { |month| same_text?(month, previous) } || months.last
      end

      def unique_count(targets, field)
        targets.filter_map { |target| target.public_send(field).to_s.downcase.strip.presence }.uniq.size
      end

      def progress_payload(target)
        assigned = target.target_quantity.to_f
        achieved = [target_achievement(target), assigned].min
        {
          target_mapping_id: target.id.to_s,
          month: target.month_name,
          fco: target.fco_name.presence || target.fco_id,
          ics: target.ics_name.presence || target.ics_id,
          village: target.village_name.presence || target.village_id,
          main_activity: target.main_activity_name,
          sub_activity: target.activity_name,
          completion_date: target.completion_date&.iso8601,
          assigned: number(assigned),
          achieved: number(achieved),
          pending: number([assigned - achieved, 0].max),
          progress_percent: assigned.positive? ? ((achieved / assigned) * 100).round(2) : 0
        }
      end

      # Keep the mobile dashboard totals identical to the existing VRP web dashboard.
      # The web calculation handles Main Activity Type, farmer/activity/month matching,
      # completion deadlines, approved Other targets, and the bill fallback.
      def web_parity_progress(targets, vrp)
        rows = jj_raw_progress(vrp)

        rows.map do |row|
          assigned = row[:target].to_f
          achieved = [row[:completed].to_f, assigned].min
          {
            **row.slice(:farmers, :main_activities, :sub_activities, :assigned_farmer_ids, :completed_farmer_ids,
              :week_1, :week_2, :week_3, :week_4, :week_1_achieved, :week_2_achieved, :week_3_achieved, :week_4_achieved,
              :opg_training, :general_training, :input_demo_inm, :input_demo_pm, :ffs),
            target_mapping_id: row[:target_mapping_id],
            month: row[:month],
            fco: row[:fco],
            ics: row[:ics],
            village: row[:village],
            main_activity: row[:main_activity],
            sub_activity: row[:activity],
            completion_date: parse_dashboard_date(row[:completion_date]),
            assigned: number(assigned),
            achieved: number(achieved),
            pending: number([assigned - achieved, 0].max),
            progress_percent: assigned.positive? ? ((achieved / assigned) * 100).round(2) : 0
          }
        end
      end

      def parse_dashboard_date(value)
        return if value.blank? || value == "-"

        Date.strptime(value.to_s, "%d-%m-%Y").iso8601
      rescue ArgumentError
        value
      end

      def target_achievement(target)
        @target_achievement_records_by_id ||= ModuleRecord
          .where(module_slug: %w[training-form seed-distribution-target papl360-target add-farmer-form])
          .select { |record| active_record?(record) }
          .group_by { |record| record.data["target_mapping_id"].to_s }
        records = @target_achievement_records_by_id.fetch(target.id.to_s, [])
        training_ids = records.select { |record| record.module_slug == "training-form" }
          .flat_map { |record| Array(record.data["selected_farmer_ids"]).map(&:to_s) }.reject(&:blank?).uniq
        other = records.reject { |record| record.module_slug == "training-form" }.sum do |record|
          (record.data["achievement"].presence || record.data["no_farmer"].presence || Array(record.data["selected_farmer_ids"]).size).to_f
        end
        training_ids.size + other
      end

      def mapped_farmer_ids(target)
        ids = Array(target.afl_ids).map(&:to_s).reject(&:blank?).uniq
        return ids if ids.any?

        VrpIcsMapping.where(vrp_id: target.vrp_id).select do |mapping|
          location_match?(mapping.fco_id, mapping.fco_name, target.fco_id, target.fco_name) &&
            location_match?(mapping.ics_id, mapping.ics_name, target.ics_id, target.ics_name) &&
            location_match?(mapping.village_id, mapping.village_name, target.village_id, target.village_name)
        end.flat_map { |mapping| Array(mapping.afl_ids).map(&:to_s) }.reject(&:blank?).uniq
      end

      def location_match?(left_id, left_name, right_id, right_name)
        left = [left_id, left_name].compact_blank.map { |value| value.to_s.strip.downcase }
        right = [right_id, right_name].compact_blank.map { |value| value.to_s.strip.downcase }
        (left & right).any?
      end

      def active_record?(record)
        status = record.data["status"].to_s.strip.downcase
        !%w[inactive rejected returned deleted].include?(status) && !record.data["is_deleted"].to_s.casecmp("true").zero?
      end

      def same_text?(left, right)
        left.to_s.strip.casecmp(right.to_s.strip).zero?
      end

      def number(value)
        value.to_f == value.to_i ? value.to_i : value.to_f.round(2)
      end
    end
  end
end
