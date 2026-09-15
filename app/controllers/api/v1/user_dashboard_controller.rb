module Api
  module V1
    class UserDashboardController < JeevikaJankarDashboardController
      def show
        return render_vrp_error if current_api_user.is_a?(Vrp)

        response = cached_user_dashboard_response
        render json: response, status: response[:success] ? :ok : :internal_server_error
      end

      # Scoped drill-down for CC, Agronomist, FCO and other office users.
      # It deliberately uses only the VRPs and targets already visible to this login.
      def list
        return render_vrp_error if current_api_user.is_a?(Vrp)

        payload = user_dashboard_list_payload(params[:list_type])
        return render json: { success: false, message: "Invalid dashboard list type.", available_list_types: user_dashboard_list_catalog.keys }, status: :unprocessable_entity unless payload

        render json: {
          success: true,
          message: "#{payload[:title]} fetched successfully.",
          dashboard_type: "user",
          list_type: params[:list_type],
          title: payload[:title],
          filters: applied_filters,
          count: payload[:records].size,
          records: payload[:records],
          generated_at: Time.current.iso8601
        }
      end

      def export
        return render_vrp_error if current_api_user.is_a?(Vrp)

        payload = user_dashboard_list_payload(params[:list_type])
        return render json: { success: false, message: "Invalid dashboard list type.", available_list_types: user_dashboard_list_catalog.keys }, status: :unprocessable_entity unless payload

        send_dashboard_list_export(payload)
      end

      def widget
        return render_vrp_error if current_api_user.is_a?(Vrp)

        config = user_dashboard_widget_catalog[params[:widget]]
        return render json: { success: false, message: "Invalid dashboard widget.", available_widgets: user_dashboard_widget_catalog.keys }, status: :unprocessable_entity unless config

        if report_widget?(params[:widget])
          return render json: report_widget_response(params[:widget], config, "user")
        end

        dashboard = cached_user_dashboard_response
        value = config[:path].reduce(dashboard) { |data, key| data.respond_to?(:[]) ? data[key] || data[key.to_s] : nil }
        render json: { success: true, dashboard_type: "user", widget: params[:widget], heading: config[:heading], value: value, filters: dashboard[:filters], generated_at: Time.current.iso8601 }
      end

      def filters
        return render_vrp_error if current_api_user.is_a?(Vrp)

        render json: mobile_dashboard_filters_payload("user")
      end

      private

      def cached_user_dashboard_response
        Rails.cache.fetch(user_dashboard_cache_key, expires_in: 10.minutes, race_condition_ttl: 30.seconds) do
          build_user_dashboard_response
        end
      rescue StandardError => error
        Rails.logger.warn("User dashboard cache skipped: #{error.class}: #{error.message}")
        build_user_dashboard_response
      end

      def user_dashboard_list_catalog
        admin_dashboard_list_catalog.merge(
          "farmer_wise_target_mapping" => "Farmer-wise Target Mapping List",
          "activity_wise_target_mapping" => "Activity-wise Target Mapping List",
          "activity_wise_achievement" => "Activity-wise Achievement List",
          "activity_wise_pending_achievement" => "Activity-wise Pending Achievement List"
        )
      end

      def user_dashboard_widget_catalog
        {
          "cc_jj_work_status" => { heading: "CC and JJ Work Status", path: %i[cc_jj_work_status] },
          "demonstration_method" => { heading: "Demonstration Method", path: %i[demonstration_method] },
          "total_registered" => { heading: "Total Registered Jeevika Jankar", path: %i[cards total_registered_vrp] },
          "final_approved" => { heading: "Final Approved Jeevika Jankar", path: %i[cards final_approved_vrp] },
          "pending_approval" => { heading: "Pending Approval", path: %i[cards vrp_pending_approval] },
          "target_records" => { heading: "Target Records", path: %i[cards vrp_targets_assigned] },
          "activities_assigned" => { heading: "Activities Assigned", path: %i[cards activities_assigned] },
          "bill_approved" => { heading: "Bill Approved", path: %i[cards bill_approved] },
          "bill_pending" => { heading: "Bill Pending", path: %i[cards bill_pending] },
          "total_mapped_villages" => { heading: "Total Mapped Villages", path: %i[dashboard_summary values total_mapped_villages] },
          "targeted_farmers" => { heading: "Targeted Farmers", path: %i[dashboard_summary values targeted_farmers] },
          "farmer_wise_achievement" => { heading: "Farmer-wise Achievement", path: %i[dashboard_summary values farmer_wise_achievement] },
          "farmer_wise_pending_achievement" => { heading: "Farmer-wise Pending Achievement", path: %i[dashboard_summary values farmer_wise_pending_achievement] }
        }
      end

      def user_dashboard_list_payload(list_type)
        return unless user_dashboard_list_catalog.key?(list_type)

        calculator = dashboard_calculator
        vrps, targets, options = filtered_scope(calculator)
        if list_type == "cc_jj_work_status"
          return { title: user_dashboard_list_catalog.fetch(list_type), headers: CcJjWorkStatusReport::HEADERS,
            records: CcJjWorkStatusReport.new(calculator: calculator).rows }
        end
        if list_type == "demonstration_method"
          return { title: user_dashboard_list_catalog.fetch(list_type), headers: DemonstrationMethodReport::HEADERS,
            records: DemonstrationMethodReport.new(targets: targets, month: params.key?(:month) ? filter_param(:month) : Date.current.prev_month.strftime("%B")).rows }
        end
        bills = filtered_bills(calculator, vrps)
        set_filtered_scope(calculator, vrps, targets, bills)
        months = calculator.send(:dashboard_month_options_for_targets, targets)
        participation_month = selected_month(:participation_month, months, calculator, targets)
        participation_fcoc = filter_param(:participation_fcoc) || calculator.send(:dashboard_default_visible_fcoc, options[:fcos])
        participation_records = calculator.send(:dashboard_training_participation_records, month_name: participation_month, fcoc_name: participation_fcoc)
        population = calculator.send(:training_participation_population_rows,
          month_name: participation_month, fcoc_name: participation_fcoc, records: participation_records)
        weekly_month = selected_month(:weekly_target_month, months, calculator)
        weekly_fcoc = filter_param(:weekly_target_fcoc) || calculator.send(:dashboard_default_visible_fcoc, options[:fcos])
        weekly_targets = calculator.send(:dashboard_targets_for_month, targets, weekly_month)
        weekly_targets = weekly_targets.select { |target| same?(target.vrp&.fcoc, weekly_fcoc) } if weekly_fcoc.present?
        weekly_rows = calculator.send(:weekly_activity_target_farmer_status_rows,
          weekly_targets, month_name: weekly_month, fcoc_name: weekly_fcoc, week_number: selected_week)
        ics_month = filter_param(:ics_report_month) || participation_month
        ics_targets = calculator.send(:training_participation_targets_for_dashboard,
          month_name: ics_month, fcoc_name: participation_fcoc)
        ics_records = calculator.send(:dashboard_training_participation_records,
          month_name: ics_month, fcoc_name: participation_fcoc)
        selected_ics = filter_param(:ics_report_ics)
        ics_rows = selected_ics.present? ? calculator.send(:ics_farmer_report_rows, ics_targets, ics_records, selected_ics: selected_ics) : []

        context = {
          web: calculator, vrps: vrps, targets: targets, all_targets: targets, bills: bills,
          participation_records: participation_records, participation_population: population,
          participation_month: participation_month, participation_month_value: participation_month,
          weekly_rows: weekly_rows, ics_rows: ics_rows
        }
        @admin_dashboard_api_context = context
        payload = admin_dashboard_list_payload(list_type)
        return unless payload

        payload.merge(title: user_dashboard_list_catalog.fetch(list_type))
      rescue StandardError => error
        Rails.logger.error("User dashboard list API failed: #{error.class}: #{error.message}")
        nil
      end

      def build_user_dashboard_response
        @calculation_stage = "authentication"

        @calculation_stage = "dashboard_context"
        calculator = dashboard_calculator
        @calculation_stage = "visible_vrps_and_targets"
        vrps, targets, options = filtered_scope(calculator)
        @calculation_stage = "visible_bills"
        bills = filtered_bills(calculator, vrps)
        set_filtered_scope(calculator, vrps, targets, bills)

        @calculation_stage = "participation_month_options"
        months = calculator.send(:dashboard_month_options_for_targets, targets)
        participation_month = selected_month(:participation_month, months, calculator, targets)
        participation_fcoc = filter_param(:participation_fcoc) || calculator.send(:dashboard_default_visible_fcoc, options[:fcos])
        @calculation_stage = "participation_records"
        records = calculator.send(:dashboard_training_participation_records, month_name: participation_month, fcoc_name: participation_fcoc)
        @calculation_stage = "participation_counts"
        participation = calculator.send(:training_participation_dashboard_counts,
          month_name: participation_month, fcoc_name: participation_fcoc, records: records)
        @calculation_stage = "weekly_targets"
        weekly_month = selected_month(:weekly_target_month, months, calculator)
        weekly_targets = calculator.send(:dashboard_targets_for_month, targets, weekly_month)
        weekly_fcoc = filter_param(:weekly_target_fcoc) || calculator.send(:dashboard_default_visible_fcoc, options[:fcos])
        if weekly_fcoc.present?
          weekly_targets = weekly_targets.select { |target| same?(target.vrp&.fcoc, weekly_fcoc) }
        end
        weekly_rows = calculator.send(:weekly_activity_target_farmer_status_rows,
          weekly_targets,
          month_name: weekly_month,
          fcoc_name: weekly_fcoc,
          week_number: selected_week)
        weekly_counts = calculator.send(:weekly_activity_target_status_counts_for_rows, weekly_rows)
        weekly = calculator.send(:dashboard_weekly_activity_summary_totals,
          weekly_targets,
          participation,
          week_number: selected_week).merge(status_counts: weekly_counts, rows_count: weekly_rows.size)

        @calculation_stage = "response_payload"
        {
          success: true,
          message: "User dashboard fetched successfully.",
          dashboard_type: "user",
          user: user_payload,
          filters: applied_filters,
          filter_options: options,
          cc_jj_work_status: CcJjWorkStatusReport.new(calculator: calculator).summary,
          demonstration_method: DemonstrationMethodReport.new(targets: targets, month: params.key?(:month) ? filter_param(:month) : Date.current.prev_month.strftime("%B")).summary,
          cards: card_payload(calculator, vrps, targets, bills),
          dashboard_summary: dashboard_summary_payload(calculator, targets, participation, weekly),
          farmer_training_participation_status: participation_payload(participation, participation_month, participation_fcoc, months),
          weekly_activity_target_status: weekly_payload(weekly, weekly_month, weekly_fcoc),
          monthly_target_summary: monthly_summary(targets),
          hierarchy: hierarchy_payload(calculator),
          generated_at: Time.current.iso8601
        }
      rescue StandardError => error
        Rails.logger.error("User dashboard API failed at #{@calculation_stage}: #{error.class}: #{error.message}\n#{error.backtrace&.first(15)&.join("\n")}")
        {
          success: false,
          message: "User dashboard could not be loaded.",
          error: "dashboard_calculation_failed",
          failed_stage: @calculation_stage,
          exception: error.class.name,
          missing_method: (error.name.to_s if error.respond_to?(:name)),
          request_id: request.request_id
        }
      end

      def render_vrp_error
        render json: { success: false, message: "This API is for User login, not Jeevika Jankar login." }, status: :forbidden
      end

      def user_dashboard_cache_key
        version_parts = [
          cache_table_version(TargetMapping),
          cache_table_version(VrpIcsMapping),
          cache_table_version(Vrp),
          cache_table_version(Afl),
          cache_module_records_version(%w[
            training-form
            jeevika-jankar-bill-process
            approval-master
            vrp-approval-history
            user-hierarchy
            new-user
          ])
        ]
        filters = admin_dashboard_cache_filters
        user_key = current_api_user_payload.slice("id", "user_id", "username", "user_name", "user_type").sort.to_h
        ["api-v1-user-dashboard-work-status-v6", user_key, filters, version_parts].to_json
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

      def dashboard_calculator
        ModulesController.new.tap do |controller|
          controller.request = request
          controller.instance_variable_set(:@current_app_user, current_api_user_payload)
        end
      end

      def filtered_scope(calculator)
        @calculation_stage = "dashboard_vrps"
        vrps = calculator.send(:dashboard_vrps).to_a
        @calculation_stage = "dashboard_target_mappings"
        targets = calculator.send(:dashboard_target_mappings).to_a
        preload_dashboard_associations!(targets)
        @calculation_stage = "dashboard_search_filter"
        vrps, targets = search_scope(vrps, targets)
        @calculation_stage = "dashboard_activity_filters"
        options = { main_activities: values(targets, :main_activity_name) }
        selected_main_activity = params.key?(:main_activity) ? filter_param(:main_activity) : default_farmer_activity_filter(calculator, options[:main_activities])
        selected_sub_activity = filter_param(:sub_activity)
        legacy_activity = filter_param(:activity)
        if selected_main_activity.present?
          normalized_main = calculator.send(:normalize_dashboard_text, selected_main_activity)
          main_matches = targets.select { |target| calculator.send(:normalize_dashboard_text, target.main_activity_name) == normalized_main }
          targets = main_matches
        elsif legacy_activity.present?
          targets = targets.select { |target| same?(target.main_activity_name, legacy_activity) || same?(target.activity_name, legacy_activity) }
        end
        options[:sub_activities] = values(targets, :activity_name)
        targets = targets.select { |target| same?(target.activity_name, selected_sub_activity) } if selected_sub_activity.present?
        options[:activities] = (options[:main_activities] + options[:sub_activities]).uniq.sort
        if selected_main_activity.present? || selected_sub_activity.present? || legacy_activity.present?
          vrps = restrict_vrps_to_targets(vrps, targets)
        end
        options[:fcos] = values(vrps, :fcoc)
        @calculation_stage = "dashboard_fcoc_filter"
        vrps, targets = filter_vrps(vrps, targets, :fcoc, filter_param(:fcoc, :fco))
        options[:cluster_incharges] = values(vrps, :cluster_incharge)
        @calculation_stage = "dashboard_cluster_filter"
        vrps, targets = filter_vrps(vrps, targets, :cluster_incharge, filter_param(:cluster_incharge))
        @calculation_stage = "dashboard_ics_filter"
        options[:ics_names] = targets.filter_map { |target| (target.ics_name.presence || target.ics_id).to_s.strip.presence }.uniq.sort
        selected_ics = filter_param(:ics, :ics_name)
        if selected_ics.present?
          targets = targets.select { |target| same?(target.ics_name.presence || target.ics_id, selected_ics) }
          vrps = restrict_vrps_to_targets(vrps, targets)
        end
        options[:months] = values(targets, :month_name)
        @calculation_stage = "dashboard_month_filter"
        selected_dashboard_month = params.key?(:month) ? filter_param(:month) : Date.current.prev_month.strftime("%B")
        if selected_dashboard_month.present?
          targets = targets.select { |t| same?(t.month_name, selected_dashboard_month) }
          vrps = restrict_vrps_to_targets(vrps, targets)
        end
        options[:post_wise_names] = values(vrps, :role)
        @calculation_stage = "dashboard_post_filter"
        vrps, targets = filter_vrps(vrps, targets, :role, filter_param(:post, :post_wise_name))
        options[:vrps] = vrps.map { |v| { id: v.id, name: v.name, user_name: v.user_name } }
        @calculation_stage = "dashboard_vrp_filter"
        selected_vrp_id = filter_param(:vrp_id)
        if selected_vrp_id.present?
          vrps = vrps.select { |v| v.id.to_s == selected_vrp_id.to_s }
          targets = targets.select { |t| t.vrp_id.to_s == selected_vrp_id.to_s }
        end
        [vrps, targets, options]
      end

      def search_scope(vrps, targets)
        query = filter_param(:search)
        return [vrps, targets] if query.blank?

        query = query.to_s.downcase.strip
        vrps = vrps.select { |v| [v.name, v.mobile_no, v.role, v.fcoc, v.cluster_incharge].any? { |x| x.to_s.downcase.include?(query) } }
        targets = targets.select { |t| [t.vrp&.name, t.month_name, t.village_name, t.main_activity_name, t.activity_name].any? { |x| x.to_s.downcase.include?(query) } }
        [vrps, targets]
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
        Rails.logger.debug("User dashboard preload skipped: #{error.class}: #{error.message}")
      end

      def filter_vrps(vrps, targets, attribute, selected)
        return [vrps, targets] if selected.blank?
        filtered = vrps.select { |v| same?(v.public_send(attribute), selected) }
        ids = id_lookup(filtered)
        [filtered, targets.select { |t| ids.key?(t.vrp_id.to_s) }]
      end

      def restrict_vrps_to_targets(vrps, targets)
        ids = targets.each_with_object({}) { |target, lookup| lookup[target.vrp_id.to_s] = true }
        vrps.select { |vrp| ids.key?(vrp.id.to_s) }
      end

      def id_lookup(records)
        records.each_with_object({}) { |record, lookup| lookup[record.id.to_s] = true }
      end

      def filtered_bills(calculator, vrps)
        ids = id_lookup(vrps)
        filters_active = %i[search activity main_activity sub_activity fcoc fco cluster_incharge ics ics_name month post post_wise_name vrp_id].any? { |key| filter_param(key).present? }
        scope = ModuleRecord.where(module_slug: "jeevika-jankar-bill-process")
        if filters_active || calculator.send(:module_cluster_incharge_login?)
          return [] if ids.blank?

          scope = scope.where("data::jsonb ->> 'select_vrp' IN (?)", ids.keys)
        end
        selected_bill_month = filter_param(:month)
        if selected_bill_month.present?
          scope = scope.where("LOWER(BTRIM(data::jsonb ->> 'bill_month')) = ?", selected_bill_month.to_s.strip.downcase)
        end
        records = scope.to_a
          .select { |record| calculator.send(:jeevika_jankar_bill_record_visible?, record) }
        if calculator.send(:module_cluster_incharge_login?)
          records.select! do |record|
            bill_vrp = calculator.send(:jeevika_bill_vrp, record)
            bill_vrp.present? && ids.key?(bill_vrp.id.to_s)
          end
        end
        records = records
          .select { |record| ids.key?(record.data["select_vrp"].to_s) || !filters_active }
        selected_activity = filter_param(:activity)
        selected_main_activity = filter_param(:main_activity)
        selected_sub_activity = filter_param(:sub_activity)
        if selected_activity.present? || selected_main_activity.present? || selected_sub_activity.present?
          records.select! do |record|
            calculator.send(:jeevika_bill_detail_rows, record).any? do |item|
              legacy_match = selected_activity.blank? || same?(item["main_activity"], selected_activity) || same?(item["activity"], selected_activity)
              main_match = selected_main_activity.blank? || same?(item["main_activity"], selected_main_activity)
              sub_match = selected_sub_activity.blank? || same?(item["activity"], selected_sub_activity)
              legacy_match && main_match && sub_match
            end
          end
        end
        records
      end

      def set_filtered_scope(calculator, vrps, targets, bills)
        calculator.instance_variable_set(:@filtered_vrps, vrps)
        calculator.instance_variable_set(:@filtered_targets, targets)
        calculator.instance_variable_set(:@filtered_bills, bills)
      end

      def selected_month(key, months, calculator, targets = nil)
        filter_param(key) || calculator.send(:default_vrp_dashboard_month, months, targets)
      end

      def card_payload(calculator, vrps, targets, bills)
        hierarchy = calculator.send(:user_hierarchy_dashboard_summary)
        activities = targets.map { |t| [t.main_activity_name.to_s.downcase.strip, t.activity_name.to_s.downcase.strip] }
          .reject { |main, sub| main.blank? && sub.blank? }.uniq
        {
          level_2_users: hierarchy[:level_2_total].to_i,
          total_registered_vrp: vrps.size,
          final_approved_vrp: calculator.send(:dashboard_approved_vrps, vrps).size,
          vrp_pending_approval: calculator.send(:dashboard_pending_approval_vrps, vrps).size,
          vrp_targets_assigned: calculator.send(:dashboard_target_record_count, targets),
          activities_assigned: activities.size,
          bill_approved: bills.count { |bill| calculator.send(:dashboard_bill_approved?, bill) },
          bill_pending: bills.count { |bill| calculator.send(:dashboard_bill_pending?, bill) }
        }
      end

      def dashboard_summary_payload(calculator, targets, participation, weekly)
        items = dashboard_summary_values(calculator, targets, participation, weekly)
        {
          language: dashboard_language,
          items: items.map do |key, value|
            labels = DASHBOARD_SUMMARY_LABELS.fetch(key)
            {
              key: key,
              label: labels.fetch(dashboard_language),
              label_en: labels.fetch(:en),
              label_hi: labels.fetch(:hi),
              value: value
            }
          end,
          values: items
        }
      end

      def dashboard_summary_values(calculator, targets, participation, weekly)
        main_activity_count = targets.filter_map { |target| target.main_activity_name.to_s.strip.presence }.uniq.size
        sub_activity_count = targets.filter_map { |target| target.activity_name.to_s.strip.presence }.uniq.size
        village_count = targets.map { |target| [target.village_id.to_s.strip, target.village_name.to_s.strip.downcase] }
          .reject { |id, name| id.blank? && name.blank? }
          .uniq
          .size
        targeted_farmer_count = participation[:total].to_i
        farmer_target_mapping = participation[:target_map_total].to_i
        farmer_achievement = participation[:completed_target_map_total].to_i
        farmer_pending = [farmer_target_mapping - farmer_achievement, 0].max
        activity_target_mapping = weekly[:target]
        activity_achievement = weekly[:completed]
        activity_pending = weekly[:pending]

        {
          total_mapped_villages: village_count,
          targeted_farmers: targeted_farmer_count,
          total_mapped_main_activities: main_activity_count,
          total_mapped_sub_activities: sub_activity_count,
          farmer_wise_target_mapping: farmer_target_mapping,
          farmer_wise_achievement: farmer_achievement,
          farmer_wise_pending_achievement: farmer_pending,
          activity_wise_target_mapping: number(activity_target_mapping),
          activity_wise_achievement: number(activity_achievement),
          activity_wise_pending_achievement: number(activity_pending)
        }
      end

      def participation_payload(counts, month, fcoc, months)
        {
          selected_month: month,
          selected_fcoc: fcoc,
          month_options: months,
          registered_farmer_total: counts[:registered_farmer_total].to_i,
          total_unique_farmers: counts[:total].to_i,
          total_training_farmer: counts[:target_map_total].to_i,
          completed_target_map_total: counts[:completed_target_map_total].to_i,
          green: counts[:green].to_i,
          yellow: counts[:yellow].to_i,
          red: counts[:red].to_i,
          pending: counts[:pending].to_i
        }
      end

      def weekly_payload(totals, month, fcoc)
        status_counts = totals[:status_counts] || {}
        {
          selected_month: month,
          selected_fcoc: fcoc,
          selected_week: selected_week,
          target_mila: number(totals[:target]),
          completed: number(totals[:completed]),
          partial: status_counts[:yellow].to_i,
          pending: number(totals[:pending]),
          target_assigned: status_counts[:total].to_i,
          rows_count: totals[:rows_count].to_i
        }
      end

      def hierarchy_payload(calculator)
        summary = calculator.send(:user_hierarchy_dashboard_summary)
        { level_2_total: summary[:level_2_total].to_i, rows: summary[:rows] }
      end

      def monthly_summary(targets)
        targets.group_by { |t| t.month_name.presence || "Not Set" }.map do |month, rows|
          quantity = rows.sum { |row| row.target_quantity.to_f }
          { month: month, target_records: rows.size, target_quantity: number(quantity) }
        end
      end

      def user_payload
        user = current_api_user_payload
        { id: user["id"], name: user["name"], username: user["username"], role: user["role"], user_type: user["user_type"] }
      end

      def applied_filters
        %i[search activity main_activity sub_activity fcoc fco cluster_incharge ics ics_name month post post_wise_name vrp_id participation_month participation_fcoc weekly_target_month weekly_target_fcoc weekly_target_week]
          .filter_map { |key| value = filter_param(key); [key, value] if value.present? }
          .to_h
      end

      def activity_options(targets)
        targets.flat_map { |t| [t.main_activity_name, t.activity_name] }.compact_blank.uniq.sort
      end

      def selected_week
        week = params[:weekly_target_week].to_i if params[:weekly_target_week].present?
        (1..4).include?(week) ? week : nil
      end

      def values(records, attribute)
        records.filter_map { |record| record.public_send(attribute).to_s.strip.presence }.uniq.sort
      end

      def same?(left, right)
        left.to_s.strip.casecmp(right.to_s.strip).zero?
      end

      def default_farmer_activity_filter(calculator, activity_options)
        Array(activity_options).find do |activity|
          %w[Farmer\ Activity Farmers'\ Training Farmers\ Training].any? do |label|
            calculator.send(:normalize_dashboard_text, activity) == calculator.send(:normalize_dashboard_text, label)
          end
        end
      end

      def number(value)
        value.to_f == value.to_i ? value.to_i : value.to_f.round(2)
      end

      def dashboard_language
        value = params[:language].presence || params[:lang].presence || params[:locale].presence
        value.to_s.downcase.start_with?("hi") ? :hi : :en
      end

      DASHBOARD_SUMMARY_LABELS = {
        total_mapped_villages: {
          en: "Total Mapped Villages",
          hi: "कुल मैप किए गए गाँव"
        },
        targeted_farmers: {
          en: "Targeted Farmers",
          hi: "लक्षित किसानों की संख्या"
        },
        total_mapped_main_activities: {
          en: "Total Mapped Main Activities",
          hi: "कुल मैप की गई मुख्य गतिविधियाँ"
        },
        total_mapped_sub_activities: {
          en: "Total Mapped Sub-Activities",
          hi: "कुल मैप की गई उप-गतिविधियाँ"
        },
        farmer_wise_target_mapping: {
          en: "Farmer-wise Target Mapping",
          hi: "किसान-वार लक्ष्य मैपिंग"
        },
        farmer_wise_achievement: {
          en: "Farmer-wise Achievement",
          hi: "किसान-वार उपलब्धि"
        },
        farmer_wise_pending_achievement: {
          en: "Farmer-wise Pending Achievement",
          hi: "किसान-वार लंबित उपलब्धि"
        },
        activity_wise_target_mapping: {
          en: "Activity-wise Target Mapping",
          hi: "गतिविधि-वार लक्ष्य मैपिंग"
        },
        activity_wise_achievement: {
          en: "Activity-wise Achievement",
          hi: "गतिविधि-वार उपलब्धि"
        },
        activity_wise_pending_achievement: {
          en: "Activity-wise Pending Achievement",
          hi: "गतिविधि-वार लंबित उपलब्धि"
        }
      }.freeze
    end
  end
end
