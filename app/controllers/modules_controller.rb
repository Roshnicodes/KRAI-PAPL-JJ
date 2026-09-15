require "fileutils"
require "securerandom"
require "csv"
require "set"

class ModulesController < ApplicationController
  before_action :authorize_farmer_target_access
  before_action :authorize_jeevika_payment_module_access

  helper_method :module_field_options, :module_select_field?, :static_field_options, :role_management_mappings,
                :access_control_role_mappings, :access_control_field_options,
                :location_hierarchy_mappings, :office_category_mappings, :training_target_mappings,
                :training_activity_setup_mappings, :training_target_month_options,
                :training_activity_mappings, :approval_user_mappings, :approval_user_options,
                :parent_office_mappings, :user_hierarchy_list_rows, :jeevika_jankar_cluster_rows,
                :jeevika_bill_status_label, :jeevika_bill_status_class, :jeevika_bill_rows,
                :jeevika_bill_detail_rows, :jeevika_bill_current_approval_step,
                :jeevika_bill_approval_history, :jeevika_bill_current_approver?,
                :jeevika_bill_approval_steps, :jeevika_bill_summary, :jeevika_bill_approver_display_name,
                :jeevika_bill_attachment_rows, :jeevika_jankar_display_name,
                :jeevika_jankar_vrp_label, :jeevika_bill_time_slot_rows,
                :jeevika_bill_description_rows, :jeevika_bill_bank_rows,
                :jeevika_bill_prepared_by, :jeevika_bill_approved_by_rows,
                :jeevika_bill_payment_month_options, :jeevika_bill_payment_rows,
                :jeevika_payment_bill_date_options, :jeevika_payment_selectable_rows,
                :jeevika_payment_detail_rows, :jeevika_completed_payment_rows,
                :jeevika_completed_payment_month_options, :jeevika_completed_payment_date_options,
                :jeevika_payment_transaction_types,
                :jeevika_bill_vrp, :bill_display_date, :bill_display_datetime,
                :approval_sequence_from_level, :module_record_field_value, :module_upload_public_url,
                :module_upload_public_urls,
                :approval_level_display_label, :approval_level_label_for_sequence,
                :training_participation_status_label, :training_participation_status_caption,
                :training_target_status_label, :training_target_status_caption, :training_target_status_for_percent,
                :training_trainee_department_default, :seed_distribution_target_mappings,
                :seed_distribution_target_month_options, :current_seed_target_vrp_option,
                :add_farmer_form_mappings, :dashboard_vrp_previous_status, :dashboard_vrp_status_label,
                :training_edit_revision_for,
                :dashboard_weekly_report_filter_params

  APPROVAL_REGISTRATION_MODULES = ["Farmer Registration", "VRP Registration", "Jeevika Jankar Registration"].freeze
  OTHER_TARGET_MODULE_SLUGS = ["seed-distribution-target", "papl360-target", "other-target"].freeze
  TARGET_RECORD_MODULE_SLUGS = (["training-form", "add-farmer-form"] + OTHER_TARGET_MODULE_SLUGS).freeze
  JEEVIKA_JANKAR_BILL_FIXED_TOTAL = 5000.0
  JEEVIKA_JANKAR_PAYMENT_DETAIL_SLUG = "jeevika-jankar-payment-detail".freeze
  JEEVIKA_PAYMENT_TRANSACTION_TYPES = ["NEFT", "RTGS", "IMPS"].freeze
  DASHBOARD_CARDS = [
    ["Total VRP", "0", "Registered field resources"],
    ["Active VRP", "0", "Currently active"],
    ["Pending Approvals", "0", "Waiting for action"],
    ["Approved Bills", "0", "Cleared bill records"],
    ["Pending Payments", "0", "Finance queue"],
    ["Weekly Target Status", "0%", "Completion ratio"],
    ["Activity Progress", "0%", "Field activity progress"],
    ["Training Status", "0%", "Training completion"]
  ].freeze

  DASHBOARD_REPORTS = [
    "Weekly Activity Progress",
    "Approval Status Summary",
    "Payment Status Report"
  ].freeze

  MODULES = {
    "state-master" => {
      title: "State Master",
      group: "LG Master",
      purpose: "Location hierarchy maintain karne ke liye.",
      fields: ["State Name", "State Code", "Status"]
    },
    "district-master" => {
      title: "District Master",
      group: "LG Master",
      purpose: "District level location master maintain karne ke liye.",
      fields: ["State", "District Name", "District Code", "Status"]
    },
    "block-master" => {
      title: "Block Master",
      group: "LG Master",
      purpose: "Block level location master maintain karne ke liye.",
      fields: ["State", "District", "Block Name", "Block Code", "Status"]
    },
    "gram-panchayat-master" => {
      title: "Gram Panchayat Master",
      group: "LG Master",
      purpose: "Gram Panchayat master maintain karne ke liye.",
      fields: ["State", "District", "Block", "Gram Panchayat Name", "GP Code", "Status"]
    },
    "village-master" => {
      title: "Village Master",
      group: "LG Master",
      purpose: "Village master maintain karne ke liye.",
      fields: ["State", "District", "Block", "Gram Panchayat", "Village Name", "Village Code", "Status"]
    },
    "lg-directory-list" => {
      title: "All List",
      group: "LG Directory",
      purpose: "State, District, Block, GP, Village ek sath maintain karne ke liye.",
      fields: ["State Name", "State Code", "District Name", "District Code", "Block Name", "Block Code", "Gram Name", "Gram Code", "Village Name", "Village Code"]
    },
    "stakeholder-master" => {
      title: "Stakeholder Master",
      group: "Masters",
      purpose: "Stakeholder name aur logo maintain karna.",
      fields: ["Stakeholder Name in English", "Stakeholder Name in Hindi", "Logo Upload", "Status"]
    },
    "stakeholder-profile" => {
      title: "Stakeholder Profile",
      group: "Masters",
      purpose: "Stakeholder profile aur logo details maintain karna.",
      fields: ["Stakeholder Name", "Profile Name", "CIN", "Phone Number", "Email", "Website", "Full Address", "Logo Upload", "Status"]
    },
    "training-form" => {
      title: "Training Form",
      group: "Farmer Target",
      purpose: "Farmer target details save karne ke liye.",
      fields: [
        "Month",
        "ICS / Block",
        "Gram Name",
        "FCO Name",
        "Trainer Name",
        "Trainer Contact",
        "Cluster Coordinator Name",
        "Agronomist Name",
        "PAPL Staff Name",
        "External Input",
        "Training Date",
        "Training Location",
        "Main Activity",
        "Sub Activity",
        "Training Method",
        "Training Description",
        "Farmer Count",
        "Male Count",
        "Female Count",
        "Total Farmer Count",
        "Next Farmer Training Date",
        "Training Register Upload",
        "Training Photo Upload with Geo Tag"
      ]
    },
    "training-form-list" => {
      title: "Training Form List",
      group: "Farmer Target",
      purpose: "Saved farmer target records dekhne ke liye.",
      fields: [
        "Month",
        "ICS / Block",
        "Gram Name",
        "Trainer Name",
        "Cluster Coordinator Name",
        "Agronomist Name",
        "PAPL Staff Name",
        "External Input",
        "Training Date",
        "Training Location",
        "Main Activity",
        "Sub Activity",
        "Training Method",
        "Farmer Count",
        "Total Farmer Count",
        "Selected Farmers",
        "Male Count",
        "Female Count",
        "Next Farmer Training Date",
        "Training Register Upload",
        "Training Photo Upload with Geo Tag"
      ]
    },
    "seed-distribution-target" => {
      title: "Seed Distribution Target",
      group: "Farmer Target",
      purpose: "Other activity ke seed distribution target aur achievement save karne ke liye.",
      fields: [
        "Jeevika Jankar Name",
        "Contact Number",
        "Department",
        "Month",
        "ICS",
        "Village",
        "Main Activity",
        "Sub Activity",
        "Completion Date",
        "Farmer Count",
        "Target",
        "Achievement",
        "Attachment Upload",
        "Field Photo"
      ]
    },
    "seed-distribution-target-list" => {
      title: "Seed Distribution Target List",
      group: "Farmer Target",
      purpose: "Saved seed distribution target records dekhne ke liye.",
      fields: [
        "Jeevika Jankar Name",
        "Contact Number",
        "Department",
        "Month",
        "ICS",
        "Village",
        "Main Activity",
        "Sub Activity",
        "Completion Date",
        "Farmer Count",
        "Target",
        "Achievement",
        "Attachment Upload",
        "Field Photo",
        "Status"
      ]
    },
    "papl360-target" => {
      title: "PAPL360 Target",
      group: "Farmer Target",
      purpose: "Other activity ke PAPL360 target aur achievement save karne ke liye.",
      fields: [
        "Jeevika Jankar Name",
        "Contact Number",
        "Department",
        "Month",
        "ICS",
        "Village",
        "Main Activity",
        "Sub Activity",
        "Completion Date",
        "Target",
        "Achievement",
        "Excel Upload",
        "Attachment Upload"
      ]
    },
    "papl360-target-list" => {
      title: "PAPL360 Target List",
      group: "Farmer Target",
      purpose: "Saved PAPL360 target records dekhne ke liye.",
      fields: [
        "Jeevika Jankar Name",
        "Contact Number",
        "Department",
        "Month",
        "ICS",
        "Village",
        "Main Activity",
        "Sub Activity",
        "Completion Date",
        "Target",
        "Achievement",
        "Excel Upload",
        "Attachment Upload",
        "Status"
      ]
    },
    "other-target" => {
      title: "Other Target",
      group: "Farmer Target",
      purpose: "Other target aur achievement save karne ke liye.",
      fields: [
        "Jeevika Jankar Name",
        "Contact Number",
        "Department",
        "Month",
        "ICS",
        "Village",
        "Main Activity",
        "Sub Activity",
        "Completion Date",
        "Target",
        "Achievement",
        "Attachment Upload",
        "Field Photo"
      ]
    },
    "other-target-list" => {
      title: "Other Target List",
      group: "Farmer Target",
      purpose: "Saved other target records dekhne ke liye.",
      fields: [
        "Jeevika Jankar Name",
        "Contact Number",
        "Department",
        "Month",
        "ICS",
        "Village",
        "Main Activity",
        "Sub Activity",
        "Completion Date",
        "Target",
        "Achievement",
        "Attachment Upload",
        "Field Photo",
        "Status"
      ]
    },
    "add-farmer-form" => {
      title: "Add Farmer Form",
      group: "Farmer Target",
      purpose: "New Farmer Target ke against No. Farmer save karne ke liye.",
      fields: [
        "Mapped Village",
        "New Farmer Target",
        "No. Farmer"
      ]
    },
    "training-topic-mapping" => {
      title: "Farmer Training Topic Mapping",
      group: "Farmer Training",
      purpose: "Department, training topic aur training subject mapping maintain karne ke liye.",
      fields: ["Department", "Training Topic", "Training Subject", "Status"]
    },
    "bank-master" => {
      title: "Bank Master",
      group: "Masters",
      purpose: "Bank details maintain karna.",
      fields: ["Bank Name", "Branch Name", "IFSC Code", "Status"]
    },
    "month-master" => {
      title: "Month Master",
      group: "Masters",
      purpose: "Financial months maintain karna.",
      fields: ["Month Name", "Financial Year"]
    },
    "project-master" => {
      title: "Project Add",
      group: "Activity Setup",
      purpose: "Project details maintain karna.",
      fields: ["Project Name", "Status"]
    },
    "activity-master" => {
      title: "Activity Master",
      group: "Activity Master",
      purpose: "All activities maintain karna.",
      fields: ["Activity Name", "Status"]
    },
    "parent-office-add" => {
      title: "Parent Office Add",
      group: "Office Setup",
      purpose: "Parent office category maintain karne ke liye.",
      fields: ["Stakeholder Category", "Parent Office Type", "Parent Office", "Parent Office Name", "Office Level", "Status"]
    },
    "office-category-add" => {
      title: "Office Category Add",
      group: "Office Setup",
      purpose: "Office category aur office level maintain karne ke liye.",
      fields: ["Stakeholder Category", "Parent Category", "Office Name", "Office Level", "Status"]
    },
    "office-mapping-add" => {
      title: "Sub Office Add",
      group: "Office Setup",
      purpose: "Office name wise sub office maintain karne ke liye.",
      fields: ["Stakeholder Category", "Parent Category", "Office Name", "Sub Office Name", "Office Level", "Status"]
    },
    "add-vrp-type" => {
      title: "Add Jeevika Jankar Type",
      group: "Stakeholder",
      purpose: "Jeevika Jankar type add karne ke liye.",
      fields: ["Jeevika Jankar Type Name", "Status"]
    },
    "add-activity-group" => {
      title: "Main Activity",
      group: "Activity Setup",
      purpose: "Main activity add karne ke liye.",
      fields: ["Main Activity Name", "Main Activity Type", "Achievement Fill", "Status"]
    },
    "activity-group-list" => {
      title: "Main Activity List",
      group: "Activity Setup",
      purpose: "Saved main activities dekhne ke liye.",
      fields: ["Main Activity Name", "Main Activity Type", "Achievement Fill", "Status"]
    },
    "add-vrp-activity" => {
      title: "Sub Activity",
      group: "Activity Setup",
      purpose: "Sub activity add karne ke liye.",
      fields: ["Main Activity", "Sub Activity Name", "Unit", "Status"]
    },
    "vrp-activity-list" => {
      title: "Sub Activity List",
      group: "Activity Setup",
      purpose: "Saved sub activities dekhne ke liye.",
      fields: ["Main Activity", "Sub Activity Name", "Unit", "Status"]
    },
    "task-completion-indicator" => {
      title: "Task Completion Indicator",
      group: "Activity Setup",
      purpose: "Activity completion indicators maintain karne ke liye.",
      fields: ["Select Activity", "TCI Name", "Select Mandatory", "Status"]
    },
    "task-completion-indicator-list" => {
      title: "Task Completion Indicator List",
      group: "Activity Setup",
      purpose: "Saved task completion indicators dekhne ke liye.",
      fields: ["Select Activity", "TCI Name", "Select Mandatory", "Status"]
    },
    "task-indicator-master" => {
      title: "Task Indicator Master",
      group: "Task Indicator Master",
      purpose: "Activity ke behalf me tasks define karna.",
      fields: ["Activity", "Task Indicator Name", "Unit", "Status"]
    },
    "approval-master" => {
      title: "VRP Approval Form",
      group: "VRP Registration",
      purpose: "VRP registration aur bill approval ke approver maintain karne ke liye.",
      fields: ["Module Name", "Stakeholder Name", "Approval Level", "Approver (Approved By)", "Status", "User Name"]
    },
    "approval-list" => {
      title: "VRP Approval List",
      group: "VRP Registration",
      purpose: "Saved approval mappings dekhne ke liye.",
      fields: ["Module Name", "Stakeholder Name", "Approval Level", "Approver (Approved By)", "Status", "User Name"]
    },
    "ics-master" => {
      title: "ICS Master",
      group: "Masters",
      purpose: "ICS details maintain karne ke liye.",
      fields: ["ICS Name", "Status"]
    },
    "vrp-registration-list" => {
      title: "VRP Registration List",
      group: "VRP Registration",
      purpose: "Registered VRP records manage karne ke liye.",
      fields: ["Search", "Filter", "Export Excel/PDF", "Active/Inactive Status"],
      features: ["View VRP", "Edit VRP", "Delete VRP", "Approval Status", "Document Download"]
    },
    "vrp-bill-add" => {
      title: "Add VRP Bill",
      group: "VRP Bills",
      purpose: "VRP bill submit karne ke liye.",
      fields: ["Select VRP", "Select Financial Year", "Select Bill Month", "Select ICS", "Select Main Activity", "Grand Total", "Status"]
    },
    "vrp-bill-list" => {
      title: "VRP Bill List",
      group: "VRP Bills",
      purpose: "Bills aur payment status track karne ke liye.",
      fields: ["Select VRP", "Select Financial Year", "Select Bill Month", "Select ICS", "Select Main Activity", "Grand Total", "Status"]
    },
    "jeevika-jankar-bill-process" => {
      title: "Jeevika Jankar Bill Process",
      group: "Jeevika Jankar Bill",
      purpose: "Approved VRP ke target, achievement, farmer training aur invoice wise timesheet generate karne ke liye.",
      fields: ["Bill Month", "Jeevika Jankar Name", "Total Target", "Total Achievement"]
    },
    "jeevika-jankar-bill-list" => {
      title: "Jeevika Jankar Bill List",
      group: "Jeevika Jankar Bill",
      purpose: "Saved Jeevika Jankar bill aur invoice records dekhne ke liye.",
      fields: ["Jeevika Jankar Name", "Bill Month", "Total Target", "Total Achievement"]
    },
    "jeevika-jankar-payment-list" => {
      title: "Jeevika Jankar Payment List",
      group: "Jeevika Jankar Bill",
      purpose: "Month wise Jeevika Jankar bills aur bank payment details dekhne ke liye.",
      fields: ["Jeevika Jankar ID", "Status", "Name", "Financial Year", "Bill Month", "Activity Group", "Total Payment", "Activity Name", "Total Target", "Total Achievement", "Bank Name", "IFSC Code", "Account Number", "Bank Passbook", "Download Bill"]
    },
    "jeevika-jankar-payment-list-detail" => {
      title: "Jeevika Jankar Payment List Detail",
      group: "Jeevika Jankar Bill",
      purpose: "Approval date wise Jeevika Jankar payment detail submit karne ke liye.",
      fields: ["Approval Date", "Jeevika Jankar", "Payment Amount", "Transaction ID", "Transaction Type", "Transaction Date", "Transaction File", "Excel File"]
    },
    "jeevika-jankar-completed-payment-list" => {
      title: "Completed Payment List",
      group: "Jeevika Jankar Bill",
      purpose: "Submitted Jeevika Jankar payment details dekhne ke liye.",
      fields: ["Bill Month", "Approval Date", "Jeevika Jankar ID", "Name", "Mobile", "Financial Year", "Amount", "Transaction ID", "Transaction Type", "Transaction Date", "Transaction File", "Excel File"]
    },
    "weekly-target-add" => {
      title: "Add Weekly Target",
      group: "Weekly Target Allocation",
      purpose: "VRP wise weekly target assign karne ke liye.",
      fields: ["Financial Year", "Month", "Week", "Select VRP", "Select VRP Type", "Select ICS", "State", "District", "Block", "Gram Panchayat", "Village", "Activity", "Task Indicator", "Target Quantity", "Unit", "Start Date", "End Date", "Priority", "Remarks", "Assigned By", "Assigned Date", "Status"]
    },
    "weekly-target-list" => {
      title: "Weekly Target List",
      group: "Weekly Target Allocation",
      purpose: "Weekly target records manage karne ke liye.",
      fields: ["View Target", "Edit Target", "Delete Target", "Approval Status", "Completion Status", "Export Excel/PDF"]
    },
    "weekly-progress-report" => {
      title: "Weekly Progress Report",
      group: "Weekly Target Allocation",
      purpose: "Target progress report dekhne ke liye.",
      fields: ["Completed Target", "Pending Target", "Overdue Target", "VRP Wise Progress", "Activity Wise Progress"]
    },
    "monthly-bill-summary" => {
      title: "Monthly Bill Summary",
      group: "Dashboard Reports",
      purpose: "Month wise bill amount, approval, aur payment summary.",
      fields: ["Financial Year", "Month", "Total Bills", "Approved Bills", "Pending Bills", "Paid Amount", "Status"]
    },
    "weekly-activity-progress" => {
      title: "Weekly Activity Progress",
      group: "Dashboard Reports",
      purpose: "Week wise activity aur target progress dekhne ke liye.",
      fields: ["Week", "VRP", "Activity", "Target", "Completed", "Pending", "Status"]
    },
    "approval-status-summary" => {
      title: "Approval Status Summary",
      group: "Dashboard Reports",
      purpose: "Module wise approval pending/approved/rejected status.",
      fields: ["Module Name", "L1 Status", "L2 Status", "Finance Status", "Pending With", "Status"]
    },
    "payment-status-report" => {
      title: "Payment Status Report",
      group: "Dashboard Reports",
      purpose: "Bill payment status aur finance queue report.",
      fields: ["VRP", "Bill Month", "Approved Amount", "Payment Status", "Transaction ID", "Payment Date"]
    },
    "new-user" => {
      title: "New User",
      group: "User Register",
      purpose: "System login user create karne ke liye.",
      fields: ["Stakeholder Category", "Stakeholder Role", "Role", "User Management Role", "Person Type", "State", "District", "Block", "Gram Panchayat", "Village", "Office Name", "Sub Office Name", "Full Address", "Pincode", "First Name", "Last Name", "Gender", "Email", "Password", "Confirmed Password", "User Name", "Mobile No", "User Type", "Status"]
    },
    "all-user" => {
      title: "All User",
      group: "User Register",
      purpose: "Registered users dekhne ke liye.",
      fields: ["Stakeholder Category", "Stakeholder Role", "Role", "User Management Role", "Person Type", "State", "District", "Block", "Gram Panchayat", "Village", "Office Name", "Sub Office Name", "Full Address", "Pincode", "First Name", "Last Name", "Gender", "Email", "Password", "Confirmed Password", "User Name", "Mobile No", "User Type", "Status"]
    },
    "user-hierarchy-mapping" => {
      title: "User Hierarchy Mapping",
      group: "User Mapping",
      purpose: "Kis user ke under kaun user kaam karega map karne ke liye.",
      fields: ["Stakeholder Category", "Level 1 User", "Level 2 User", "Status"]
    },
    "user-hierarchy-list" => {
      title: "Cluster Incharge Under Jeevika Jankar User",
      group: "User Mapping",
      purpose: "Saved user hierarchy aur Jeevika Jankar cluster incharge mapping dekhne ke liye.",
      fields: ["Stakeholder Category", "Level 1 User", "Level 2 User", "Status"]
    },
    "stakeholder-role" => {
      title: "Stakeholder Person Type",
      group: "Stakeholder",
      purpose: "Stakeholder category wise stakeholder person type maintain karne ke liye.",
      fields: ["Stakeholder Category", "Office Name", "Stakeholder Role", "Status"]
    },
    # "role-management" => {
    #   title: "Resource Person Type",
    #   group: "Resource Person Type",
    #   purpose: "Resource person type maintain karne ke liye.",
    #   fields: ["Stakeholder Category", "Stakeholder Role", "Role", "Status"]
    # },
    "role-name" => {
      title: "Role",
      group: "Stakeholder",
      purpose: "Stakeholder category wise role maintain karne ke liye.",
      fields: ["Stakeholder Category", "Stakeholder Role", "Role Name", "Status"]
    },
    # "user-management-role" => {
    #   title: "User Management Person Type",
    #   group: "Resource Person Type",
    #   purpose: "Resource person type wise user management person type maintain karne ke liye.",
    #   fields: ["Stakeholder Category", "Stakeholder Role", "Role", "User Management Role", "Status"]
    # },
    # "person-type" => {
    #   title: "Person Type",
    #   group: "Resource Person Type",
    #   purpose: "User management person type wise person type maintain karne ke liye.",
    #   fields: ["Stakeholder Category", "Stakeholder Role", "Role", "User Management Role", "Person Type", "Status"]
    # },
    "access-control" => {
      title: "Access Control",
      group: "Resource Person Type",
      purpose: "Role wise module access dene ke liye.",
      fields: ["Stakeholder", "Stakeholder Role", "Role Name", "Jeevika Jankar Type", "Module Name", "Sub Module Name", "Can View", "Can Create", "Can Edit", "Can Delete", "Status"]
    },
    "access-control-list" => {
      title: "Access Control List",
      group: "Resource Person Type",
      purpose: "Saved access control records dekhne ke liye.",
      fields: ["Stakeholder", "Stakeholder Role", "Role Name", "Jeevika Jankar Type", "Module Name", "Sub Module Name", "Status"]
    }
  }.freeze

  RECORD_SOURCE_SLUGS = {
    "activity-group-list" => "add-activity-group",
    "vrp-activity-list" => "add-vrp-activity",
    "task-completion-indicator-list" => "task-completion-indicator",
    "approval-list" => "approval-master",
    "access-control-list" => "access-control",
    "vrp-bill-list" => "vrp-bill-add",
    "jeevika-jankar-bill-list" => "jeevika-jankar-bill-process",
    "jeevika-jankar-payment-list" => "jeevika-jankar-bill-process",
    "jeevika-jankar-payment-list-detail" => "jeevika-jankar-bill-process",
    "jeevika-jankar-completed-payment-list" => "jeevika-jankar-payment-detail",
    "training-form-list" => "training-form",
    "seed-distribution-target-list" => "seed-distribution-target",
    "papl360-target-list" => "papl360-target",
    "other-target-list" => "other-target",
    "user-hierarchy-list" => "user-hierarchy-mapping",
    "all-user" => "new-user"
  }.freeze

  def dashboard
    if vrp_login_user?
      prepare_vrp_dashboard
      return
    end

    # 1. Load unfiltered VRPs and Targets in the user's visible scope first
    unfiltered_vrps = dashboard_vrps
    unfiltered_targets = dashboard_target_mappings

    # Start with all targets and VRPs in user scope
    t_scope = unfiltered_targets.to_a
    v_scope = unfiltered_vrps.to_a

    # Apply search filter (if search query is present)
    search_query = dashboard_filter_param(:search)
    if search_query.present?
      q = search_query.to_s.downcase.strip
      v_scope = v_scope.select do |v|
        v.name.to_s.downcase.include?(q) ||
          v.mobile_no.to_s.include?(q) ||
          v.role.to_s.downcase.include?(q) ||
          v.fcoc.to_s.downcase.include?(q) ||
          v.cluster_incharge.to_s.downcase.include?(q)
      end
      t_scope = t_scope.select do |t|
        t.vrp&.name.to_s.downcase.include?(q) ||
          t.month_name.to_s.downcase.include?(q) ||
          t.village_name.to_s.downcase.include?(q) ||
          t.main_activity_name.to_s.downcase.include?(q) ||
          t.activity_name.to_s.downcase.include?(q)
      end
    end

    # ─── CASCADING FILTER DROPDOWNS ───
    # 1. Activity Filter (always show all in initial scope, restrict others)
    @filter_main_activity_options = t_scope.map(&:main_activity_name).uniq.compact_blank.sort
    # Open the dashboard on the farmer-training view when it is available;
    # an explicitly selected activity always takes precedence.
    @dashboard_main_activity_filter_value = dashboard_filter_param(:main_activity) ||
      @filter_main_activity_options.find do |activity|
        normalize_dashboard_text(activity) == normalize_dashboard_text("Farmer Activity") ||
          normalize_dashboard_text(activity) == normalize_dashboard_text("Farmers' Training") ||
          normalize_dashboard_text(activity) == normalize_dashboard_text("Farmers Training")
      end
    normalized_dashboard_main_activity = normalize_dashboard_text(@dashboard_main_activity_filter_value)
    @dashboard_farmer_activity_mode = [
      "Farmer Activity",
      "Farmers' Training",
      "Farmers Training"
    ].any? { |value| normalized_dashboard_main_activity == normalize_dashboard_text(value) } ||
      normalized_dashboard_main_activity.include?(normalize_dashboard_text("Training"))
    selected_main_activity = @dashboard_main_activity_filter_value
    selected_sub_activity = dashboard_filter_param(:sub_activity)
    legacy_activity = dashboard_filter_param(:activity)
    if selected_main_activity.present?
      normalized_selected_main_activity = normalize_dashboard_text(selected_main_activity)
      main_activity_matches = t_scope.select { |t| normalize_dashboard_text(t.main_activity_name) == normalized_selected_main_activity }
      t_scope = main_activity_matches
    elsif legacy_activity.present?
      t_scope = t_scope.select { |t| t.main_activity_name == legacy_activity || t.activity_name == legacy_activity }
    end
    @filter_sub_activity_options = dashboard_filter_sub_activity_options(t_scope)
    selected_sub_activity = nil unless @filter_sub_activity_options.any? { |value| normalize_dashboard_text(value) == normalize_dashboard_text(selected_sub_activity) }
    if selected_sub_activity.nil?
      params.delete(:sub_activity)
      @dashboard_filter_param_cache = {}
    end

    if selected_sub_activity.present?
      t_scope = t_scope.select { |t| normalize_dashboard_text(t.activity_name) == normalize_dashboard_text(selected_sub_activity) }
    end
    if selected_main_activity.present? || selected_sub_activity.present? || legacy_activity.present?
      v_ids = t_scope.map(&:vrp_id).uniq.to_set
      v_scope = v_scope.select { |v| v_ids.include?(v.id) }
    end

    # 2. FCO Filter (depends on selected Activity)
    @filter_fcoc_options = v_scope.map(&:fcoc).uniq.compact_blank.sort
    default_visible_fcoc = dashboard_default_visible_fcoc(@filter_fcoc_options)
    @dashboard_fcoc_filter_value = dashboard_filter_param(:fcoc) || default_visible_fcoc
    if @dashboard_fcoc_filter_value.present?
      f = normalize_dashboard_text(@dashboard_fcoc_filter_value)
      v_scope = v_scope.select { |v| normalize_dashboard_text(v.fcoc) == f }
      v_ids = v_scope.map(&:id).to_set
      t_scope = t_scope.select { |t| t.vrp_id.present? && v_ids.include?(t.vrp_id) }
    else
      default_fco_values = dashboard_summary_fco_filter_values
      v_scope = v_scope.select { |v| (training_fcoc_filter_values(v.fcoc) & default_fco_values).any? }
      t_scope = t_scope.select do |t|
        target_values = training_fcoc_filter_values(t.fco_name, t.fco_id, t.vrp&.fcoc)
        (target_values & default_fco_values).any?
      end
    end

    # 3. Cluster Incharge Filter (depends on selected Activity & FCO)
    current_cluster_labels = hierarchy_cluster_incharge_labels
    @filter_cluster_incharge_options = v_scope.filter_map do |vrp|
      saved_label = vrp.cluster_incharge.to_s.strip
      next if saved_label.blank?

      canonical_label = current_cluster_labels.find { |label| cluster_label_matches?(label, saved_label) }
      (canonical_label.presence || saved_label).sub(/\s*\([^)]*\)\s*\z/, "").strip
    end.uniq { |label| normalize_dashboard_text(label) }.sort
    selected_cluster_incharge = dashboard_filter_param(:cluster_incharge)
    if selected_cluster_incharge.present?
      ci = selected_cluster_incharge.to_s
      v_scope = v_scope.select { |v| cluster_label_matches?(ci, v.cluster_incharge) }
      v_ids = v_scope.map(&:id).to_set
      t_scope = t_scope.select { |t| t.vrp_id.present? && v_ids.include?(t.vrp_id) }
    end

    # 4. ICS Filter
    @filter_ics_options = t_scope.map { |t| t.ics_name.presence || t.ics_id }.uniq.compact_blank.sort
    selected_ics_filter = dashboard_filter_param(:ics)
    if selected_ics_filter.present?
      selected_ics = selected_ics_filter.to_s
      t_scope = t_scope.select { |t| (t.ics_name.presence || t.ics_id).to_s == selected_ics }
      v_ids = t_scope.map(&:vrp_id).uniq.to_set
      v_scope = v_scope.select { |v| v_ids.include?(v.id) }
    end

    # 5. Month Filter (depends on Activity, FCO, Cluster Incharge, ICS)
    @filter_month_options = (t_scope.map(&:month_name) + month_master_month_options)
      .uniq
      .compact_blank
      .sort_by { |m| dashboard_month_index(m) || 0 }
    weekly_target_scope = t_scope.dup
    # Monthly dashboard summary opens on the previous month by default. Users
    # can still choose All Months or another month from the filter.
    default_dashboard_month = Date.current.prev_month.strftime("%B")
    @dashboard_month_filter_value = params.key?(:month) ? dashboard_filter_param(:month) : default_dashboard_month
    if @dashboard_month_filter_value.present?
      m = normalize_dashboard_text(@dashboard_month_filter_value)
      t_scope = t_scope.select { |t| normalize_dashboard_text(t.month_name) == m }
      v_ids = t_scope.map(&:vrp_id).uniq.to_set
      v_scope = v_scope.select { |v| v_ids.include?(v.id) }
    end

    # 6. Post Filter (depends on all above)
    @filter_post_options = v_scope.map(&:role).uniq.compact_blank.sort
    selected_post_filter = dashboard_filter_param(:post)
    if selected_post_filter.present?
      p_filter = selected_post_filter.to_s
      v_scope = v_scope.select { |v| v.role == p_filter }
      v_ids = v_scope.map(&:id).to_set
      t_scope = t_scope.select { |t| t.vrp_id.present? && v_ids.include?(t.vrp_id) }
    end

    # 7. VRP Name Filter (depends on all above)
    @filter_vrp_options = v_scope.map { |v| [v.name, v.id] }.uniq.sort_by(&:first)
    selected_vrp_filter = dashboard_filter_param(:vrp_id)
    if selected_vrp_filter.present?
      vid = selected_vrp_filter.to_i
      v_scope = v_scope.select { |v| v.id == vid }
      t_scope = t_scope.select { |t| t.vrp_id == vid }
    end

    @filtered_vrps = v_scope
    @filtered_targets = t_scope
    @demonstration_method_report = DemonstrationMethodReport.new(targets: t_scope, month: @dashboard_month_filter_value)
    if params[:demonstration_list] == "true"
      @demonstration_method_rows = @demonstration_method_report.rows
      respond_to do |format|
        format.html { render :demonstration_method_list }
        format.json { render json: { success: true, records: @demonstration_method_rows, count: @demonstration_method_rows.size } }
        format.xlsx do
          send_xlsx(headers: DemonstrationMethodReport::HEADERS,
            rows: @demonstration_method_rows.map { |row| DemonstrationMethodReport::HEADERS.map { |key| row[key] } },
            filename: "demonstration-method.xlsx", sheet_name: "Demonstration Method")
        end
      end
      return
    end
    @cc_jj_work_status_report = CcJjWorkStatusReport.new(calculator: self)
    if params[:work_status_list] == "true"
      @work_status_rows = @cc_jj_work_status_report.rows
      respond_to do |format|
        format.html { render :cc_jj_work_status_list }
        format.json { render json: { success: true, records: @work_status_rows, count: @work_status_rows.size } }
        format.xlsx do
          send_xlsx(headers: CcJjWorkStatusReport::HEADERS,
            rows: @work_status_rows.map { |row| CcJjWorkStatusReport::HEADERS.map { |key| row[key] } },
            filename: "cc-jj-work-status.xlsx", sheet_name: "CC and JJ Work Status")
        end
      end
      return
    end
    preload_dashboard_vrp_identity_records!(@filtered_vrps)

    # ─── BILL FILTERING ───
    filtered_vrp_ids = @filtered_vrps.map { |v| v.id.to_s }
    dashboard_filters_active = [
      dashboard_filter_param(:search), dashboard_filter_param(:activity), dashboard_filter_param(:main_activity),
      dashboard_filter_param(:sub_activity), dashboard_filter_param(:fcoc), dashboard_filter_param(:cluster_incharge),
      dashboard_filter_param(:ics), dashboard_filter_param(:month), dashboard_filter_param(:post), dashboard_filter_param(:vrp_id)
    ].any?(&:present?) || [
      @dashboard_main_activity_filter_value, selected_sub_activity, @dashboard_fcoc_filter_value,
      selected_cluster_incharge, selected_ics_filter, @dashboard_month_filter_value, selected_post_filter, selected_vrp_filter
    ].any?(&:present?)

    bill_scope = ModuleRecord.where(module_slug: "jeevika-jankar-bill-process")
    if dashboard_filters_active || module_cluster_incharge_login?
      bill_scope = filtered_vrp_ids.any? ? bill_scope.where("data::jsonb ->> 'select_vrp' IN (?)", filtered_vrp_ids) : ModuleRecord.none
    end
    bill_records = bill_scope.to_a
    unless admin_dashboard_user?
      bill_records = bill_records.select { |r| jeevika_jankar_bill_record_visible?(r) }
    end
    bill_records = bill_records.select { |r| jeevika_jankar_bill_blocks_duplicate?(r) }

    # A cluster incharge dashboard is a roll-up of the VRPs mapped below that
    # incharge. Approval visibility can legitimately include unrelated bills,
    # but those records must not leak into the cluster dashboard totals.
    if module_cluster_incharge_login?
      bill_records = bill_records.select do |record|
        bill_vrp = jeevika_bill_vrp(record)
        bill_vrp.present? && filtered_vrp_ids.include?(bill_vrp.id.to_s)
      end
    end

    bill_records = bill_records.select do |r|
      next false unless r.data.present?

      # Keep bills mapped to currently visible/filtered VRPs.
      next true if filtered_vrp_ids.include?(r.data["select_vrp"].to_s)

      # Approver/creator bills must still count even when VRP is outside dashboard VRP scope.
      next true unless dashboard_filters_active

      false
    end

    # Restrict bills by Selected Activity
    selected_bill_activity = dashboard_filter_param(:activity)
    selected_bill_main_activity = dashboard_filter_param(:main_activity)
    selected_bill_sub_activity = dashboard_filter_param(:sub_activity)
    if selected_bill_activity.present? || selected_bill_main_activity.present? || selected_bill_sub_activity.present?
      act = selected_bill_activity.to_s
      main_activity = selected_bill_main_activity.to_s
      sub_activity = selected_bill_sub_activity.to_s
      bill_records = bill_records.select do |r|
        items = jeevika_bill_detail_rows(r)
        items.any? do |item|
          legacy_matches = act.blank? || item["main_activity"] == act || item["activity"] == act
          main_matches = main_activity.blank? || normalize_dashboard_text(item["main_activity"]) == normalize_dashboard_text(main_activity)
          sub_matches = sub_activity.blank? || normalize_dashboard_text(item["activity"]) == normalize_dashboard_text(sub_activity)
          legacy_matches && main_matches && sub_matches
        end
      end
    end

    @filtered_bills = bill_records

    targets = @filtered_targets
    @training_month_options = dashboard_month_options_for_targets(targets)
    selected_month = dashboard_selected_training_month_name.presence || @dashboard_month_filter_value.presence || default_vrp_dashboard_month(@training_month_options, targets)
    month_targets = dashboard_targets_for_month(targets, selected_month)
    @training_sub_activity_options = dashboard_sub_activity_options_for_targets(month_targets, selected_month)
    requested_sub_activity = dashboard_selected_training_sub_activity_name
    selected_sub_activity = @training_sub_activity_options.find do |option|
      normalize_dashboard_text(option) == normalize_dashboard_text(requested_sub_activity)
    end || @training_sub_activity_options.first
    @dashboard_title = admin_dashboard_user? ? "Admin Dashboard" : dashboard_current_user_title
    @dashboard_caption = admin_dashboard_user? ? "Live complete system summary." : "Live summary for your mapped records."
    @training_selected_month = selected_month
    @training_selected_sub_activity = selected_sub_activity
    default_status_month = default_vrp_dashboard_month(@training_month_options, targets)
    @participation_month_filter_value = @dashboard_month_filter_value.presence || default_status_month
    @participation_selected_month = @participation_month_filter_value == "all" ? nil : @participation_month_filter_value
    @participation_fcoc_filter_value = @dashboard_fcoc_filter_value.presence || dashboard_default_visible_fcoc(@filter_fcoc_options)
    @participation_week_filter_value = dashboard_filter_param(:weekly_target_week).to_i if dashboard_filter_param(:weekly_target_week).present?
    @participation_week_filter_value = nil unless (1..4).include?(@participation_week_filter_value)
    if @dashboard_farmer_activity_mode
      participation_dashboard_counts = cached_training_participation_dashboard_counts(
        month_name: @participation_selected_month,
        fcoc_name: @participation_fcoc_filter_value,
        week_number: @participation_week_filter_value
      )
      mapped_count, mapped_popups = farmer_training_mapped_farmer_count_and_popups(
        month_name: @participation_selected_month,
        fcoc_name: @participation_fcoc_filter_value
      )
      no_training_count, no_training_popups, red_fco_details = farmer_training_no_training_count_and_popups(
        month_name: @participation_selected_month,
        fcoc_name: @participation_fcoc_filter_value
      )
      yellow_count, yellow_popups = farmer_training_yellow_farmer_count_and_popups(
        month_name: @participation_selected_month,
        fcoc_name: @participation_fcoc_filter_value
      )
      green_count, green_popups = farmer_training_green_farmer_count_and_popups(
        month_name: @participation_selected_month,
        fcoc_name: @participation_fcoc_filter_value
      )
      participation_dashboard_counts[:red] = no_training_count if participation_dashboard_counts.is_a?(Hash)
      participation_dashboard_counts[:yellow] = yellow_count if participation_dashboard_counts.is_a?(Hash)
      participation_dashboard_counts[:green] = green_count if participation_dashboard_counts.is_a?(Hash)
      participation_dashboard_counts[:total] = mapped_count if participation_dashboard_counts.is_a?(Hash)

      @training_participation_status_cards = training_participation_dashboard_status_cards(
        participation_dashboard_counts,
        month_name: @participation_selected_month,
        fcoc_name: @participation_fcoc_filter_value,
        week_number: @participation_week_filter_value
      )
      @training_registered_farmer_count = participation_dashboard_counts[:registered_farmer_total].to_i
      @training_unique_farmer_count = mapped_count
      @training_mapped_farmer_count = mapped_count
      @training_mapped_farmer_popups = mapped_popups
      @training_no_training_popups = no_training_popups
      @training_red_fco_details = red_fco_details
      @training_yellow_farmer_popups = yellow_popups
      @training_green_farmer_popups = green_popups
      @training_total_training_farmer_count = participation_dashboard_counts[:target_map_total].to_i
      @training_completed_target_map_count = participation_dashboard_counts[:completed_target_map_total].to_i
      visible_vrp_ids = @filtered_vrps.map(&:id)
      ics_mappings = model_ready?(:VrpIcsMapping) ? VrpIcsMapping.where(vrp_id: visible_vrp_ids).to_a : []
      if selected_ics_filter.present?
        selected_ics = normalize_dashboard_text(selected_ics_filter)
        ics_mappings.select! do |mapping|
          normalize_dashboard_text(mapping.ics_name.presence || mapping.ics_id) == selected_ics
        end
      end
      # Full target/participation rows are available on their dedicated report
      # pages. The dashboard renders summary boxes only, so building those large
      # unused datasets here needlessly multiplies queries and memory usage.
      @ics_farmer_report_month_value = @participation_month_filter_value
      @ics_farmer_report_selected_month = @ics_farmer_report_month_value == "all" ? nil : @ics_farmer_report_month_value
      ics_report_targets = training_participation_targets_for_dashboard(
        month_name: @ics_farmer_report_selected_month,
        fcoc_name: @participation_fcoc_filter_value
      )
      @ics_farmer_report_options = ics_farmer_report_options([], ics_report_targets)
      @ics_farmer_report_selected_ics = dashboard_filter_param(:ics_report_ics)
      @ics_farmer_report_summary = ics_farmer_report_summary([], selected_ics: @ics_farmer_report_selected_ics)
      @weekly_target_month_filter_value = @dashboard_month_filter_value.presence || default_status_month
      @weekly_dashboard_selected_month = @weekly_target_month_filter_value == "all" ? nil : @weekly_target_month_filter_value
      @weekly_target_fcoc_filter_value = @dashboard_fcoc_filter_value.presence || dashboard_default_visible_fcoc(@filter_fcoc_options)
      @weekly_target_week_filter_value = @participation_week_filter_value
      weekly_dashboard_targets = dashboard_targets_for_month(weekly_target_scope, @weekly_dashboard_selected_month)
      if selected_post_filter.present?
        selected_post = selected_post_filter.to_s
        weekly_dashboard_targets = weekly_dashboard_targets.select { |target| target.vrp&.role.to_s == selected_post }
      end
      if selected_vrp_filter.present?
        selected_vrp_id = selected_vrp_filter.to_s
        weekly_dashboard_targets = weekly_dashboard_targets.select { |target| target.vrp_id.to_s == selected_vrp_id }
      end
      weekly_dashboard_targets = filter_weekly_activity_targets(
        weekly_dashboard_targets,
        activity: dashboard_filter_param(:activity, :main_activity),
        sub_activity: dashboard_filter_param(:training_sub_activity, :sub_activity),
        fcoc: @weekly_target_fcoc_filter_value
      )
      @dashboard_weekly_target_cards = weekly_activity_target_status_cards(
        weekly_dashboard_targets,
        month_name: @weekly_dashboard_selected_month,
        fcoc_name: @weekly_target_fcoc_filter_value,
        week_number: @weekly_target_week_filter_value,
        participation_counts: participation_dashboard_counts
      )
    else
      @dashboard_other_activity_totals = dashboard_other_activity_totals(t_scope)
    end
    summary_targets = training_participation_active_vrp_targets(t_scope)
    @dashboard_summary_cards = dashboard_summary_cards(summary_targets)
    @demonstration_method_cards = @dashboard_farmer_activity_mode ? demonstration_method_cards : []
    @dashboard_cards = @dashboard_farmer_activity_mode ? dashboard_cards : []
    @dashboard_generated_at = Time.current

    respond_to do |format|
      format.html
      format.xlsx do
        export_rows = dashboard_filter_export_rows
        send_xlsx(
          headers: export_rows.shift || [],
          rows: export_rows,
          filename: "dashboard-export-#{Time.current.strftime("%Y%m%d%H%M")}.xlsx",
          sheet_name: "Dashboard Export"
        )
      end
    end
  end


  # Drill-down for the Demonstration Method View List "Target Farmer Count" column.
  # Lists the targeted farmers (from target_mappings.afl_ids) for one JJ + month,
  # restricted to the farmers/targets the current user is allowed to see.
  def demonstration_method_farmers
    vrp_id = params[:vrp_id].to_s.strip
    month = params[:training_month].presence || params[:month].presence
    @demonstration_farmer_vrp = model_ready?(:Vrp) ? Vrp.find_by(id: vrp_id) : nil
    @demonstration_farmer_month = month

    base = dashboard_visible_target_scope
    base = base.where(vrp_id: vrp_id) if vrp_id.present?
    base = base.where("LOWER(TRIM(month_name)) = ?", month.to_s.strip.downcase) if month.present?

    farmer_sql = <<~SQL
      SELECT DISTINCT a.id AS "Farmer ID", a.farmer_name AS "Farmer Name",
        a.father_name AS "Father Name", a.tracenet_no AS "TraceNet No",
        CASE WHEN UPPER(BTRIM(COALESCE(a.mobile_no, ''))) IN ('', 'NULL') THEN NULL ELSE a.mobile_no END AS "Mobile No"
      FROM (#{base.select(:afl_ids).to_sql}) t
      CROSS JOIN LATERAL jsonb_array_elements_text(
        CASE WHEN jsonb_typeof(t.afl_ids::jsonb) = 'array' THEN t.afl_ids::jsonb ELSE '[]'::jsonb END
      ) AS af(afl_id)
      JOIN afls a ON a.id::text = af.afl_id
      ORDER BY a.farmer_name
    SQL
    @demonstration_farmers = TargetMapping.connection.select_all(farmer_sql).to_a

    respond_to do |format|
      format.html { render :demonstration_method_farmers }
      format.xlsx do
        headers = @demonstration_farmers.first&.keys || ["Farmer ID", "Farmer Name", "Father Name", "TraceNet No", "Mobile No"]
        send_xlsx(headers: headers,
          rows: @demonstration_farmers.map { |r| headers.map { |k| r[k] } },
          filename: "demonstration-method-farmers.xlsx", sheet_name: "Targeted Farmers")
      end
    end
  end

  def farmer_training_participation
    selected_month = dashboard_filter_param(:training_month, :month)
    selected_sub_activity = dashboard_filter_param(:training_sub_activity, :sub_activity)
    selected_fcoc = dashboard_filter_param(:training_fcoc, :fcoc)
    selected_fcoc = Array(params[:fco_id]).reject(&:blank?) if selected_fcoc.blank? && params[:fco_id].present?
    selected_main_activity = dashboard_filter_param(:main_activity, :activity)
    selected_training_method = params[:training_method].to_s.strip
    selected_week_param = params[:week].presence || params[:weekly_target_week].presence
    selected_week = selected_week_param.to_i if selected_week_param.present?
    selected_week = nil unless (1..4).include?(selected_week)
    selected_status = normalize_training_participation_status(params[:status]) || "green"
    training_records = dashboard_training_participation_records(month_name: selected_month, main_activity_name: selected_main_activity, sub_activity_name: selected_sub_activity, fcoc_name: selected_fcoc)
    training_records = training_records.select { |record| training_record_week_number(record) == selected_week } if selected_week.present?
    if selected_training_method.present?
      training_records = training_records.select do |record|
        normalize_dashboard_text(record.data["training_method"]) == normalize_dashboard_text(selected_training_method)
      end
    end
    participation_targets = training_participation_targets_for_dashboard(
      month_name: selected_month,
      fcoc_name: selected_fcoc,
      main_activity_name: selected_main_activity,
      sub_activity_name: selected_sub_activity
    )
    participation_targets = training_participation_targets_for_week(participation_targets, selected_week) if selected_week.present?
    participation_dashboard_counts = training_participation_dashboard_counts(
      month_name: selected_month,
      fcoc_name: selected_fcoc,
      records: training_records,
      targets: participation_targets,
      week_number: selected_week
    )
    population_rows = nil
    target_map_rows = nil
    record_rows = nil

    @training_participation_status = selected_status
    @training_participation_title = training_participation_status_label(selected_status)
    @training_participation_caption = training_participation_status_caption(selected_status)
    @training_participation_rows = if selected_status == "unique" || selected_status == "mapped"
      farmer_training_participation_rows_from_sql(
        "unique",
        month_name: selected_month,
        fcoc_name: selected_fcoc
      )
    elsif %w[no_activity no_training_mapping no_training training_mapped_no_entry no_entry red total_red pending].include?(selected_status)
      farmer_training_participation_rows_from_sql(
        selected_status,
        month_name: selected_month,
        fcoc_name: selected_fcoc
      )
    elsif selected_status == "yellow" || selected_status == "only_1_training" || selected_status == "1_training"
      farmer_training_participation_rows_from_sql(
        "yellow",
        month_name: selected_month,
        fcoc_name: selected_fcoc,
        week_number: selected_week
      )
    elsif selected_status == "green" || selected_status == "1_plus_trainings" || selected_status == "more_than_1"
      farmer_training_participation_rows_from_sql(
        "green",
        month_name: selected_month,
        fcoc_name: selected_fcoc,
        week_number: selected_week
      )
    elsif selected_status == "training_unique"
      record_rows = training_participation_farmer_rows_from_records(training_records)
    elsif selected_status == "completed_map"
      target_map_rows = training_participation_target_map_rows(participation_targets, month_name: selected_month)
      target_map_rows.select { |row| row[:completed_activity_count].to_i.positive? }
    elsif selected_status == "pending_achievement"
      target_map_rows = training_participation_target_map_rows(participation_targets, month_name: selected_month)
      target_map_rows.select { |row| row[:completed_activity_count].to_i < row[:assigned_activity_count].to_i }
    elsif selected_status == "total"
      target_map_rows = training_participation_target_map_rows(participation_targets, month_name: selected_month)
      target_map_rows
    else
      record_rows = training_participation_farmer_rows_from_records(training_records)
      record_rows.select { |row| row[:status] == selected_status }
    end
    mapped_sql_count, mapped_sql_popups = farmer_training_mapped_farmer_count_and_popups(
      month_name: selected_month,
      fcoc_name: selected_fcoc
    )
    no_training_sql_count, no_training_sql_popups = farmer_training_no_training_count_and_popups(
      month_name: selected_month,
      fcoc_name: selected_fcoc
    )
    yellow_sql_count, yellow_sql_popups = farmer_training_yellow_farmer_count_and_popups(
      month_name: selected_month,
      fcoc_name: selected_fcoc
    )
    green_sql_count, green_sql_popups = farmer_training_green_farmer_count_and_popups(
      month_name: selected_month,
      fcoc_name: selected_fcoc
    )

    @training_participation_totals = participation_dashboard_counts.slice(:green, :yellow, :red, :pending, :total)
    @training_selected_week = selected_week
    @training_unique_farmer_count = mapped_sql_count
    @training_mapped_farmer_count = mapped_sql_count
    @training_mapped_farmer_popups = mapped_sql_popups
    @training_no_training_popups = no_training_sql_popups
    @training_yellow_farmer_popups = yellow_sql_popups
    @training_green_farmer_popups = green_sql_popups
    @training_total_training_farmer_count = participation_dashboard_counts[:target_map_total].to_i
    @training_completed_target_map_count = participation_dashboard_counts[:completed_target_map_total].to_i
    @training_participation_totals[:unique] = mapped_sql_count
    @training_participation_totals[:red] = no_training_sql_count
    @training_participation_totals[:pending] = no_training_sql_count
    @training_participation_totals[:yellow] = yellow_sql_count
    @training_participation_totals[:green] = green_sql_count
    @training_participation_totals[:total] = @training_total_training_farmer_count
    @training_participation_totals[:completed_map] = @training_completed_target_map_count
    @training_selected_month = selected_month
    @training_selected_sub_activity = selected_sub_activity
    @training_selected_fcoc = selected_fcoc
    @training_selected_method = selected_training_method
    enrich_training_participation_list_rows!(@training_participation_rows, training_records, participation_targets)
    @training_participation_search = params[:search].to_s.strip
    if @mapped_farmer_details
      columns = @mapped_farmer_details.columns | %w[training_register_urls training_photo_urls]
      details = @mapped_farmer_details.to_a.each_with_index.map do |detail, index|
        row = @training_participation_rows[index]
        detail.merge("cluster_incharge" => row[:cluster_incharge],
          "training_register_urls" => Array(row[:training_register_urls]).join(", "),
          "training_photo_urls" => Array(row[:training_photo_urls]).join(", "))
      end
      if @training_participation_search.present?
        matching = details.each_index.select { |index| training_participation_search_match?(details[index].values) }
        details = matching.map { |index| details[index] }
        @training_participation_rows = matching.map { |index| @training_participation_rows[index] }
      end
      @mapped_farmer_details = ActiveRecord::Result.new(columns, details.map { |detail| columns.map { |column| detail[column] } })
    elsif @training_participation_search.present?
      @training_participation_rows = @training_participation_rows.select { |row| training_participation_search_match?(row.values) }
    end
    @training_participation_total_count = @training_participation_rows.size
    @training_participation_page = [params[:page].to_i, 1].max
    per_page_value = params[:per_page].present? ? params[:per_page].to_i : 20
    @training_participation_per_page = [[per_page_value, 20].max, 500].min
    @training_participation_total_pages = [(@training_participation_total_count.to_f / @training_participation_per_page).ceil, 1].max
    @training_participation_page = @training_participation_total_pages if @training_participation_page > @training_participation_total_pages
    @training_participation_page_rows = @training_participation_rows.slice((@training_participation_page - 1) * @training_participation_per_page, @training_participation_per_page) || []

    if @mapped_farmer_details
      # Paginate the rendered rows so the browser does not build all 9k+ <tr> at once
      # (that froze the page). Counts and exports still use the full result below.
      @training_participation_total_count = @mapped_farmer_details.rows.size
      @training_participation_total_pages = [(@training_participation_total_count.to_f / @training_participation_per_page).ceil, 1].max
      @training_participation_page = [[@training_participation_page, @training_participation_total_pages].min, 1].max
    end
    if @mapped_farmer_details && request.format.csv?
      send_data(CSV.generate { |csv| csv << @mapped_farmer_details.columns; @mapped_farmer_details.rows.each { |row| csv << row } },
        filename: "#{@training_participation_status}-farmers.csv", type: "text/csv")
      return
    end
    if @mapped_farmer_details && request.format.xlsx?
      send_xlsx(headers: @mapped_farmer_details.columns, rows: @mapped_farmer_details.rows,
        filename: "#{@training_participation_status}-farmers-#{selected_month.presence || 'August'}.xlsx", sheet_name: "Farmer Details")
      return
    end

    # HTML only: render just the current page's rows so the DOM stays small (no freeze).
    if @mapped_farmer_details
      page_rows = @mapped_farmer_details.rows.slice((@training_participation_page - 1) * @training_participation_per_page, @training_participation_per_page) || []
      @mapped_farmer_details = ActiveRecord::Result.new(@mapped_farmer_details.columns, page_rows)
    end

    respond_to do |format|
      format.html
      format.csv do
        send_data(
          training_participation_rows_csv(@training_participation_rows),
          filename: "farmer-training-#{selected_status}-#{Time.current.strftime("%Y%m%d%H%M")}.csv",
          type: "text/csv"
        )
      end
      format.xlsx do
        send_xlsx(
          headers: training_participation_export_headers,
          rows: training_participation_export_rows(@training_participation_rows),
          filename: "farmer-training-#{selected_status}-#{Time.current.strftime("%Y%m%d%H%M")}.xlsx",
          sheet_name: "Training Participation"
        )
      end
      format.zip do
        send_data(
          training_participation_attachments_zip(@training_participation_rows),
          filename: "farmer-training-attachments-#{selected_status}-#{Time.current.strftime("%Y%m%d%H%M")}.zip",
          type: "application/zip"
        )
      end
    end
  end

  def farmer_training_target_status
    targets = dashboard_participation_targets
    selected_month = dashboard_filter_param(:training_month, :month)
    selected_sub_activity = dashboard_filter_param(:training_sub_activity, :sub_activity)
    selected_status = normalize_training_target_status(params[:status]) || "green"
    filtered_targets = if selected_month.present? && selected_sub_activity.present?
      dashboard_targets_for_filters(targets, selected_month, selected_sub_activity)
    elsif selected_month.present?
      dashboard_targets_for_month(targets, selected_month)
    else
      targets
    end

    preload_training_farmers_for_targets!(filtered_targets)
    @training_target_status = selected_status
    @training_target_status_title = training_target_status_label(selected_status)
    @training_target_status_caption = training_target_status_caption(selected_status)
    all_status_rows = training_target_status_rows(filtered_targets)
    @training_target_status_rows = all_status_rows
      .select { |row| row[:status_class] == selected_status }
    @training_target_status_totals = training_target_status_counts_for_rows(all_status_rows)
    @training_selected_month = selected_month
    @training_selected_sub_activity = selected_sub_activity

    respond_to do |format|
      format.html
      format.csv do
        send_data(
          training_target_status_rows_csv(@training_target_status_rows),
          filename: "farmer-training-target-#{selected_status}-#{Time.current.strftime("%Y%m%d%H%M")}.csv",
          type: "text/csv"
        )
      end
      format.xlsx do
        send_xlsx(
          rows: training_target_status_rows_csv(@training_target_status_rows),
          filename: "farmer-training-target-#{selected_status}-#{Time.current.strftime("%Y%m%d%H%M")}.xlsx",
          sheet_name: "Training Target"
        )
      end
    end
  end

  def farmer_participation_report
    all_entries = farmer_participation_entries
    entries = all_entries
    selected_farmer_ids = Array(params[:farmer_ids].presence || params[:farmer_id]).map(&:to_s).reject(&:blank?).uniq
    selected_fcocs = Array(params[:fcocs].presence || params[:fcoc]).map(&:to_s).reject(&:blank?).uniq
    @farmer_participation_filters_applied = selected_farmer_ids.any? || selected_fcocs.any? || params[:month].present? || params[:vrp_id].present?

    farmer_options = all_entries
      .group_by { |entry| entry[:farmer_id] }
      .map { |farmer_id, farmer_entries| [farmer_entries.map { |entry| entry[:farmer_label] }.find { |label| !label.start_with?("Farmer #") } || farmer_entries.first[:farmer_label], farmer_id] }
      .sort_by { |label, _id| label.downcase }
    month_options = (participation_text_filter_options(all_entries, :month) + month_master_month_options)
      .uniq { |month| normalize_dashboard_text(month) }
      .sort_by { |month| [dashboard_month_index(month), month] }
    visible_fcoc_options = farmer_participation_visible_vrps.filter_map do |vrp|
      vrp.fcoc.to_s.strip.presence
    end
    fcoc_options = (participation_text_filter_options(all_entries, :fcoc) + visible_fcoc_options).uniq.sort
    vrp_options = all_entries.map { |entry| [entry[:vrp_name], entry[:vrp_id]] }.reject { |label, id| label.blank? || id.blank? }.uniq.sort_by { |label, _id| label.downcase }

    entries = entries.select { |entry| selected_farmer_ids.include?(entry[:farmer_id].to_s) } if selected_farmer_ids.any?
    entries = entries.select { |entry| entry[:month] == params[:month].to_s } if params[:month].present?
    entries = entries.select { |entry| selected_fcocs.include?(entry[:fcoc].to_s) } if selected_fcocs.any?
    entries = entries.select { |entry| entry[:vrp_id] == params[:vrp_id].to_s } if params[:vrp_id].present?

    @farmer_participation_selected_filters = {
      farmer_ids: selected_farmer_ids,
      month: params[:month].to_s,
      fcocs: selected_fcocs,
      vrp_id: params[:vrp_id].to_s
    }

    @farmer_participation_filter_options = {
      farmers: farmer_options,
      months: month_options,
      fcocs: fcoc_options,
      vrps: vrp_options
    }
    @farmer_participation_vrp_fcoc_map = all_entries
      .reject { |entry| entry[:vrp_id].blank? || entry[:fcoc].blank? || entry[:fcoc] == "-" }
      .group_by { |entry| entry[:vrp_id] }
      .transform_values { |vrp_entries| vrp_entries.map { |entry| entry[:fcoc] }.uniq.sort }
    @farmer_participation_farmer_filter_map = all_entries
      .group_by { |entry| entry[:farmer_id].to_s }
      .transform_values do |farmer_entries|
        {
          months: farmer_entries.map { |entry| entry[:month] }.compact_blank.uniq,
          fcocs: farmer_entries.map { |entry| entry[:fcoc] }.compact_blank.reject { |value| value == "-" }.uniq
        }
      end

    if params[:vrp_id].present? && selected_fcocs.any?
      compatible_fcocs = @farmer_participation_vrp_fcoc_map[params[:vrp_id].to_s] || []
      incompatible_fcocs = selected_fcocs - compatible_fcocs
      if incompatible_fcocs.any?
        selected_vrp_name = vrp_options.find { |_label, id| id == params[:vrp_id].to_s }&.first || "Selected Jeevika Jankar"
        @farmer_participation_filter_warning = "#{selected_vrp_name} ke saath #{incompatible_fcocs.join(', ')} compatible nahi hai. Available FCOC: #{compatible_fcocs.join(', ').presence || 'koi nahi'}."
      end
    end

    entries = [] unless @farmer_participation_filters_applied

    @farmer_participation_rows = entries
      .group_by { |entry| [entry[:farmer_id], entry[:month], entry[:main_activity], entry[:sub_activity], entry[:training_method], entry[:vrp_id]] }
      .map do |_key, grouped|
        first = grouped.first
        first.merge(
          participation_count: grouped.size,
          training_dates: grouped.map { |entry| entry[:training_date] }.compact_blank.uniq.sort.join(", ").presence || "-",
          training_register_urls: grouped.flat_map { |entry| Array(entry[:training_register_urls]) }.compact_blank.uniq,
          training_photo_urls: grouped.flat_map { |entry| Array(entry[:training_photo_urls]) }.compact_blank.uniq
        )
      end
      .sort_by { |row| [row[:farmer_name].downcase, row[:main_activity].downcase, row[:sub_activity].downcase, row[:training_method].downcase] }

    @farmer_participation_totals = {
      farmers: entries.map { |entry| entry[:farmer_id] }.uniq.size,
      participations: entries.size,
      activities: entries.map { |entry| [entry[:main_activity], entry[:sub_activity]] }.uniq.size,
      trainings: entries.map { |entry| entry[:training_method] }.reject { |value| ["-", "Not Recorded"].include?(value) }.uniq.size
    }

    respond_to do |format|
      format.html
      format.xlsx do
        headers = ["Farmer Name", "Tracenet No.", "Village", "Month", "FCOC", "Jeevika Jankar", "Main Activity", "Sub Activity", "Training Method", "Participation Count", "Training Dates", "Training Register Upload", "Training Photo Upload with Geo Tag"]
        rows = @farmer_participation_rows.map do |row|
          [row[:farmer_name], row[:tracenet_no], row[:village], row[:month], row[:fcoc], row[:vrp_name], row[:main_activity], row[:sub_activity], row[:training_method], row[:participation_count], row[:training_dates], Array(row[:training_register_urls]).join(", "), Array(row[:training_photo_urls]).join(", ")]
        end
        send_xlsx(headers: headers, rows: rows, filename: "farmer-participation-#{Time.current.strftime('%Y%m%d%H%M')}.xlsx", sheet_name: "Farmer Participation")
      end
    end
  end

  def weekly_activity_target_report
    targets = dashboard_participation_targets
    selected_month = dashboard_filter_param(:training_month, :month)
    selected_activity = dashboard_filter_param(:activity, :main_activity)
    selected_sub_activity = dashboard_filter_param(:training_sub_activity, :sub_activity)
    selected_fcoc = dashboard_filter_param(:training_fcoc, :fcoc)
    selected_fcoc = Array(params[:fco_id]).reject(&:blank?) if selected_fcoc.blank? && params[:fco_id].present?
    selected_week = params[:week].to_i if params[:week].present?
    selected_week = nil unless (1..4).include?(selected_week)
    requested_status = params[:status].to_s.downcase.presence
    selected_status = normalize_training_target_status(requested_status)
    selected_status_key = requested_status == "total" ? "total" : selected_status

    filtered_targets = targets.to_a
    filtered_targets = dashboard_targets_for_month(filtered_targets, selected_month) if selected_month.present?
    filtered_targets = filter_weekly_activity_targets(
      filtered_targets,
      activity: selected_activity,
      sub_activity: selected_sub_activity,
      fcoc: selected_fcoc
    )

    all_rows = weekly_activity_target_farmer_status_rows(filtered_targets, month_name: selected_month, fcoc_name: selected_fcoc, week_number: selected_week)
    rows = all_rows
    rows = if selected_status.present?
      rows.select { |row| row[:status_class] == selected_status }
    elsif selected_status_key == "total"
      rows
    else
      []
    end

    @weekly_report_rows = rows
    @weekly_report_totals = weekly_activity_target_status_counts_for_rows(all_rows)
    @weekly_report_status = selected_status_key
    @weekly_selected_month = selected_month
    @weekly_selected_activity = selected_activity
    @weekly_selected_sub_activity = selected_sub_activity
    @weekly_selected_fcoc = selected_fcoc
    @weekly_selected_week = selected_week
    @weekly_month_options = dashboard_month_options_for_targets(targets)
    @weekly_activity_options = Array(targets).map(&:main_activity_name).uniq.compact_blank.sort
    @weekly_fcoc_options = Array(targets).filter_map { |target| target.vrp&.fcoc.to_s.strip.presence }.uniq.sort
    @weekly_sub_activity_options = Array(targets)
      .select { |target| selected_activity.blank? || normalize_dashboard_text(target.main_activity_name) == normalize_dashboard_text(selected_activity) }
      .map(&:activity_name)
      .uniq
      .compact_blank
      .sort

    respond_to do |format|
      format.html
      format.csv do
        week_suffix = selected_week.present? ? "-week-#{selected_week}" : "-all-weeks"
        send_data(
          weekly_activity_target_report_csv(@weekly_report_rows),
          filename: "weekly-activity-target-report#{week_suffix}-#{Time.current.strftime("%Y%m%d%H%M")}.csv",
          type: "text/csv"
        )
      end
      format.xlsx do
        week_suffix = selected_week.present? ? "-week-#{selected_week}" : "-all-weeks"
        send_xlsx(
          rows: weekly_activity_target_report_csv(@weekly_report_rows),
          filename: "weekly-activity-target-report#{week_suffix}-#{Time.current.strftime("%Y%m%d%H%M")}.xlsx",
          sheet_name: selected_week.present? ? "Week #{selected_week} Report" : "All Weeks Report"
        )
      end
    end
  end

  def ics_wise_farmer_report
    selected_month_value = params[:training_month].presence || params[:ics_report_month].presence || params[:month].presence
    selected_month = selected_month_value == "all" ? nil : selected_month_value
    selected_fcoc = params[:training_fcoc].presence || params[:participation_fcoc].presence || params[:fcoc].presence
    selected_fcoc = Array(params[:fco_id]).reject(&:blank?) if selected_fcoc.blank? && params[:fco_id].present?
    selected_main_activity = params[:main_activity].presence || params[:activity].presence
    selected_sub_activity = params[:training_sub_activity].presence || params[:sub_activity].presence
    selected_ics = params[:ics].presence || params[:ics_report_ics].presence

    targets = training_participation_targets_for_dashboard(
      month_name: selected_month,
      fcoc_name: selected_fcoc,
      main_activity_name: selected_main_activity,
      sub_activity_name: selected_sub_activity
    )
    records = selected_ics.present? ? dashboard_training_participation_records(month_name: selected_month, main_activity_name: selected_main_activity, sub_activity_name: selected_sub_activity, fcoc_name: selected_fcoc) : []

    @ics_report_month_options = dashboard_month_options_for_targets(dashboard_participation_targets)
    @ics_report_fcoc_options = @filter_fcoc_options || Array(dashboard_participation_targets).filter_map { |target| target.vrp&.fcoc.to_s.strip.presence }.uniq.sort
    @ics_report_options = ics_farmer_report_options([], targets)
    @ics_report_selected_month_value = selected_month_value.presence || "all"
    @ics_report_selected_month = selected_month
    @ics_report_selected_fcoc = selected_fcoc
    @ics_report_selected_ics = selected_ics
    @ics_report_rows = selected_ics.present? ? ics_farmer_report_rows(targets, records, selected_ics: selected_ics) : []
    @ics_report_summary = ics_farmer_report_summary(@ics_report_rows, selected_ics: selected_ics)

    respond_to do |format|
      format.html
      format.xlsx do
        send_xlsx(
          headers: ics_farmer_report_export_headers,
          rows: ics_farmer_report_export_rows(@ics_report_rows),
          filename: "ics-wise-farmer-report-#{Time.current.strftime("%Y%m%d%H%M")}.xlsx",
          sheet_name: "ICS Farmer Report"
        )
      end
    end
  end

  def vrp_dashboard_list
    redirect_to dashboard_path, alert: "VRP dashboard list is available only for VRP login." and return unless vrp_login_user?

    @vrp = current_vrp_record
    redirect_to dashboard_path, alert: "VRP record not found." and return unless @vrp

    mappings = vrp_dashboard_mappings(@vrp)
    targets = vrp_dashboard_targets(@vrp)
    targets = dashboard_targets_for_month(targets, params[:training_month]) if params[:training_month].present?
    targets = targets.select { |target| target.village_id.to_s == params[:village_id].to_s } if params[:village_id].present?
    bills = vrp_dashboard_bills(@vrp)
    @vrp_dashboard_detail = vrp_dashboard_detail_payload(params[:list_type], @vrp, mappings, targets, bills, params)

    respond_to do |format|
      format.html
      format.csv do
        export_payload = export_dashboard_detail_payload(@vrp_dashboard_detail, targets, bills)
        send_data(
          dashboard_detail_rows_csv(export_payload),
          filename: "#{export_payload[:key]}-#{Time.current.strftime("%Y%m%d%H%M")}.csv",
          type: "text/csv"
        )
      end
      format.xlsx do
        export_payload = export_dashboard_detail_payload(@vrp_dashboard_detail, targets, bills)
        send_xlsx(
          rows: dashboard_detail_rows_csv(export_payload),
          filename: "#{export_payload[:key]}-#{Time.current.strftime("%Y%m%d%H%M")}.xlsx",
          sheet_name: export_payload[:key].to_s.titleize
        )
      end
    end
  end

  def export_dashboard_detail_payload(detail, targets, bills)
    return detail unless detail.is_a?(Hash) && detail[:key].to_s == "pending_target"

    target_rows = vrp_dashboard_target_progress_rows(targets, bills)
    pending_rows = vrp_dashboard_pending_farmer_rows(target_rows)
    {
      key: "pending_farmers",
      title: "Pending Farmers",
      caption: detail[:caption],
      total: pending_rows.size,
      headers: vrp_target_farmer_headers,
      rows: pending_rows
    }
  end

  def destroy_vrp_mapped_village
    target = dashboard_vrp_target_scope&.find_by(id: params[:id])
    unless target
      redirect_back fallback_location: vrp_dashboard_list_path("mapped_villages"), alert: "Mapped village not found."
      return
    end

    dashboard_vrp_target_scope.where(village_id: target.village_id).destroy_all
    redirect_back fallback_location: vrp_dashboard_list_path("mapped_villages"), notice: "Mapped village deleted successfully."
  end

  def show
    load_module!
    redirect_to users_path and return if @slug == "all-user"
    redirect_to new_user_path and return if @slug == "new-user"

    @records = module_records_required_for_show? ? module_records : []
    @jeevika_bill_user_filters = !admin_dashboard_user? if @slug == "jeevika-jankar-bill-list"
    prepare_lg_directory_data if @slug == "lg-directory-list"
    prepare_vrp_bill_data if @slug == "vrp-bill-add"
    prepare_jeevika_jankar_bill_data if @slug == "jeevika-jankar-bill-process"
    prepare_jeevika_jankar_bill_list if @slug == "jeevika-jankar-bill-list"
  end

  def edit
    load_module!
    @record = ModuleRecord.find(params[:id])
    unless module_record_visible_for_current_context?(@record)
      redirect_to module_path(module_redirect_slug), alert: "You are not allowed to view this record."
      return
    end
    @records = module_records
    prepare_approval_channel_form(@record) if record_source_slug == "approval-master"
    prepare_vrp_bill_data if @slug == "vrp-bill-add"
    prepare_jeevika_jankar_bill_data if @slug == "jeevika-jankar-bill-process"
    render :show
  end

  def create
    load_module!

    if record_source_slug == "approval-master" && approval_channel_params?
      create_approval_channel
      return
    end

    record = ModuleRecord.new(
      module_slug: record_source_slug,
      data: normalized_module_data
    )

    data_errors = module_data_error_messages(record.data)
    if data_errors.any?
      @records = module_records_required_for_show? ? module_records : []
      prepare_jeevika_jankar_bill_data if @slug == "jeevika-jankar-bill-process"
      flash.now[:alert] = data_errors.to_sentence
      render :show, status: :unprocessable_entity
      return
    end

    if duplicate_access_control_record?(record.data)
      @records = module_records_required_for_show? ? module_records : []
      prepare_jeevika_jankar_bill_data if @slug == "jeevika-jankar-bill-process"
      flash.now[:alert] = "Access control for this stakeholder and role already exists."
      render :show, status: :unprocessable_entity
      return
    end

    if record.save
      sync_vrp_master_record(record)
      redirect_to module_path(module_redirect_slug), notice: "#{@module[:title]} saved successfully."
    else
      @records = module_records_required_for_show? ? module_records : []
      prepare_jeevika_jankar_bill_data if @slug == "jeevika-jankar-bill-process"
      flash.now[:alert] = record.errors.full_messages.to_sentence
      render :show, status: :unprocessable_entity
    end
  end

  def create_payment_detail
    load_module!
    unless @slug == "jeevika-jankar-payment-list-detail" && jeevika_jankar_payment_module_access?(@slug)
      redirect_to module_path(@slug), alert: "You are not allowed to submit payment details."
      return
    end

    raw_data = module_record_params.to_h
    selected_bill_ids = Array(raw_data["selected_bill_ids"]).map(&:to_s).map(&:strip).reject(&:blank?).uniq
    selected_records = ModuleRecord
      .where(module_slug: "jeevika-jankar-bill-process", id: selected_bill_ids)
      .index_by { |record| record.id.to_s }
      .values_at(*selected_bill_ids)
      .compact

    paid_ids = jeevika_paid_bill_ids
    selected_records = selected_records.select do |record|
      jeevika_bill_final_approved?(record) &&
        jeevika_jankar_bill_downloadable?(record) &&
        !paid_ids.include?(record.id.to_s)
    end

    data_errors = jeevika_payment_detail_error_messages(raw_data, selected_bill_ids, selected_records)
    if data_errors.any?
      redirect_to module_path("jeevika-jankar-payment-list-detail"), alert: data_errors.to_sentence
      return
    end

    ModuleRecord.create!(
      module_slug: JEEVIKA_JANKAR_PAYMENT_DETAIL_SLUG,
      data: normalized_jeevika_payment_detail_data(raw_data, selected_records)
    )

    sms_summary = send_jeevika_payment_advice_sms(raw_data, selected_records)
    notice = "Jeevika Jankar payment detail saved successfully."
    notice = "#{notice} #{sms_summary}" if sms_summary.present?

    redirect_to module_path("jeevika-jankar-payment-list-detail"), notice: notice
  end

  def update
    load_module!
    record = ModuleRecord.find(params[:id])
    unless module_record_visible_for_current_context?(record)
      redirect_to module_path(module_redirect_slug), alert: "You are not allowed to update this record."
      return
    end

    if record_source_slug == "approval-master" && approval_channel_params?
      update_approval_channel(record)
      return
    end

    previous_data = record.data.deep_dup

    # Dynamic farmer controls may omit a saved farmer after target mappings
    # change. Build an edit from the saved payload so details are retained.
    next_data = if record_source_slug == "training-form"
      normalized_module_data(base_data: record.data)
    else
      record.data.merge(normalized_module_data)
    end

    data_errors = module_data_error_messages(next_data)
    if data_errors.any?
      @record = record
      @records = module_records_required_for_show? ? module_records : []
      prepare_jeevika_jankar_bill_data if @slug == "jeevika-jankar-bill-process"
      flash.now[:alert] = data_errors.to_sentence
      render :show, status: :unprocessable_entity
      return
    end

    if duplicate_access_control_record?(next_data, except_id: record.id)
      @record = record
      @records = module_records_required_for_show? ? module_records : []
      prepare_jeevika_jankar_bill_data if @slug == "jeevika-jankar-bill-process"
      flash.now[:alert] = "Access control for this stakeholder and role already exists."
      render :show, status: :unprocessable_entity
      return
    end

    # Keep existing training evidence when an edit adds more files.
    next_data = preserve_training_uploads(record.data, next_data) if record_source_slug == "training-form"

    if record_source_slug == "training-form" && module_cluster_incharge_login? && !admin_dashboard_user?
      begin
        revision = TrainingEditApproval.submit!(record: record, proposed: next_data, actor: current_app_user)
        redirect_to module_path("training-form-list"), notice: "Training changes submitted for approval. #{TrainingEditApproval.status_label(revision)}."
      rescue TrainingEditApproval::InvalidTransition => error
        redirect_to module_path("training-form-list"), alert: error.message
      end
      return
    end

    if record.update(data: next_data)
      sync_stakeholder_name_change(previous_data, next_data)
      sync_vrp_master_record(record)
      redirect_to module_path(module_redirect_slug), notice: "#{@module[:title]} updated successfully."
    else
      @record = record
      @records = module_records_required_for_show? ? module_records : []
      prepare_jeevika_jankar_bill_data if @slug == "jeevika-jankar-bill-process"
      flash.now[:alert] = record.errors.full_messages.to_sentence
      render :show, status: :unprocessable_entity
    end
  end

  def destroy
    load_module!
    record = ModuleRecord.find(params[:id])
    unless module_record_visible_for_current_context?(record)
      redirect_to module_path(@slug), alert: "You are not allowed to delete this record.", status: :see_other
      return
    end
    record.destroy
    redirect_to module_path(@slug), notice: "#{@module[:title]} deleted successfully.", status: :see_other
  end

  def selected_farmers
    load_module!
    @record = ModuleRecord.find(params[:id])
    unless module_record_visible_for_current_context?(@record)
      redirect_to module_path(module_redirect_slug), alert: "You are not allowed to view this record."
      return
    end
    @selected_farmer_rows = selected_farmer_rows_for(@record)
  end

  def export_selected_farmers
    load_module!
    record = ModuleRecord.find(params[:id])
    unless module_record_visible_for_current_context?(record)
      redirect_to module_path(module_redirect_slug), alert: "You are not allowed to export this record."
      return
    end
    rows = selected_farmer_rows_for(record)

    send_xlsx(
      headers: ["Farmer ID", "Farmer Name", "Father Name", "Tracenet No", "Mobile No", "Khasara No"],
      rows: rows.map do |row|
        [
          row[:id],
          row[:farmer_name],
          row[:father_name],
          row[:tracenet_no],
          row[:mobile_no],
          row[:khasara_no]
        ]
      end,
      filename: "#{record.module_slug}_selected_farmers_#{record.id}_#{Date.current}.xlsx",
      sheet_name: "Selected Farmers"
    )
  end

  def selected_farmer
    load_module!
    record = ModuleRecord.find(params[:id])
    unless module_record_visible_for_current_context?(record)
      redirect_to module_path(module_redirect_slug), alert: "You are not allowed to update this record."
      return
    end
    farmer_id = params[:farmer_id].to_s
    selected_ids = Array(record.data["selected_farmer_ids"]).map(&:to_s).reject(&:blank?)
    next_ids = selected_ids - [farmer_id]
    next_data = record.data.merge(
      "selected_farmer_ids" => next_ids,
      "selected_farmer_names" => training_farmer_names(next_ids),
      "farmer_count" => next_ids.size.to_s
    )

    if record.update(data: next_data)
      redirect_to selected_farmers_module_record_path(@slug, record), notice: "Farmer removed successfully."
    else
      redirect_to selected_farmers_module_record_path(@slug, record), alert: record.errors.full_messages.to_sentence
    end
  end

  def toggle_status
    load_module!
    record = ModuleRecord.find(params[:id])
    current_status = record.data["status"].presence || "Active"
    next_status = current_status == "Active" ? "Inactive" : "Active"

    if record.update(data: record.data.merge("status" => next_status))
      sync_vrp_master_record(record)
    end
    redirect_to module_path(@slug), notice: "Status changed to #{next_status}."
  end

  def import
    load_module!
    if @slug == "lg-directory-list"
      result = LgDirectoryImporter.import(params[:file])
      counts = lg_directory_import_notice_counts(result[:counts])
      notice = "LG Directory uploaded successfully. #{result[:imported]} records created"
      notice = "#{notice} (#{counts})" if counts.present?
      redirect_to module_path(@slug), notice: "#{notice}."
      return
    end

    result = import_module_records(params[:file])
    redirect_to module_path(@slug), notice: "#{@module[:title]} uploaded successfully. #{result[:imported]} records created."
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_to module_path(@slug), alert: e.message
  end

  def export
    load_module!

    respond_to do |format|
      format.xlsx do
        if @slug == "lg-directory-list"
          prepare_lg_directory_data
          csv_data = lg_directory_csv(@lg_directory_rows)
          filename = "lg_directory_all_list_#{Date.current}.xlsx"
        else
          csv_data = module_records_csv(module_records)
          filename = "#{record_source_slug.tr("-", "_")}_records_#{Date.current}.xlsx"
        end

        send_xlsx rows: csv_data, filename: filename, sheet_name: @module[:title]
      end

      format.zip do
        unless @slug == "training-form-list"
          redirect_to module_path(@slug), alert: "Attachment download is available only for Training Form List." and return
        end

        send_data(
          module_records_attachments_zip(module_records),
          filename: "training_form_attachments_#{Time.current.strftime("%Y%m%d%H%M")}.zip",
          type: "application/zip"
        )
      end
    end
  end

  def training_target_farmers
    ids = Array(params[:target_mapping_ids].presence || params[:target_mapping_id])
      .flat_map { |value| value.to_s.split(",") }
      .map(&:strip)
      .reject(&:blank?)
      .uniq
    return render json: { farmers: [] } if ids.blank? || !model_ready?(:TargetMapping)

    targets = training_target_scope.where(id: ids).includes(:vrp).to_a
    farmer_ids = targets.flat_map { |target| target_farmer_ids(target) }.map(&:to_s).reject(&:blank?).uniq
    existing_ids = Array(params[:existing_farmer_ids]).flat_map { |value| value.to_s.split(",") }
      .map(&:strip).reject(&:blank?)
    farmer_ids |= existing_ids
    completed_ids = targets.flat_map { |target| completed_training_farmer_ids_for(target, target_farmer_ids(target)) }.map(&:to_s).uniq
    completed_lookup = completed_ids.index_with(true)

    farmers = training_farmers_for_ids(farmer_ids).map do |farmer|
      farmer.merge(already_included: completed_lookup.key?(farmer[:id].to_s))
    end

    render json: { farmers: farmers }
  end

  def jeevika_jankar_bill_target_rows
    return render json: { rows: [], achievement_summary: {}, target_summary: {} } unless current_slug == "jeevika-jankar-bill-process"

    rows = jeevika_jankar_bill_rows(
      vrp_id: params[:vrp_id].presence,
      month_name: params[:month].presence
    )

    render json: {
      rows: rows,
      achievement_summary: jeevika_jankar_achievement_summary(rows),
      target_summary: jeevika_jankar_target_summary_from_rows(rows)
    }
  end

  def seed_target_farmers
    return render json: { farmers: [], completed_farmer_ids: [] } unless model_ready?(:TargetMapping)

    target = training_target_scope.find_by(id: params[:target_mapping_id])
    return render json: { farmers: [], completed_farmer_ids: [] } unless target

    farmer_ids = target_farmer_ids(target)
    completed_ids = other_target_completed_farmer_ids_for(target.id)
    farmers = training_farmers_for_ids(farmer_ids)

    render json: {
      farmers: farmers,
      completed_farmer_ids: completed_ids
    }
  end

  def bulk_update
    load_module!
    redirect_to module_path(@slug), alert: "Bulk action is available only for LG Directory All List." and return unless @slug == "lg-directory-list"

    selected_records = lg_directory_selected_records
    redirect_to module_path(@slug), alert: "Please select at least one LG Directory row." and return if selected_records.blank?

    case params[:bulk_action]
    when "edit"
      redirect_to module_path(@slug), alert: "Please select one row only for edit." and return unless selected_records.one?

      edit_record = lg_directory_edit_record(selected_records.first)
      redirect_to module_path(@slug), alert: "This LG Directory row cannot be edited from All List." and return unless edit_record

      redirect_to edit_module_record_path(edit_record.module_slug, edit_record)
    when "active", "inactive"
      next_status = params[:bulk_action] == "active" ? "Active" : "Inactive"
      records_to_update = lg_directory_matching_records(selected_records)
      records_to_update.each { |record| record.update!(data: record.data.merge("status" => next_status)) }
      redirect_to module_path(@slug), notice: "#{selected_records.size} LG Directory row(s) marked #{next_status}."
    when "delete"
      records_to_delete = lg_directory_matching_records(selected_records)
      records_to_delete.each(&:destroy!)
      redirect_to module_path(@slug), notice: "#{selected_records.size} LG Directory row(s) deleted."
    else
      redirect_to module_path(@slug), alert: "Please choose a valid action."
    end
  end

  def set_status
    load_module!
    record = ModuleRecord.find(params[:id])
    next_status = params[:status].presence_in(["Active", "Inactive"]) || "Active"

    if record.update(data: record.data.merge("status" => next_status))
      sync_vrp_master_record(record)
      redirect_to module_path(@slug), notice: "Status changed to #{next_status}."
    else
      redirect_to module_path(@slug), alert: record.errors.full_messages.to_sentence
    end
  end

  def send_bill_for_approval
    load_module!
    record = ModuleRecord.find(params[:id])
    unless ["jeevika-jankar-bill-process", "jeevika-jankar-bill-list"].include?(record.module_slug) || record_source_slug == "jeevika-jankar-bill-process"
      redirect_to module_path(@slug), alert: "Send for approval is available only for Jeevika Jankar bills." and return
    end
    redirect_to module_path("jeevika-jankar-bill-list"), alert: "You are not allowed to view this bill." and return unless jeevika_jankar_bill_record_visible?(record)

    step = jeevika_bill_approval_steps(record).first
    redirect_to module_path("jeevika-jankar-bill-list"), alert: "Please create Jeevika Jankar Bill approval channel first." and return unless step

    update_bill_status!(record, "Pending at #{step.data["approver_approved_by"]}", current_sequence: approval_sequence_from_level(step.data["approval_level"]))
    create_bill_approval_history(record, "Sent for Approval", step)
    redirect_to module_path("jeevika-jankar-bill-list"), notice: "Jeevika Jankar bill sent for approval."
  end

  def set_bill_state
    load_module!
    record = ModuleRecord.find(params[:id])
    redirect_to module_path("jeevika-jankar-bill-list"), alert: "You are not allowed to update this bill." and return unless jeevika_jankar_bill_record_visible?(record)
    state = params[:state].presence_in(["Active", "Inactive"]) || "Active"
    record.update!(data: record.data.merge("record_state" => state))
    redirect_to module_path("jeevika-jankar-bill-list"), notice: "Bill marked #{state}."
  end

  def approve_bill
    update_bill_approval("Approved")
  end

  def reject_bill
    update_bill_approval("Rejected")
  end

  def return_bill
    update_bill_approval("Returned")
  end

  def download_bill
    load_module!
    @record = ModuleRecord.find(params[:id])
    redirect_to module_path("jeevika-jankar-bill-list"), alert: "You are not allowed to view this bill." and return unless jeevika_jankar_bill_downloadable?(@record)
    @bill_print_mode = true
    @records = []
    render :show, layout: "bill_print"
  end

  private

  def authorize_jeevika_payment_module_access
    payment_slugs = %w[
      jeevika-jankar-payment-list
      jeevika-jankar-payment-list-detail
      jeevika-jankar-completed-payment-list
    ]
    requested_slug = current_slug.to_s
    return unless payment_slugs.include?(requested_slug)
    return if jeevika_jankar_payment_module_access?(requested_slug)

    redirect_to dashboard_path, alert: "You are not allowed to access this menu."
  end

  def dashboard_filter_sub_activity_options(targets)
    month = params.key?(:month) ? dashboard_filter_param(:month) : Date.current.prev_month.strftime("%B")
    fcoc = dashboard_filter_param(:fcoc, :fco)
    fco_values = training_fcoc_filter_values(fcoc) if fcoc.present?
    ics = dashboard_filter_param(:ics, :ics_name)
    cluster = dashboard_filter_param(:cluster_incharge)
    vrp_id = dashboard_filter_param(:vrp_id)
    post = dashboard_filter_param(:post)
    Array(targets).select do |target|
      (month.blank? || normalize_dashboard_text(target.month_name) == normalize_dashboard_text(month)) &&
        (fco_values.blank? || (training_fcoc_filter_values(target.fco_name, target.fco_id, target.vrp&.fcoc) & fco_values).any?) &&
        (ics.blank? || (target.ics_name.presence || target.ics_id).to_s == ics) &&
        (cluster.blank? || cluster_label_matches?(cluster, target.vrp&.cluster_incharge)) &&
        (vrp_id.blank? || target.vrp_id.to_s == vrp_id) &&
        (post.blank? || target.vrp&.role.to_s == post)
    end.map(&:activity_name).uniq.compact_blank.sort
  end

  def dashboard_other_activity_totals(targets)
    @other_target_candidate_targets = Array(targets).uniq { |target| target.id }.select do |target|
      fco_id = target.fco_id.to_s.strip
      if fco_id.match?(/\A\d+\z/)
        %w[1004 1006].include?(fco_id)
      else
        [target.fco_name, fco_id].any? { |value| value.to_s.match?(/\b(?:sausar|turekela)\b/i) }
      end
    end
    return { target: 0, completed: 0, pending: 0 } if @other_target_candidate_targets.empty?

    @other_target_candidate_targets_by_id = @other_target_candidate_targets.index_by { |target| target.id.to_s }
    preload_training_farmers_for_targets!(@other_target_candidate_targets)
    # Reuse JJ completion evidence and assignment deduplication. Numeric-only
    # aggregation missed completed farmer submissions and repeated mappings.
    totals = { assigned: 0.0, achieved: 0.0, pending: 0.0 }
    @other_target_candidate_targets.group_by do |target|
      [target.month_name, target.main_activity_name, target.activity_name].map { |value| normalize_dashboard_text(value) }
    end.each_value do |activity_targets|
      rows = vrp_dashboard_target_progress_rows(activity_targets, [])
      farmer_rows, quantity_rows = rows.partition { |row| Array(row[:assigned_farmer_ids]).any? }
      assigned_ids = farmer_rows.flat_map { |row| Array(row[:assigned_farmer_ids]).map(&:to_s) }.uniq
      completed_ids = farmer_rows.flat_map { |row| Array(row[:completed_farmer_ids]).map(&:to_s) }.uniq & assigned_ids
      # Legacy numeric achievements have no individual farmer evidence. Keep
      # that quantity, once per identical assignment, capped at distinct farmers.
      numeric_completion = farmer_rows.group_by { |row| Array(row[:assigned_farmer_ids]).map(&:to_s).uniq.sort }.sum do |_ids, duplicates|
        duplicates.map { |row| [row[:completed].to_f - Array(row[:completed_farmer_ids]).map(&:to_s).uniq.size, 0].max }.max.to_f
      end
      quantities = vrp_dashboard_target_totals(quantity_rows)
      assigned = assigned_ids.size + quantities[:assigned]
      completed = [completed_ids.size + numeric_completion, assigned_ids.size].min + quantities[:achieved]
      totals[:assigned] += assigned
      totals[:achieved] += completed
      totals[:pending] += [assigned - completed, 0].max
    end
    { target: dashboard_quantity(totals[:assigned]), completed: dashboard_quantity(totals[:achieved]), pending: dashboard_quantity(totals[:pending]) }
  end

  def prepare_vrp_dashboard
    @vrp_dashboard = true
    @dashboard_generated_at = Time.current
    @vrp = current_vrp_record
    selected_sub_activity = dashboard_selected_training_sub_activity_name

    unless @vrp
      @dashboard_cards = []
      @vrp_target_rows = []
      @vrp_village_rows = []
      @vrp_farmer_followup = empty_vrp_farmer_followup
      return
    end

    mappings = vrp_dashboard_mappings(@vrp)
    targets = vrp_dashboard_targets(@vrp)
    @training_month_options = dashboard_month_options_for_targets(targets)
    selected_month = dashboard_selected_training_month_name.presence || default_vrp_dashboard_month(@training_month_options, targets)
    filtered_targets = dashboard_targets_for_month(targets, selected_month)
    @training_sub_activity_options = dashboard_sub_activity_options_for_targets(filtered_targets, selected_month)
    requested_sub_activity = dashboard_selected_training_sub_activity_name
    selected_sub_activity = @training_sub_activity_options.find do |option|
      normalize_dashboard_text(option) == normalize_dashboard_text(requested_sub_activity)
    end || @training_sub_activity_options.first
    training_targets = dashboard_targets_for_filters(targets, selected_month, selected_sub_activity)
    bills = vrp_dashboard_bills(@vrp)
    main_activity_count = filtered_targets.map { |target| normalize_dashboard_text(target.main_activity_name) }.reject(&:blank?).uniq.size
    sub_activity_count = filtered_targets.map { |target| normalize_dashboard_text(target.activity_name) }.reject(&:blank?).uniq.size
    target_total = filtered_targets.sum { |target| target.target_quantity.to_f }
    @vrp_village_rows = vrp_dashboard_village_rows(@vrp, mappings, filtered_targets)
    @training_selected_month = selected_month
    @training_selected_sub_activity = selected_sub_activity
    @participation_month_filter_value = params[:participation_month].presence || default_vrp_dashboard_month(@training_month_options, targets)
    @participation_selected_month = @participation_month_filter_value == "all" ? nil : @participation_month_filter_value
    @participation_fcoc_filter_value = params[:participation_fcoc].presence
    @participation_week_filter_value = params[:weekly_target_week].to_i if params[:weekly_target_week].present?
    @participation_week_filter_value = nil unless (1..4).include?(@participation_week_filter_value)
    participation_records = dashboard_training_participation_records(month_name: @participation_selected_month, fcoc_name: @participation_fcoc_filter_value)
    participation_records = participation_records.select { |record| training_record_week_number(record) == @participation_week_filter_value } if @participation_week_filter_value.present?
    participation_targets = training_participation_targets_for_dashboard(month_name: @participation_selected_month, fcoc_name: @participation_fcoc_filter_value)
    participation_targets = training_participation_targets_for_week(participation_targets, @participation_week_filter_value) if @participation_week_filter_value.present?
    participation_dashboard_counts = training_participation_dashboard_counts(
      month_name: @participation_selected_month,
      fcoc_name: @participation_fcoc_filter_value,
      records: participation_records,
      targets: participation_targets,
      week_number: @participation_week_filter_value
    )
    @training_participation_status_cards = training_participation_dashboard_status_cards(
      participation_dashboard_counts,
      month_name: @participation_selected_month,
      fcoc_name: @participation_fcoc_filter_value,
      week_number: @participation_week_filter_value
    )
    @training_registered_farmer_count = participation_dashboard_counts[:registered_farmer_total].to_i
    @training_unique_farmer_count = participation_dashboard_counts[:total]
    @training_mapped_farmer_count = participation_dashboard_counts[:total]
    @training_total_training_farmer_count = participation_dashboard_counts[:target_map_total].presence || training_total_farmer_count_from_records(participation_records)
    @training_completed_target_map_count = participation_dashboard_counts[:completed_target_map_total].to_i
    village_count = @vrp_village_rows.size
    mapped_village_farmer_count = vrp_dashboard_afl_farmer_rows_for_target_villages(filtered_targets).size
    preload_training_farmers_for_targets!(filtered_targets)
    @vrp_target_rows = vrp_dashboard_target_progress_rows(filtered_targets, bills)
    target_totals = vrp_dashboard_target_totals(@vrp_target_rows)
    assigned_target_total = target_totals[:assigned]
    achieved_target_total = target_totals[:achieved]
    pending_target_total = target_totals[:pending]
    month_caption = selected_month.presence || "selected month"

    @dashboard_cards = [
      dashboard_card("Mapped Villages", village_count, "Villages assigned in #{month_caption}", vrp_dashboard_list_path("mapped_villages", training_month: selected_month)),
      dashboard_card("Main Activities", main_activity_count, "Main activities mapped in #{month_caption}", vrp_dashboard_list_path("main_activities", training_month: selected_month)),
      dashboard_card("Sub Activities", sub_activity_count, "Sub activities mapped in #{month_caption}", vrp_dashboard_list_path("sub_activities", training_month: selected_month)),
      dashboard_card("Assigned Target", dashboard_quantity(assigned_target_total), "Target quantity assigned in #{month_caption}", vrp_dashboard_list_path("assigned_target", training_month: selected_month)),
      dashboard_card("Assigned Farmers", @vrp_target_rows.flat_map { |row| Array(row[:assigned_farmer_ids]) }.map(&:to_s).reject(&:blank?).uniq.size, "Unique farmers assigned in #{month_caption}", vrp_dashboard_list_path("mapped_farmers", training_month: selected_month)),
      dashboard_card("Achieved Target", dashboard_quantity(achieved_target_total), "Target completed in #{month_caption}", vrp_dashboard_list_path("achieved_target", training_month: selected_month)),
      dashboard_card("Pending Target", dashboard_quantity(pending_target_total), "Target pending in #{month_caption}", vrp_dashboard_list_path("pending_target", training_month: selected_month))
    ]
    @dashboard_summary_cards = vrp_dashboard_summary_cards(
      @vrp_target_rows,
      village_count: village_count,
      main_activity_count: main_activity_count,
      sub_activity_count: sub_activity_count,
      mapped_village_farmer_count: mapped_village_farmer_count,
      assigned_target_total: assigned_target_total,
      achieved_target_total: achieved_target_total,
      pending_target_total: pending_target_total,
      selected_month: selected_month
    )
    @vrp_farmer_followup = empty_vrp_farmer_followup
  end

  def vrp_login_user?
    current_app_user&.dig("record_type").to_s == "Vrp"
  end

  def current_vrp_record
    return unless model_ready?(:Vrp)

    return @current_vrp_record if defined?(@current_vrp_record)

    @current_vrp_record = begin
      user = current_app_user || {}
      id_values = [user["id"], user["vrp_id"]].compact_blank.map(&:to_s).select { |value| value.match?(/\A\d+\z/) }
      user_names = [user["username"], user["user_name"], user["name"]].compact_blank.map { |value| value.to_s.strip.downcase }.uniq
      mobile_values = [user["mobile_no"], user["mobile"], user["phone"]].compact_blank.map { |value| value.to_s.gsub(/\D/, "").last(10) }.reject(&:blank?).uniq
      email = user["email"].to_s.strip.downcase

      vrp = Vrp.where(id: id_values).first if vrp_login_user? && id_values.any?
      vrp ||= Vrp.where("LOWER(user_name) IN (?)", user_names).first if user_names.any? && Vrp.column_names.include?("user_name")
      vrp ||= Vrp.where(mobile_no: mobile_values).first if mobile_values.any? && Vrp.column_names.include?("mobile_no")
      vrp ||= Vrp.where("LOWER(email) = ?", email).first if email.present? && Vrp.column_names.include?("email")
      vrp ||= Vrp.where(id: id_values).first if vrp.blank? && id_values.any?
      vrp
    end
  end

  def vrp_dashboard_mappings(vrp)
    return [] unless model_ready?(:VrpIcsMapping)

    VrpIcsMapping.where(vrp_id: vrp.id).order(:village_name, :id).to_a
  end

  def dashboard_vrp_target_scope
    klass = "TargetMapping".safe_constantize
    return unless klass&.table_exists?

    vrp = current_vrp_record
    return klass.none unless vrp

    klass.includes(:vrp).where(vrp_id: vrp.id)
  end

  def module_record_label_for_dashboard(module_slug, id, field_key)
    return "" if id.blank? || !model_ready?(:ModuleRecord)

    @module_record_label_cache ||= {}
    cache_key = [module_slug.to_s, id.to_s, field_key.to_s]
    return @module_record_label_cache[cache_key] if @module_record_label_cache.key?(cache_key)

    record = ModuleRecord.find_by(module_slug: module_slug, id: id)
    label = module_record_display_label_for_dashboard(module_slug, record, field_key)
    label = id.to_s.match?(/\A\d+\z/) ? "" : id.to_s if label.blank?

    @module_record_label_cache[cache_key] = label
  end

  def module_record_labels_for_dashboard(module_slug, ids, field_key)
    Array(ids)
      .filter_map { |id| module_record_label_for_dashboard(module_slug, id, field_key).presence }
      .join(", ")
  end

  def module_record_display_label_for_dashboard(module_slug, record, field_key)
    return "" unless record

    case module_slug
    when "gram-panchayat-master"
      gram_panchayat_name_from_record(record)
    when "village-master"
      first_present_data(record, "village_name", "village", "name")
    else
      Array(field_key).filter_map { |key| record.data[key].presence }.first
    end.to_s
  end

  def gram_panchayat_label_for_village(village_id)
    return "" if village_id.blank? || !model_ready?(:ModuleRecord)

    village_record = ModuleRecord.find_by(module_slug: "village-master", id: village_id)
    return "" unless village_record

    gram_panchayat = first_non_code_data(village_record, "gram_panchayat_name", "gram_panchayat", "gp_name", "gram_name", "gp_code", "gram_code")
    return module_record_label_for_dashboard("gram-panchayat-master", gram_panchayat, "gram_panchayat_name") if gram_panchayat.to_s.match?(/\A\d+\z/)

    gram_panchayat.to_s
  end

  def vrp_dashboard_village_rows(_vrp, _mappings, targets)
    Array(targets).group_by { |target| dashboard_target_village_key(target) }.filter_map do |_village_key, village_targets|
      target = village_targets.first
      next unless target

      farmer_ids = village_targets.flat_map { |row| row.respond_to?(:afl_ids) ? Array(row.afl_ids).map(&:to_s) : [] }.reject(&:blank?).uniq
      village_id = target.village_id.to_s
      village = target.village_name.presence || module_record_label_for_dashboard("village-master", village_id, "village_name")

      {
        mapping_id: target.id,
        village_id: village_id,
        fco: village_targets.filter_map { |row| row.fco_name.presence || row.fco_id.presence }.uniq.join(", ").presence || "-",
        gram_panchayat: gram_panchayat_label_for_village(village_id),
        village: village.presence || village_id,
        farmers: farmer_ids.any? ? farmer_ids.size : village_targets.sum { |row| row.farmer_count.to_i },
        targets: village_targets.size,
        target_quantity: village_targets.sum { |row| row.target_quantity.to_f }
      }
    end
  end

  def dashboard_target_village_key(target)
    village_id = target.village_id.to_s
    return "id:#{village_id}" if village_id.present?

    "name:#{normalize_dashboard_text(target.village_name)}"
  end

  def vrp_dashboard_targets(vrp)
    return [] unless model_ready?(:TargetMapping)

    targets = TargetMapping.includes(:vrp).where(vrp_id: vrp.id).order(Arel.sql("completion_date ASC NULLS LAST"), :month_name, :main_activity_name, :activity_name, :id).to_a
    @training_record_target_mapping_cache ||= {}
    targets.each { |target| @training_record_target_mapping_cache[target.id.to_s] = target }
    targets
  end

  def vrp_dashboard_bills(vrp)
    return [] unless model_ready?(:ModuleRecord)

    labels = vrp_bill_match_labels(vrp)
    # Progress is calculated for many JJs in one dashboard request. Load and
    # normalize the bill rows once, retaining the original database ordering.
    @vrp_dashboard_bills_by_label ||= begin
      index = Hash.new { |hash, key| hash[key] = [] }
      ModuleRecord.where(module_slug: "vrp-bill-add").order(created_at: :desc).each_with_index do |record, position|
        index[normalize_dashboard_text(record.data["select_vrp"])] << [position, record]
      end
      index
    end
    labels.flat_map { |label| @vrp_dashboard_bills_by_label.fetch(label, []) }
      .sort_by(&:first).map(&:last)
  end

  def vrp_bill_match_labels(vrp)
    [
      vrp.id,
      vrp.name,
      vrp.user_name,
      vrp.mobile_no,
      [vrp.name, vrp.mobile_no.presence].compact_blank.join(" - ")
    ].map { |value| normalize_dashboard_text(value) }.reject(&:blank?).uniq
  end

  def vrp_mapped_farmer_count(mappings)
    direct_farmer_ids = mappings.flat_map { |mapping| Array(mapping.afl_ids).map(&:to_s) }.reject(&:blank?).uniq
    return direct_farmer_ids.size unless model_ready?(:Afl)

    fallback_farmer_ids = mappings.each_with_object([]) do |mapping, ids|
      next if Array(mapping.afl_ids).any?

      ids.concat(vrp_mapping_afl_ids(mapping))
    end

    (direct_farmer_ids | fallback_farmer_ids.map(&:to_s)).size
  end

  def vrp_afl_farmer_count(mappings, targets: [], vrps: [])
    return 0 unless model_ready?(:Afl)

    fco_ids = Array(targets).filter_map { |target| target.fco_id.to_s.strip.presence }.uniq
    fco_names = (
      Array(targets).filter_map { |target| target.fco_name.to_s.strip.presence } +
      Array(vrps).filter_map { |vrp| vrp.fcoc.to_s.strip.presence }
    ).uniq
    ics_values = Array(mappings).filter_map { |mapping| mapping.ics_name.presence || mapping.ics_id.presence }.uniq

    scope = Afl.all
    scope = vrp_filter_afl_mapping_scope(scope, :fco_id, :fco, fco_ids, fco_names) if fco_ids.any? || fco_names.any?
    scope = vrp_filter_afl_mapping_scope(scope, :ics_id, :ics_name, ics_values, ics_values) if params[:ics].present? && ics_values.any?

    rows = scope.distinct.pluck(:id, :tracenet_no)
    rows.map do |id, tracenet_no|
      tracenet = dashboard_text_value(tracenet_no)
      tracenet.present? && tracenet.casecmp("NULL") != 0 ? "tracenet:#{tracenet}" : "afl:#{id}"
    end.uniq.size
  end

  def vrp_mapping_afl_ids(mapping)
    return [] unless mapping

    scope = Afl.all
    scope = vrp_filter_afl_mapping_scope(scope, :fco_id, :fco, mapping.fco_id, mapping.fco_name)
    scope = vrp_filter_afl_mapping_scope(scope, :ics_id, :ics_name, mapping.ics_id, mapping.ics_name)
    scope = vrp_filter_afl_mapping_scope(scope, :village_id, :village_name, mapping.village_id, mapping.village_name)
    scope.distinct.pluck(:id).map(&:to_s)
  end

  def vrp_filter_afl_mapping_scope(scope, id_column, name_column, id_value, name_value)
    id_values = vrp_dashboard_location_values(id_value).map { |value| normalize_dashboard_text(value) }.reject(&:blank?).uniq
    label_values = vrp_dashboard_location_values(name_value).map { |value| normalize_dashboard_text(value) }.reject(&:blank?).uniq
    return scope.none if id_values.blank? && label_values.blank?

    conditions = []
    bind_values = {}

    if id_values.any?
      conditions << "LOWER(BTRIM(COALESCE(#{Afl.connection.quote_column_name(id_column)}::text, ''))) IN (:ids)"
      bind_values[:ids] = id_values
    end

    if label_values.any?
      conditions << "LOWER(BTRIM(COALESCE(#{Afl.connection.quote_column_name(name_column)}, ''))) IN (:labels)"
      bind_values[:labels] = label_values
    end

    scope.where(conditions.join(" OR "), bind_values)
  end

  def vrp_dashboard_location_values(value)
    Array(value).flat_map do |item|
      text = item.to_s.strip
      next [] if text.blank?

      parsed = begin
        JSON.parse(text) if text.start_with?("[")
      rescue JSON::ParserError
        nil
      end

      parsed.is_a?(Array) ? parsed : text.split(",")
    end.map { |item| item.to_s.strip }.reject(&:blank?)
  end

  def vrp_targeted_farmer_ids(targets)
    targets.flat_map { |target| target.respond_to?(:afl_ids) ? Array(target.afl_ids).map(&:to_s) : [] }.reject(&:blank?).uniq
  end

  def vrp_dashboard_target_progress_rows(targets, bills)
    activity_settings = jeevika_jankar_main_activity_settings
    sub_activity_settings = jeevika_jankar_sub_activity_settings(activity_settings)
    other_target_achievement_index = approved_other_target_achievement_index
    group_key_counts = dashboard_target_mapping_group_key_counts(targets)
    training_participation_existing_farmer_id_set(targets)

    raw_rows = Array(targets).map do |target|
      assigned_farmer_ids = target_farmer_ids(target)
      completed_farmer_ids = vrp_dashboard_completed_farmer_ids_for_target(target) & assigned_farmer_ids
      activity_setting = jeevika_jankar_activity_setting_for(target, activity_settings, sub_activity_settings)
      other_completion = other_target_achievement_index[target.id.to_s]
      training_completion = other_completion.blank? && (activity_setting.blank? || training_main_activity_type?(activity_setting[:main_activity_type]))
      completion_uses_farmer_ids = training_completion || (other_completion.blank? && completed_farmer_ids.any?)
      target_quantity = target.target_quantity.to_f
      effective_target = assigned_farmer_ids.any? ? assigned_farmer_ids.size.to_f : target_quantity
      completed = if training_completion && assigned_farmer_ids.any?
        completed_farmer_ids.size.to_f
      else
        vrp_target_completed_quantity(
          target,
          bills,
          activity_settings: activity_settings,
          sub_activity_settings: sub_activity_settings,
          other_target_achievement_index: other_target_achievement_index
        )
      end
      completed = [completed.to_f, effective_target].min
      pending = [effective_target - completed, 0].max
      week_targets = target.respond_to?(:weekly_target_values) ? target.weekly_target_values : [0, 0, 0, 0]
      weekly_completed_farmer_ids = training_weekly_achievement_farmer_ids(target, assigned_farmer_ids)

      {
        month: target.month_name,
        completion_date: target.completion_date&.strftime("%d-%m-%Y") || "-",
        completion_date_sort: target.completion_date,
        fco: target.fco_name.presence || target.fco_id,
        ics: target.ics_name.presence || target.ics_id,
        village: target.village_name.presence || target.village_id,
        farmers: assigned_farmer_ids.any? ? assigned_farmer_ids.size : target.farmer_count,
        main_activity: target.main_activity_name,
        activity: target.activity_name,
        target_mapping_id: target.id.to_s,
        target_record: target,
        assigned_farmer_ids: assigned_farmer_ids,
        completed_farmer_ids: completed_farmer_ids,
        weekly_completed_farmer_ids: weekly_completed_farmer_ids,
        training_completion: training_completion,
        completion_uses_farmer_ids: completion_uses_farmer_ids,
        target: effective_target,
        week_1: week_targets[0],
        week_2: week_targets[1],
        week_3: week_targets[2],
        week_4: week_targets[3],
        week_1_achieved: Array(weekly_completed_farmer_ids[0]).size,
        week_2_achieved: Array(weekly_completed_farmer_ids[1]).size,
        week_3_achieved: Array(weekly_completed_farmer_ids[2]).size,
        week_4_achieved: Array(weekly_completed_farmer_ids[3]).size,
        opg_training: target.opg_training_target,
        general_training: target.week_wise_opg_target,
        input_demo_inm: target.input_demo_inm_target,
        input_demo_pm: target.input_demo_pm_target,
        ffs: target.ffs_target,
        completed: completed,
        pending: pending,
        progress: percentage(completed, effective_target)
      }
    end

    raw_rows.group_by do |row|
      row[:target_record].present? ? dashboard_target_assignment_key(row[:target_record], group_key_counts) : row[:target_mapping_id]
    end.values.map do |rows|
      first = rows.first
      main_activities = rows.map { |row| row[:main_activity].to_s.strip }.reject(&:blank?).uniq
      sub_activities = rows.map { |row| row[:activity].to_s.strip }.reject(&:blank?).uniq
      effective_target = first[:target].to_f
      assigned_farmer_ids = rows.flat_map { |row| Array(row[:assigned_farmer_ids]).map(&:to_s) }.reject(&:blank?).uniq
      weekly_completed_farmer_ids = 4.times.map do |index|
        unique_training_farmer_ids(rows.flat_map { |row| Array(row[:weekly_completed_farmer_ids])[index] || [] }) & assigned_farmer_ids
      end
      training_completion_rows = rows.select { |row| row[:training_completion] }
      farmer_completion_rows = training_completion_rows.presence || rows.select { |row| row[:completion_uses_farmer_ids] }
      completed_farmer_ids = unique_training_farmer_ids(
        farmer_completion_rows.flat_map { |row| Array(row[:completed_farmer_ids]) }
      ) & assigned_farmer_ids
      training_targets = training_completion_rows.filter_map { |row| row[:target_record] }
      training_form_total = dashboard_training_form_total_farmer_count(training_targets, assigned_farmer_ids)
      training_form_farmer_ids = dashboard_training_form_completed_farmer_ids(training_targets, assigned_farmer_ids)
      completed_farmer_ids = training_form_farmer_ids if training_targets.any?
      completed_total = if training_targets.any?
        training_form_total
      elsif assigned_farmer_ids.any? && farmer_completion_rows.any?
        completed_farmer_ids.size.to_f
      else
        # Combined activity rows represent one mapped target. Without farmer IDs,
        # use the greatest achieved value instead of multiplying it per activity.
        rows.map { |row| row[:completed].to_f }.max.to_f
      end
      # A grouped assignment can also have a quantity-based Other Target entry.
      other_completed = rows.reject { |row| row[:training_completion] }.map { |row| row[:completed].to_f }.max.to_f
      completed_total = [[completed_total, other_completed].max, effective_target].min

      first.merge(
        main_activity: main_activities.join("\n"),
        activity: sub_activities.join("\n"),
        main_activities: main_activities,
        sub_activities: sub_activities,
        target_mapping_ids: rows.map { |row| row[:target_mapping_id].to_s }.reject(&:blank?).uniq,
        assigned_farmer_ids: assigned_farmer_ids,
        completed_farmer_ids: completed_farmer_ids,
        week_1: rows.map { |row| row[:week_1].to_f }.max,
        week_2: rows.map { |row| row[:week_2].to_f }.max,
        week_3: rows.map { |row| row[:week_3].to_f }.max,
        week_4: rows.map { |row| row[:week_4].to_f }.max,
        week_1_achieved: weekly_completed_farmer_ids[0].size,
        week_2_achieved: weekly_completed_farmer_ids[1].size,
        week_3_achieved: weekly_completed_farmer_ids[2].size,
        week_4_achieved: weekly_completed_farmer_ids[3].size,
        opg_training: rows.map { |row| row[:opg_training].to_f }.max,
        general_training: rows.map { |row| row[:general_training].to_f }.max,
        input_demo_inm: rows.map { |row| row[:input_demo_inm].to_f }.max,
        input_demo_pm: rows.map { |row| row[:input_demo_pm].to_f }.max,
        ffs: rows.map { |row| row[:ffs].to_f }.max,
        completed: completed_total,
        pending: [effective_target - completed_total, 0].max,
        progress: percentage(completed_total, effective_target)
      )
    end.sort_by do |row|
      [
        dashboard_month_index(row[:month]),
        row[:completion_date_sort] || Date.new(1900, 1, 1),
        row[:fco].to_s,
        row[:village].to_s
      ]
    end
  end

  # Mapped Farmers is a distinct headcount, but target progress is activity-wise.
  # A farmer assigned to two different activities contributes once to each
  # activity target, so these totals must remain additive across dashboard rows.
  def vrp_dashboard_target_totals(rows)
    rows = Array(rows)
    assigned = rows.sum { |row| row[:target].to_f }
    achieved = rows.sum { |row| row[:completed].to_f }
    achieved = [achieved, assigned].min

    { assigned: assigned, achieved: achieved, pending: [assigned - achieved, 0].max }
  end

  def vrp_dashboard_farmer_status_totals(rows)
    sets = vrp_dashboard_farmer_status_sets(rows)
    sets.transform_values(&:size)
  end

  def vrp_dashboard_farmer_status_sets(rows)
    farmer_states = Hash.new { |hash, farmer_id| hash[farmer_id] = { complete: 0, pending: 0 } }

    Array(rows).each do |row|
      assigned_ids = Array(row[:assigned_farmer_ids]).map(&:to_s).reject(&:blank?).uniq
      completed_ids = Array(row[:completed_farmer_ids]).map(&:to_s).reject(&:blank?).to_set

      assigned_ids.each do |farmer_id|
        state = farmer_states[farmer_id]
        if completed_ids.include?(farmer_id)
          state[:complete] += 1
        else
          state[:pending] += 1
        end
      end
    end

    {
      mapped: farmer_states.keys,
      pending: farmer_states.filter_map { |farmer_id, state| farmer_id if state[:pending].positive? },
      complete: farmer_states.filter_map { |farmer_id, state| farmer_id if state[:complete].positive? },
      red: farmer_states.filter_map { |farmer_id, state| farmer_id if state[:pending].positive? && state[:complete].zero? },
      green: farmer_states.filter_map { |farmer_id, state| farmer_id if state[:complete].positive? && state[:pending].zero? },
      yellow: farmer_states.filter_map { |farmer_id, state| farmer_id if state[:complete].positive? && state[:pending].positive? }
    }
  end

  def vrp_dashboard_summary_cards(rows, village_count:, main_activity_count:, sub_activity_count:, mapped_village_farmer_count:, assigned_target_total:, achieved_target_total:, pending_target_total:, selected_month:)
    status_sets = vrp_dashboard_farmer_status_sets(rows)
    mapped_farmer_count = status_sets[:mapped].size
    month_params = { training_month: selected_month }.compact_blank

    [
      dashboard_card("Total Mapped Villages", village_count, "Filtered mapped villages", vrp_dashboard_list_path("mapped_villages", month_params)),
      dashboard_card("Mapped Farmer", mapped_village_farmer_count, "AFL farmers in filtered mapped villages", vrp_dashboard_list_path("mapped_village_farmers", month_params)),
      dashboard_card("Targeted Farmers", mapped_farmer_count, "Unique targeted farmers", vrp_dashboard_list_path("mapped_farmers", month_params)),
      dashboard_card("Total Mapped Main Activities", main_activity_count, "Filtered main activities", vrp_dashboard_list_path("main_activities", month_params)),
      dashboard_card("Total Mapped Sub-Activities", sub_activity_count, "Filtered sub-activities", vrp_dashboard_list_path("sub_activities", month_params))
    ]
  end

  def vrp_dashboard_completed_farmer_count(status_sets)
    (Array(status_sets[:green]) + Array(status_sets[:yellow])).uniq.size
  end

  def vrp_dashboard_pending_farmer_count(status_sets)
    (Array(status_sets[:red]) + Array(status_sets[:yellow])).uniq.size
  end

  def vrp_activity_overview_totals(targets, bills: [])
    rows = vrp_dashboard_target_progress_rows(targets, bills)
    farmer_states = Hash.new { |hash, farmer_id| hash[farmer_id] = { complete: 0, pending: 0 } }
    target_map = Array(rows).sum { |row| Array(row[:assigned_farmer_ids]).map(&:to_s).reject(&:blank?).size.nonzero? || row[:target].to_f }
    completed_target_map = Array(rows).sum do |row|
      assigned_ids = Array(row[:assigned_farmer_ids]).map(&:to_s).reject(&:blank?)
      completed_ids = Array(row[:completed_farmer_ids]).map(&:to_s).reject(&:blank?)
      assigned_ids.any? ? completed_ids.size.to_f : row[:completed].to_f
    end

    Array(rows).each do |row|
      assigned_ids = Array(row[:assigned_farmer_ids]).map(&:to_s).reject(&:blank?).uniq
      completed_ids = Array(row[:completed_farmer_ids]).map(&:to_s).reject(&:blank?).uniq.to_set

      assigned_ids.each do |farmer_id|
        state = farmer_states[farmer_id]
        if completed_ids.include?(farmer_id)
          state[:complete] += 1
        else
          state[:pending] += 1
        end
      end
    end

    {
      mapped_farmers: farmer_states.keys.size,
      target_map: target_map,
      pending_farmers: farmer_states.count { |_farmer_id, state| state[:pending].positive? },
      complete_farmers: farmer_states.count { |_farmer_id, state| state[:complete].positive? },
      pending_target_map: [target_map - completed_target_map, 0].max,
      completed_target_map: completed_target_map,
      red_farmers: farmer_states.count { |_farmer_id, state| state[:pending].positive? && state[:complete].zero? },
      green_farmers: farmer_states.count { |_farmer_id, state| state[:complete].positive? && state[:pending].zero? },
      yellow_farmers: farmer_states.count { |_farmer_id, state| state[:complete].positive? && state[:pending].positive? } + farmer_states.count { |_farmer_id, state| state[:pending] > 1 && state[:complete].zero? }
    }
  end

  # A farmer can occur in multiple target rows (for different activities).
  # Keep one state per farmer so the activity overview always reports distinct
  # farmers for both an individual month and the "All" month selection.
  def activity_overview_farmer_totals(target_rows)
    farmer_states = Hash.new { |hash, farmer_id| hash[farmer_id] = { completed: false, pending: false } }
    target_map = 0
    completed_target_map = 0
    pending_target_map = 0
    farmer_key_lookup = training_farmer_status_key_lookup(Array(target_rows).flat_map do |row|
      Array(row[:assigned_farmer_ids]) + Array(row[:completed_farmer_ids])
    end)

    Array(target_rows).each do |row|
      assigned_ids = unique_training_farmer_ids(row[:assigned_farmer_ids])
      completed_ids = unique_training_farmer_ids(row[:completed_farmer_ids])
      assigned_keys = assigned_ids.map { |farmer_id| farmer_key_lookup[farmer_id.to_s] || farmer_id.to_s }.reject(&:blank?).uniq
      completed_keys = completed_ids.map { |farmer_id| farmer_key_lookup[farmer_id.to_s] || farmer_id.to_s }.reject(&:blank?).uniq.to_set

      assigned_keys.each do |farmer_key|
        state = farmer_states[farmer_key]
        if completed_keys.include?(farmer_key)
          state[:completed] = true
          completed_target_map += 1
        else
          state[:pending] = true
          pending_target_map += 1
        end
        target_map += 1
      end
    end

    {
      mapped_farmers: farmer_states.size,
      target_map: target_map,
      pending_target_map: pending_target_map,
      completed_target_map: completed_target_map,
      pending_farmers: farmer_states.count { |_farmer_id, state| state[:pending] },
      complete_farmers: farmer_states.count { |_farmer_id, state| state[:completed] },
      red_farmers: farmer_states.count { |_farmer_id, state| state[:pending] && !state[:completed] },
      green_farmers: farmer_states.count { |_farmer_id, state| state[:completed] && !state[:pending] },
      yellow_farmers: farmer_states.count { |_farmer_id, state| state[:completed] && state[:pending] }
    }
  end

  def training_farmer_status_key_lookup(farmer_ids)
    farmer_ids = Array(farmer_ids).map(&:to_s).reject(&:blank?).uniq
    return {} if farmer_ids.blank?

    tracenet_by_id = model_ready?(:Afl) ? Afl.where(id: farmer_ids).pluck(:id, :tracenet_no).to_h : {}
    farmer_ids.index_with do |farmer_id|
      tracenet = tracenet_by_id[farmer_id.to_i].presence || tracenet_by_id[farmer_id].presence
      normalized_tracenet = dashboard_text_value(tracenet)
      normalized_tracenet.present? && normalized_tracenet.casecmp("NULL") != 0 ? "tracenet:#{normalized_tracenet}" : "afl:#{farmer_id}"
    end
  end

  def activity_overview_afl_master_count(targets)
    return 0 unless model_ready?(:Afl)

    targets = Array(targets)
    return Afl.distinct.count(:id) if targets.blank?

    fco_ids = targets.filter_map { |target| target.fco_id.to_s.strip.presence }.uniq
    fco_names = targets.filter_map { |target| target.fco_name.to_s.strip.presence }.uniq
    ics_ids = targets.filter_map { |target| target.ics_id.to_s.strip.presence }.uniq
    ics_names = targets.filter_map { |target| target.ics_name.to_s.strip.presence }.uniq
    village_ids = targets.filter_map { |target| target.village_id.to_s.strip.presence }.uniq
    village_names = targets.filter_map { |target| target.village_name.to_s.strip.presence }.uniq

    scope = Afl.all
    scope = vrp_filter_afl_mapping_scope(scope, :fco_id, :fco, fco_ids, fco_names) if fco_ids.any? || fco_names.any?
    scope = vrp_filter_afl_mapping_scope(scope, :ics_id, :ics_name, ics_ids, ics_names) if ics_ids.any? || ics_names.any?
    scope = vrp_filter_afl_mapping_scope(scope, :village_id, :village_name, village_ids, village_names) if village_ids.any? || village_names.any?
    scope.distinct.count(:id)
  end

  def activity_overview_farmer_path_params(status:)
    {
      status: status,
      training_month: @activity_overview_selected_month.presence,
      training_fcoc: @activity_overview_fcoc_filter_value.presence
    }.compact_blank
  end

  def dashboard_training_form_total_farmer_count(targets, assigned_farmer_ids)
    assigned_farmer_ids = Array(assigned_farmer_ids).map(&:to_s).reject(&:blank?).uniq
    records = dashboard_training_form_records(targets, assigned_farmer_ids)
    completed_farmer_ids = dashboard_training_form_completed_farmer_ids(targets, assigned_farmer_ids)
    return completed_farmer_ids.size.to_f if completed_farmer_ids.any?

    # Legacy forms may have only the saved total and no farmer-id array. A
    # combined activity form is one training event, so never add the same
    # farmer total once per activity/topic.
    records.map { |record| dashboard_numeric(record.data["total_farmer_count"]) }.max.to_f
  end

  def dashboard_training_form_completed_farmer_ids(targets, assigned_farmer_ids)
    assigned_farmer_ids = Array(assigned_farmer_ids).map(&:to_s).reject(&:blank?).uniq
    completed_ids = dashboard_training_form_all_completed_farmer_ids(targets)
    completed_ids & assigned_farmer_ids
  end

  def dashboard_training_form_all_completed_farmer_ids(targets)
    targets = Array(targets)
    return [] if targets.blank?

    month_name = normalize_dashboard_text(targets.first.month_name)
    vrp_id = targets.first.vrp_id.to_s
    target_ids = targets.map { |target| target.id.to_s }.reject(&:blank?).sort
    @dashboard_training_form_farmer_ids_by_scope ||= {}
    cache_key = [month_name, vrp_id, target_ids]
    @dashboard_training_form_farmer_ids_by_scope[cache_key] ||= dashboard_training_form_records_for_targets(targets)
      .flat_map { |record| training_record_selected_farmer_ids(record) }
      .uniq
  end

  def dashboard_training_form_records(targets, assigned_farmer_ids)
    targets = Array(targets)
    assigned_farmer_ids = Array(assigned_farmer_ids).map(&:to_s).reject(&:blank?).uniq
    return [] if targets.blank?

    month_name = targets.first.month_name
    vrp = targets.first.vrp
    @dashboard_training_form_records_by_scope ||= {}
    cache_key = [normalize_dashboard_text(month_name), targets.first.vrp_id.to_s, assigned_farmer_ids.sort.join(",")]

    @dashboard_training_form_records_by_scope[cache_key] ||= dashboard_training_form_records_for_month(month_name, farmer_ids: assigned_farmer_ids)
      .select do |record|
        (training_record_selected_farmer_ids(record) & assigned_farmer_ids).any? &&
          training_record_vrp_scope_matches?(record, vrp)
      end
      .uniq(&:id)
  end

  def dashboard_training_form_records_for_targets(targets)
    targets = Array(targets)
    return [] if targets.blank?

    targets.group_by { |target| normalize_dashboard_text(target.month_name) }.flat_map do |_month, month_targets|
      farmer_ids = month_targets.flat_map { |target| target_farmer_ids(target) }.map(&:to_s).reject(&:blank?).uniq
      month_targets.flat_map do |target|
        assigned_ids = target_farmer_ids(target)
        candidate_records = dashboard_training_form_records_for_month(target.month_name, farmer_ids: assigned_ids.presence || farmer_ids)
        candidate_records.select { |record| training_record_matches_dashboard_target?(record, target, assigned_ids) }
      end
    end.uniq(&:id)
  end

  def dashboard_training_form_records_for_month(month_name, farmer_ids: nil)
    month = normalize_dashboard_text(month_name)
    farmer_ids = Array(farmer_ids).map(&:to_s).reject(&:blank?).uniq
    records = dashboard_training_form_records_by_month(month)
    return records if farmer_ids.blank?

    record_ids = farmer_ids.flat_map { |farmer_id| dashboard_training_form_record_ids_by_farmer_for_month(month)[farmer_id] }.compact.uniq
    return [] if record_ids.blank?

    @dashboard_training_form_records_index_by_month ||= {}
    records_by_id = @dashboard_training_form_records_index_by_month[month] ||= records.index_by(&:id)
    record_ids.filter_map { |record_id| records_by_id[record_id] }
  end

  def dashboard_training_form_records_by_month(month)
    @dashboard_training_form_records_by_month ||= {}
    return @dashboard_training_form_records_by_month[month] if @dashboard_training_form_records_by_month.key?(month)

    scope = active_module_records_scope("training-form").order(created_at: :desc)
    scope = scope.where("LOWER(BTRIM(data::jsonb ->> 'month')) = ?", month) if month.present?
    records = scope.select { |record| training_record_countable?(record) }
    preload_training_target_mappings_for_records!(records)
    @dashboard_training_form_records_by_month[month] = records
  end

  def dashboard_training_form_record_ids_by_farmer_for_month(month)
    @dashboard_training_form_record_ids_by_farmer_by_month ||= {}
    @dashboard_training_form_record_ids_by_farmer_by_month[month] ||= dashboard_training_form_records_by_month(month)
      .each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |record, index|
        training_record_selected_farmer_ids(record).each { |farmer_id| index[farmer_id] << record.id }
      end
  end

  def vrp_dashboard_detail_payload(list_type, vrp, mappings, targets, bills, filters = {})
    key = list_type.to_s.presence || "assigned_target"
    # Farmer/village lists do not display achievement calculations. Avoid
    # loading training records and approval data for those requests.
    simple_lists = %w[target_farmers mapped_farmers mapped_village_farmers ics_mapped_farmers mapped_villages]
    target_rows = simple_lists.include?(key) ? [] : vrp_dashboard_target_progress_rows(targets, bills)
    farmer_status_sets = if %w[complete_farmers red_farmers green_farmers yellow_farmers].include?(key)
      vrp_dashboard_farmer_status_sets(target_rows)
    end

    case key
    when "target_farmers"
      vrp_dashboard_target_farmer_payload(targets, filters)
    when "mapped_farmers"
      rows = vrp_dashboard_mapped_farmer_rows(mappings, targets, include_mapping_fallback: filters[:training_month].blank?)
      dashboard_detail_payload(key, "Mapped Farmers", "Unique farmers linked to your target rows.", rows.size, vrp_dashboard_farmer_list_headers, rows)
    when "mapped_village_farmers"
      rows = vrp_dashboard_afl_farmer_rows_for_target_villages(targets)
      dashboard_detail_payload(key, "Mapped Farmer", "AFL farmers available in filtered mapped villages.", rows.size, vrp_dashboard_farmer_list_headers, rows)
    when "ics_mapped_farmers"
      rows = vrp_dashboard_mapped_farmer_rows(mappings, [], include_mapping_fallback: true)
      dashboard_detail_payload(key, "AFL", "Distinct farmers mapped to you through ICS.", rows.size, ["Farmer", "Father Name", "Mobile", "TraceNet No", "ICS", "Village", "Status"], rows)
    when "pending_farmers"
      rows = vrp_dashboard_pending_farmer_rows(target_rows)
      dashboard_detail_payload(key, "Pending Farmers", "Pending mapped farmers for the selected month.", rows.size, vrp_target_farmer_headers, rows)
    when "complete_farmers", "red_farmers", "green_farmers", "yellow_farmers"
      status_key = key.delete_suffix("_farmers").to_sym
      farmer_ids = farmer_status_sets.fetch(status_key, [])
      rows = vrp_dashboard_mapped_farmer_rows(mappings, targets, include_mapping_fallback: false, farmer_ids: farmer_ids)
      title = key.titleize
      dashboard_detail_payload(key, title, "Distinct #{title.downcase} for the selected month.", rows.size, vrp_dashboard_farmer_list_headers, rows)
    when "mapped_villages"
      village_rows = vrp_dashboard_village_rows(vrp, mappings, targets)
      rows = village_rows.map do |row|
        village_link = ->(list_type, label) do
          { label: label, path: vrp_dashboard_list_path(list_type, training_month: filters[:training_month].presence, village_id: row[:village_id]) }
        end
        [
          row[:fco],
          row[:village],
          village_link.call("mapped_village_farmers", dashboard_quantity(row[:farmers])),
          village_link.call("assigned_target", dashboard_quantity(row[:targets])),
          village_link.call("assigned_target", dashboard_quantity(row[:target_quantity]))
        ]
      end
      dashboard_detail_payload(key, "Mapped Villages", "Villages assigned for field work.", rows.size, ["FCO", "Village", "Mapped Farmers", "Targets", "Target Quantity"], rows)
    when "main_activities"
      rows = vrp_dashboard_grouped_target_rows(target_rows, :main_activity)
      dashboard_detail_payload(key, "Main Activities", "Main activities mapped to your targets.", rows.size, ["Main Activity", "Targets", "Target", "Completed", "Pending", "Progress"], rows)
    when "sub_activities"
      rows = vrp_dashboard_grouped_target_rows(target_rows, :activity)
      dashboard_detail_payload(key, "Sub Activities", "Sub activities mapped to your targets.", rows.size, ["Main Activity", "Sub Activity", "Targets", "Target", "Completed", "Pending", "Progress"], rows)
    when "achieved_target"
      total = vrp_dashboard_target_totals(target_rows)[:achieved]
      rows = target_rows.select { |row| row[:completed].to_f.positive? }
      dashboard_detail_payload(key, "Achieved Target", "Target completed so far.", dashboard_quantity(total), vrp_target_detail_headers, vrp_target_detail_rows(rows, farmer_scope: "completed"))
    when "pending_target"
      total = vrp_dashboard_target_totals(target_rows)[:pending]
      rows = target_rows.select { |row| row[:pending].to_f.positive? }
      dashboard_detail_payload(key, "Pending Target", "Target left to complete.", dashboard_quantity(total), vrp_target_detail_headers, vrp_target_detail_rows(rows, farmer_scope: "pending"))
    else
      rows = target_rows
      dashboard_detail_payload("assigned_target", "Assigned Target", "Total target quantity assigned to you.", dashboard_quantity(vrp_dashboard_target_totals(rows)[:assigned]), vrp_target_detail_headers, vrp_target_detail_rows(rows, farmer_scope: "assigned"))
    end
  end

  def dashboard_detail_payload(key, title, caption, total, headers, rows)
    {
      key: key,
      title: title,
      caption: caption,
      total: total,
      headers: headers,
      rows: rows
    }
  end

  def vrp_dashboard_farmer_list_headers
    ["ICS", "Village", "Farmer", "Father Name", "TraceNet No"]
  end

  def vrp_dashboard_mapped_farmer_rows(mappings, targets, include_mapping_fallback: true, farmer_ids: nil)
    farmer_ids = Array(farmer_ids).map(&:to_s).reject(&:blank?).uniq if farmer_ids
    farmer_ids ||= vrp_targeted_farmer_ids(targets)
    if farmer_ids.blank? && include_mapping_fallback
      farmer_ids = mappings.flat_map { |mapping| Array(mapping.afl_ids).map(&:to_s) }.reject(&:blank?).uniq
    end
    farmers_by_id = model_ready?(:Afl) && farmer_ids.any? ? Afl.where(id: farmer_ids).index_by { |farmer| farmer.id.to_s } : {}

    farmer_ids.filter_map do |farmer_id|
      farmer = farmers_by_id[farmer_id.to_s]
      next unless farmer

      [
        dashboard_text_value(farmer.ics_name).presence || dashboard_text_value(farmer.ics_id).presence || "-",
        dashboard_text_value(farmer.village_name).presence || dashboard_text_value(farmer.village_id).presence || "-",
        dashboard_text_value(farmer.farmer_name).presence || "-",
        dashboard_text_value(farmer.father_name).presence || "-",
        dashboard_text_value(farmer.tracenet_no).presence || "-"
      ]
    end
  end

  def vrp_dashboard_afl_farmer_rows_for_target_villages(targets)
    return [] unless model_ready?(:Afl)

    targets = Array(targets)
    return [] if targets.blank?

    village_ids = targets.filter_map { |target| target.village_id.to_s.strip.presence }.uniq
    village_names = targets.filter_map { |target| target.village_name.to_s.strip.presence }.uniq
    return [] if village_ids.blank? && village_names.blank?

    scope = vrp_filter_afl_mapping_scope(Afl.all, :village_id, :village_name, village_ids, village_names)

    seen_keys = Set.new
    scope.order(:village_name, :farmer_name, :id).filter_map do |farmer|
      tracenet = dashboard_text_value(farmer.tracenet_no)
      key = tracenet.present? && tracenet.casecmp("NULL") != 0 ? "tracenet:#{tracenet.downcase}" : "afl:#{farmer.id}"
      next if seen_keys.include?(key)

      seen_keys << key
      [
        dashboard_text_value(farmer.ics_name).presence || dashboard_text_value(farmer.ics_id).presence || "-",
        dashboard_text_value(farmer.village_name).presence || dashboard_text_value(farmer.village_id).presence || "-",
        dashboard_text_value(farmer.farmer_name).presence || "Farmer ##{farmer.id}",
        dashboard_text_value(farmer.father_name).presence || "-",
        tracenet.presence || "-"
      ]
    end
  end

  def vrp_dashboard_target_farmer_payload(targets, filters)
    requested_ids = filters[:target_ids].to_s.split(",").map(&:strip).reject(&:blank?)
    requested_ids = [filters[:target_id].to_s] if requested_ids.blank? && filters[:target_id].present?
    selected_targets = Array(targets).select { |row| requested_ids.include?(row.id.to_s) }
    target = selected_targets.first
    scope = filters[:farmer_scope].presence_in(%w[assigned completed pending]) || "assigned"
    return dashboard_detail_payload("target_farmers", "Target Farmers", "Target record not found.", 0, vrp_target_farmer_headers, []) unless target

    assigned_ids = selected_targets.flat_map { |row| target_farmer_ids(row) }.map(&:to_s).reject(&:blank?).uniq
    training_mapping_farmer_ids = vrp_target_farmer_ids_from_training_mappings(selected_targets)
    assigned_ids = training_mapping_farmer_ids if assigned_ids.blank? && training_mapping_farmer_ids.any?
    activity_settings = jeevika_jankar_main_activity_settings
    sub_activity_settings = jeevika_jankar_sub_activity_settings(activity_settings)
    training_targets = selected_targets.select do |row|
      setting = jeevika_jankar_activity_setting_for(row, activity_settings, sub_activity_settings)
      setting.blank? || training_main_activity_type?(setting[:main_activity_type])
    end
    completed_ids = if training_targets.any?
      dashboard_training_form_completed_farmer_ids(training_targets, assigned_ids)
    else
      unique_training_farmer_ids(selected_targets.flat_map { |row| vrp_dashboard_completed_farmer_ids_for_target(row) }) & assigned_ids
    end
    training_mapping_completed_ids = vrp_target_completed_farmer_ids_from_training_mappings(selected_targets)
    completed_ids = training_mapping_completed_ids & assigned_ids if completed_ids.blank? && training_mapping_completed_ids.any?
    pending_ids = assigned_ids - completed_ids
    farmer_ids = case scope
    when "completed" then completed_ids
    when "pending" then pending_ids
    else assigned_ids
    end

    rows = if farmer_ids.any?
      vrp_target_farmer_rows(target, farmer_ids, completed_ids)
    else
      vrp_target_farmer_fallback_rows(selected_targets, scope)
    end
    title = {
      "assigned" => "Assigned Farmers",
      "completed" => "Completed Farmers",
      "pending" => "Pending Farmers"
    }[scope]
    caption = [
      target.month_name,
      target.village_name.presence || target.village_id,
      selected_targets.map(&:main_activity_name).compact_blank.uniq.join(", "),
      selected_targets.map(&:activity_name).compact_blank.uniq.join(", ")
    ].compact_blank.join(" | ")

    dashboard_detail_payload("target_farmers", title, caption, rows.size, vrp_target_farmer_headers, rows)
  end

  def vrp_dashboard_pending_farmer_rows(target_rows)
    Array(target_rows).flat_map do |row|
      target = row[:target_record]
      completed_ids = Array(row[:completed_farmer_ids]).map(&:to_s).reject(&:blank?).uniq
      assigned_ids = Array(row[:assigned_farmer_ids]).map(&:to_s).reject(&:blank?).uniq
      if assigned_ids.blank? && target
        assigned_ids = target_farmer_ids(target).map(&:to_s).reject(&:blank?).uniq
        training_mapping_farmer_ids = vrp_target_farmer_ids_from_training_mappings([target])
        assigned_ids = training_mapping_farmer_ids if assigned_ids.blank? && training_mapping_farmer_ids.any?
      end
      pending_ids = assigned_ids - completed_ids
      next [] if pending_ids.blank?

      target ? vrp_target_farmer_rows(target, pending_ids, completed_ids) : []
    end
  end

  def vrp_target_farmer_fallback_rows(_targets, _scope, fallback_count: nil)
    []
  end

  def vrp_target_farmer_ids_from_training_mappings(targets)
    vrp_target_training_mappings(targets)
      .flat_map { |mapping| Array(mapping[:farmers]).filter_map { |farmer| farmer[:id].presence } }
      .map(&:to_s)
      .reject(&:blank?)
      .uniq
  end

  def vrp_target_completed_farmer_ids_from_training_mappings(targets)
    vrp_target_training_mappings(targets)
      .flat_map { |mapping| Array(mapping[:completed_farmer_ids]) }
      .map(&:to_s)
      .reject(&:blank?)
      .uniq
  end

  def vrp_target_training_mappings(targets)
    targets = Array(targets)
    return [] if targets.blank?

    target_ids = targets.map { |target| target.id.to_s }.reject(&:blank?).uniq
    mappings = training_target_mappings.select { |mapping| target_ids.include?(mapping[:target_mapping_id].to_s) }
    return mappings if mappings.any?

    targets.flat_map do |target|
      training_target_mappings.select do |mapping|
        normalize_dashboard_text(mapping[:month]) == normalize_dashboard_text(target.month_name) &&
          normalize_dashboard_text(mapping[:ics]) == normalize_dashboard_text(target.ics_name.presence || target.ics_id) &&
          normalize_dashboard_text(mapping[:village]) == normalize_dashboard_text(target.village_name.presence || target.village_id) &&
          dashboard_training_activity_text_matches?(mapping[:main_activity], normalize_dashboard_text(target.main_activity_name)) &&
          dashboard_training_activity_text_matches?(mapping[:sub_activity], normalize_dashboard_text(target.activity_name))
      end
    end.uniq { |mapping| mapping[:target_mapping_id].to_s }
  end

  def vrp_dashboard_completed_farmer_ids_for_target(target)
    farmer_ids = target_farmer_ids(target)
    (
      completed_training_farmer_ids_for(target, farmer_ids) +
      approved_other_target_completed_farmer_ids_for(target.id)
    ).map(&:to_s).reject(&:blank?).uniq
  end

  def approved_other_target_completed_farmer_ids_for(target_mapping_id)
    return [] unless model_ready?(:ModuleRecord)

    approved_other_target_completed_farmer_ids_by_target[target_mapping_id.to_s] || []
  end

  def approved_other_target_completed_farmer_ids_by_target
    return @approved_other_target_completed_farmer_ids_by_target if defined?(@approved_other_target_completed_farmer_ids_by_target)

    @approved_other_target_completed_farmer_ids_by_target = Hash.new { |hash, key| hash[key] = [] }
    return @approved_other_target_completed_farmer_ids_by_target unless model_ready?(:ModuleRecord)

    records = ModuleRecord.where(module_slug: OTHER_TARGET_MODULE_SLUGS)
    candidate_months = other_target_candidate_targets.map { |target| normalize_dashboard_text(target.month_name) }.reject(&:blank?).uniq
    records = records.where("LOWER(BTRIM(data::jsonb ->> 'month')) IN (?)", candidate_months) if candidate_months.present?
    records = records
      .order(created_at: :asc)
      .select { |record| approved_other_target_record?(record) }

    index_other_target_records_by_target(records, @approved_other_target_completed_farmer_ids_by_target)
  end

  def index_other_target_records_by_target(records, result, target_ids: nil)
    allowed_ids = Array(target_ids).map(&:to_s).reject(&:blank?)

    Array(records).each do |record|
      matched_target_ids = other_target_record_target_mapping_ids(record)
      matched_target_ids &= allowed_ids if allowed_ids.present?
      next if matched_target_ids.blank?

      farmer_ids = Array(record.data["selected_farmer_ids"]).map(&:to_s).reject(&:blank?)
      matched_target_ids.each { |target_mapping_id| result[target_mapping_id] |= farmer_ids }
    end

    result
  end

  def vrp_target_farmer_headers
    ["ICS", "Village", "Farmer", "Father Name", "TraceNet No", "Target Month", "Main Activity", "Sub Activity"]
  end

  def vrp_target_farmer_rows(target, farmer_ids, completed_ids)
    farmers_by_id = model_ready?(:Afl) && farmer_ids.any? ? Afl.where(id: farmer_ids).index_by { |farmer| farmer.id.to_s } : {}

    Array(farmer_ids).filter_map do |farmer_id|
      farmer = farmers_by_id[farmer_id.to_s]
      next unless farmer

      completed = completed_ids.include?(farmer_id.to_s)
      [
        dashboard_text_value(farmer.ics_name).presence || dashboard_text_value(farmer.ics_id).presence || dashboard_text_value(target.ics_name).presence || dashboard_text_value(target.ics_id).presence || "-",
        dashboard_text_value(farmer.village_name).presence || dashboard_text_value(farmer.village_id).presence || dashboard_text_value(target.village_name).presence || dashboard_text_value(target.village_id).presence || "-",
        dashboard_text_value(farmer.farmer_name).presence || "-",
        dashboard_text_value(farmer.father_name).presence || "-",
        dashboard_text_value(farmer.tracenet_no).presence || "-",
        dashboard_text_value(target.month_name).presence || "-",
        dashboard_text_value(target.main_activity_name).presence || "-",
        dashboard_text_value(target.activity_name).presence || "-"
      ]
    end
  end

  def vrp_dashboard_grouped_target_rows(target_rows, group_type)
    grouped = Array(target_rows).group_by do |row|
      if group_type == :activity
        [normalize_dashboard_text(row[:main_activity]), normalize_dashboard_text(row[:activity])]
      else
        normalize_dashboard_text(row[:main_activity])
      end
    end

    grouped.values.map do |rows|
      target_total = rows.sum { |row| row[:target].to_f }
      completed_total = rows.sum { |row| row[:completed].to_f }
      pending_total = rows.sum { |row| row[:pending].to_f }

      if group_type == :activity
        [
          rows.first[:main_activity].presence || "-",
          rows.first[:activity].presence || "-",
          rows.size,
          dashboard_quantity(target_total),
          dashboard_quantity(completed_total),
          dashboard_quantity(pending_total),
          percentage(completed_total, target_total)
        ]
      else
        [
          rows.first[:main_activity].presence || "-",
          rows.size,
          dashboard_quantity(target_total),
          dashboard_quantity(completed_total),
          dashboard_quantity(pending_total),
          percentage(completed_total, target_total)
        ]
      end
    end.sort_by { |row| row.first.to_s }
  end

  def vrp_target_detail_headers
    ["Month", "Completion Date", "FCO", "ICS", "Village", "Farmers", "Main Activity", "Sub Activity", "Target", "Week 1", "Week 2", "Week 3", "Week 4", "OPG Training", "General Training/Meeting", "Input Demo INM", "Input Demo PM", "FFS", "Completed", "Pending", "Progress", "Farmer List"]
  end

  def vrp_target_detail_rows(rows, farmer_scope:)
    Array(rows).map do |row|
      [
        row[:month].presence || "-",
        row[:completion_date].presence || "-",
        row[:fco].presence || "-",
        row[:ics].presence || "-",
        row[:village].presence || "-",
        dashboard_quantity(row[:farmers]),
        row[:main_activity].presence || "-",
        row[:activity].presence || "-",
        dashboard_quantity(row[:target]),
        dashboard_quantity(row[:week_1]),
        dashboard_quantity(row[:week_2]),
        dashboard_quantity(row[:week_3]),
        dashboard_quantity(row[:week_4]),
        row[:opg_training].present? ? dashboard_quantity(row[:opg_training]) : "-",
        row[:general_training].present? ? dashboard_quantity(row[:general_training]) : "-",
        row[:input_demo_inm].present? ? dashboard_quantity(row[:input_demo_inm]) : "-",
        row[:input_demo_pm].present? ? dashboard_quantity(row[:input_demo_pm]) : "-",
        row[:ffs].present? ? dashboard_quantity(row[:ffs]) : "-",
        dashboard_quantity(row[:completed]),
        dashboard_quantity(row[:pending]),
        row[:progress],
        {
          label: "View List",
          path: vrp_dashboard_list_path(
            "target_farmers",
            target_id: row[:target_mapping_id],
            target_ids: Array(row[:target_mapping_ids].presence || row[:target_mapping_id]).join(","),
            farmer_scope: farmer_scope,
            training_month: row[:month]
          )
        }
      ]
    end
  end

  def dashboard_detail_rows_csv(detail)
    CSV.generate(headers: true) do |csv|
      csv << detail[:headers]
      Array(detail[:rows]).each { |row| csv << row.map { |cell| dashboard_detail_cell_text(cell) } }
    end
  end

  def dashboard_detail_cell_text(cell)
    cell.is_a?(Hash) && cell[:label].present? ? cell[:label] : cell
  end

  def vrp_farmer_followup(mappings)
    mapped_farmer_ids = mappings.flat_map { |mapping| Array(mapping.afl_ids).map(&:to_s) }.reject(&:blank?).uniq
    vrp_farmer_followup_for_ids(mapped_farmer_ids)
  end

  def vrp_farmer_followup_for_ids(mapped_farmer_ids)
    return empty_vrp_farmer_followup if mapped_farmer_ids.blank? || !model_ready?(:Afl)

    farmers = Afl.where(id: mapped_farmer_ids).to_a
    work_dates = farmers.filter_map { |farmer| afl_work_date(farmer) }
    current_month = work_dates.max&.beginning_of_month || Date.current.beginning_of_month
    previous_month = current_month.prev_month
    mapped_farmer_keys = farmers.map { |farmer| farmer_identity_key(farmer) }.reject(&:blank?).uniq
    current_farmer_keys = farmers.select { |farmer| date_in_month?(afl_work_date(farmer), current_month) }.map { |farmer| farmer_identity_key(farmer) }.reject(&:blank?).uniq
    previous_farmer_keys = farmers.select { |farmer| date_in_month?(afl_work_date(farmer), previous_month) }.map { |farmer| farmer_identity_key(farmer) }.reject(&:blank?).uniq

    {
      current_month: current_month,
      previous_month: previous_month,
      repeat: farmer_rows_for_keys(current_farmer_keys & previous_farmer_keys, farmers),
      new: farmer_rows_for_keys(current_farmer_keys - previous_farmer_keys, farmers),
      pending: farmer_rows_for_keys(mapped_farmer_keys - current_farmer_keys, farmers)
    }
  end

  def empty_vrp_farmer_followup
    {
      current_month: Date.current.beginning_of_month,
      previous_month: Date.current.prev_month.beginning_of_month,
      repeat: [],
      new: [],
      pending: []
    }
  end

  def afl_work_date(afl)
    afl.purchase_date || afl.date || afl.qrcode_date&.to_date
  end

  def date_in_month?(date, month_start)
    return false unless date

    date >= month_start && date < month_start.next_month
  end

  def farmer_identity_key(farmer)
    farmer.tracenet_no.presence ||
      farmer.mobile_no.presence ||
      farmer.aadhar.presence ||
      [farmer.farmer_name, farmer.father_name, farmer.village_id].map { |value| normalize_dashboard_text(value) }.join("|")
  end

  def farmer_rows_for_keys(keys, farmers)
    farmer_by_key = farmers.group_by { |farmer| farmer_identity_key(farmer) }
    keys.filter_map do |key|
      farmer = farmer_by_key[key.to_s]&.max_by { |row| afl_work_date(row) || Date.new(1900, 1, 1) }
      next unless farmer

      {
        name: dashboard_text_value(farmer.farmer_name).presence || "Farmer ##{farmer.id}",
        father_name: dashboard_text_value(farmer.father_name),
        village: dashboard_text_value(farmer.village_name).presence || dashboard_text_value(farmer.village_id),
        mobile_no: dashboard_text_value(farmer.mobile_no),
        tracenet_no: dashboard_text_value(farmer.tracenet_no),
        work_date: afl_work_date(farmer)
      }
    end.sort_by { |row| [row[:village].to_s, row[:name].to_s] }
  end

  def vrp_target_completed_quantity(target, bills, activity_settings: nil, sub_activity_settings: nil, other_target_achievement_index: nil)
    activity_settings ||= jeevika_jankar_main_activity_settings
    sub_activity_settings ||= jeevika_jankar_sub_activity_settings(activity_settings)
    activity_setting = jeevika_jankar_activity_setting_for(target, activity_settings, sub_activity_settings)

    # A missing key in the already-built index means no achievement. Rebuilding
    # the entire index for every missing target repeats the same database work.
    other_target_achievement = (other_target_achievement_index || approved_other_target_achievement_index)[target.id.to_s]
    return capped_target_achievement(target, other_target_achievement[:achievement]) if other_target_achievement.present?

    if activity_setting.blank? || training_main_activity_type?(activity_setting[:main_activity_type])
      # Older/renamed activity-master rows may not resolve to a setting. Matching
      # training submissions are still authoritative completion evidence and must
      # keep the dashboard's achieved/pending figures live.
      completed_farmer_count = completed_training_farmer_ids_for(target, target_farmer_ids(target)).size
      return capped_target_achievement(target, completed_farmer_count) if completed_farmer_count.positive?
    end

    relevant_bills = bills.select do |record|
      target.month_name.blank? || normalize_dashboard_text(record.data["select_bill_month"]) == normalize_dashboard_text(target.month_name)
    end

    bill_achievement = relevant_bills.sum do |record|
      matching_items = vrp_bill_items(record).select do |item|
        normalize_dashboard_text(item["activity"]) == normalize_dashboard_text(target.activity_name)
      end

      if matching_items.any?
        matching_items.sum { |item| dashboard_numeric(item["no_of_unit"]) }
      elsif Array(record.data["select_activity_group"]).any? { |activity| normalize_dashboard_text(activity) == normalize_dashboard_text(target.main_activity_name) }
        dashboard_numeric(record.data["grand_units"])
      else
        0
      end
    end

    capped_target_achievement(target, bill_achievement)
  end

  def capped_target_achievement(target, achievement)
    [[achievement.to_f, 0].max, target.target_quantity.to_f].min
  end

  def vrp_bill_items(record)
    raw_items = record.data["bill_items"]
    items = raw_items.is_a?(Hash) ? raw_items.values : Array(raw_items)
    items.select { |item| item.respond_to?(:[]) }
  end

  def dashboard_numeric(value)
    value.to_s.gsub(",", "").to_f
  end

  def dashboard_quantity(value)
    value = value.to_f
    value == value.to_i ? value.to_i : format("%.2f", value)
  end

  def normalize_dashboard_text(value)
    value.to_s.strip.downcase
  end

  def dashboard_text_value(value)
    value.to_s.strip.presence
  end

  def dashboard_preferred_text(*values)
    values.filter_map { |value| dashboard_text_value(value) }.first
  end

  def dashboard_farmer_profile_from_records(id, afl = nil, farmer_info = nil, declaration = nil)
    {
      id: id.to_s,
      farmer_name: dashboard_preferred_text(afl&.farmer_name, farmer_info&.farmer_name, declaration&.farmer_name).presence || "Farmer ##{id}",
      father_name: dashboard_preferred_text(afl&.father_name, farmer_info&.father_mother_name),
      mobile_no: dashboard_preferred_text(afl&.mobile_no, farmer_info&.farmer_contact_no, declaration&.farmer_contact_no),
      tracenet_no: dashboard_preferred_text(afl&.tracenet_no, farmer_info&.tracenet_no, declaration&.tracenet_no),
      khasara_no: dashboard_preferred_text(afl&.khasara_no, farmer_info&.khasra_no),
      ics_name: dashboard_preferred_text(afl&.ics_name, farmer_info&.ics_name, declaration&.ics_name),
      ics_id: dashboard_text_value(afl&.ics_id),
      village_name: dashboard_preferred_text(afl&.village_name, farmer_info&.farmer_village, farmer_info&.farm_village, declaration&.farmer_village),
      village_id: dashboard_text_value(afl&.village_id),
      status: dashboard_preferred_text(afl&.status, farmer_info&.status, declaration&.status),
      work_date: afl ? afl_work_date(afl) : nil
    }
  end

  def dashboard_farmer_profiles_by_id(farmer_ids)
    ids = Array(farmer_ids).map(&:to_s).reject(&:blank?).uniq
    return {} if ids.blank?

    @dashboard_farmer_profiles_by_id_cache ||= {}
    cache_key = ids.sort.join("|")
    return @dashboard_farmer_profiles_by_id_cache[cache_key] if @dashboard_farmer_profiles_by_id_cache.key?(cache_key)

    afls = if model_ready?(:Afl)
      Afl.where(id: ids).to_a.index_by { |farmer| farmer.id.to_s }
    else
      {}
    end

    farmer_infos = dashboard_farmer_information_records(afls.values)
    declarations = dashboard_exit_declarations_for_afls(afls.values)

    farmer_info_by_farm_id = farmer_infos.index_by { |farmer| farmer.farm_id.to_s }
    farmer_info_by_tracenet = farmer_infos.each_with_object({}) do |farmer_info, index|
      key = dashboard_text_value(farmer_info.tracenet_no)
      index[key] ||= farmer_info if key.present?
    end
    farmer_info_by_aadhar = farmer_infos.each_with_object({}) do |farmer_info, index|
      key = dashboard_text_value(farmer_info.aadhar_number)
      index[key] ||= farmer_info if key.present?
    end
    farmer_info_by_mobile = farmer_infos.each_with_object({}) do |farmer_info, index|
      key = dashboard_text_value(farmer_info.farmer_contact_no)
      index[key] ||= farmer_info if key.present?
    end
    farmer_info_by_name = farmer_infos.each_with_object({}) do |farmer_info, index|
      key = dashboard_text_value(farmer_info.farmer_name)
      index[key] ||= farmer_info if key.present?
    end
    farmer_info_by_id = farmer_infos.index_by { |farmer| farmer.id.to_s }

    profiles = ids.each_with_object({}) do |id, memo|
      afl = afls[id]
      declaration = dashboard_farmer_declaration_for_afl(afl, declarations)
      farmer_info = farmer_info_by_farm_id[id]
      farmer_info ||= farmer_info_by_tracenet[dashboard_text_value(afl&.tracenet_no)] if afl.present?
      farmer_info ||= farmer_info_by_aadhar[dashboard_text_value(afl&.aadhar)] if afl.present?
      farmer_info ||= farmer_info_by_aadhar[dashboard_text_value(afl&.qr_aadhar)] if afl.present?
      farmer_info ||= farmer_info_by_mobile[dashboard_text_value(afl&.mobile_no)] if afl.present?
      farmer_info ||= farmer_info_by_name[dashboard_text_value(afl&.farmer_name)] if afl.present?
      farmer_info ||= farmer_info_by_id[declaration&.farmer_farm_information_id.to_s] if declaration&.farmer_farm_information_id.present?
      memo[id] = dashboard_farmer_profile_from_records(id, afl, farmer_info, declaration)
    end

    @dashboard_farmer_profiles_by_id_cache[cache_key] = profiles
  end

  def dashboard_farmer_information_records(afls)
    return [] unless model_ready?(:FarmerFarmInformation)

    afls = Array(afls)
    ids = afls.map { |afl| afl.id.to_s }.reject(&:blank?).uniq
    tracenets = afls.map { |afl| dashboard_text_value(afl&.tracenet_no) }.compact
    aadhars = afls.flat_map { |afl| [afl.aadhar, afl.qr_aadhar] }.map { |value| dashboard_text_value(value) }.compact
    mobiles = afls.map { |afl| dashboard_text_value(afl&.mobile_no) }.compact
    names = afls.map { |afl| dashboard_text_value(afl&.farmer_name) }.compact
    declaration_ids = dashboard_exit_declarations_for_afls(afls).values.map { |declaration| declaration&.farmer_farm_information_id.to_s }.reject(&:blank?).uniq

    scope = FarmerFarmInformation.none
    scope = scope.or(FarmerFarmInformation.where(farm_id: ids)) if ids.any?
    scope = scope.or(FarmerFarmInformation.where(tracenet_no: tracenets)) if tracenets.any?
    scope = scope.or(FarmerFarmInformation.where(aadhar_number: aadhars)) if aadhars.any?
    scope = scope.or(FarmerFarmInformation.where(farmer_contact_no: mobiles)) if mobiles.any?
    scope = scope.or(FarmerFarmInformation.where(farmer_name: names)) if names.any?
    scope = scope.or(FarmerFarmInformation.where(id: declaration_ids)) if declaration_ids.any?

    scope.to_a.uniq { |farmer| farmer.id }
  end

  def dashboard_exit_declarations_for_afls(afls)
    return {} unless model_ready?(:IcsExitDeclaration)

    afls = Array(afls)
    ids = afls.map { |afl| afl.id.to_s }.reject(&:blank?).uniq
    tracenets = afls.map { |afl| dashboard_text_value(afl&.tracenet_no) }.compact
    mobiles = afls.map { |afl| dashboard_text_value(afl&.mobile_no) }.compact
    names = afls.map { |afl| dashboard_text_value(afl&.farmer_name) }.compact
    id_numbers = afls.flat_map { |afl| [afl.aadhar, afl.qr_aadhar] }.map { |value| dashboard_text_value(value) }.compact

    scope = IcsExitDeclaration.none
    scope = scope.or(IcsExitDeclaration.where(farm_id: ids)) if ids.any?
    scope = scope.or(IcsExitDeclaration.where(tracenet_no: tracenets)) if tracenets.any?
    scope = scope.or(IcsExitDeclaration.where(farmer_contact_no: mobiles)) if mobiles.any?
    scope = scope.or(IcsExitDeclaration.where(farmer_name: names)) if names.any?
    scope = scope.or(IcsExitDeclaration.where(id_number: id_numbers)) if id_numbers.any?

    scope.to_a.each_with_object({}) do |declaration, index|
      [
        declaration.farm_id,
        declaration.tracenet_no,
        declaration.farmer_contact_no,
        declaration.farmer_name,
        declaration.id_number,
        declaration.farmer_farm_information_id
      ].map { |value| dashboard_text_value(value) }.reject(&:blank?).each do |key|
        index[key] ||= declaration
      end
    end
  end

  def dashboard_farmer_declaration_for_afl(afl, declarations_by_key)
    return nil unless afl.present?

    keys = [
      afl.id,
      afl.tracenet_no,
      afl.mobile_no,
      afl.aadhar,
      afl.qr_aadhar,
      afl.farmer_name
    ].map { |value| dashboard_text_value(value) }.reject(&:blank?)

    keys.each do |key|
      declaration = declarations_by_key[key]
      return declaration if declaration.present?
    end

    nil
  end

  def dashboard_cards
    vrps = dashboard_vrps
    active_vrps = vrps.select do |vrp|
      is_act = vrp.respond_to?(:is_active) ? (vrp.is_active == true || vrp.is_active == 1) : true
      is_del = vrp.respond_to?(:is_deleted) ? (vrp.is_deleted == true || vrp.is_deleted == 1) : false
      is_act && !is_del
    end
    approved_vrps = dashboard_approved_vrps(active_vrps).size
    pending_approvals = dashboard_pending_approval_vrps(active_vrps).size

    bill_records = dashboard_billing_records
    approved_bills = bill_records.count { |r| dashboard_bill_approved?(r) }
    pending_bills = bill_records.count { |r| dashboard_bill_pending?(r) }
    billing_items = [
      { title: "Approved", value: approved_bills, path: module_path("jeevika-jankar-bill-list", bill_status: "final-approved", record_state: "Active") },
      { title: "Pending", value: pending_bills, path: module_path("jeevika-jankar-bill-list", bill_status: "pending", record_state: "Active") }
    ]

    cards = [
      dashboard_group_card("Jeevika Jankar Registration", [
        { title: "Total Registered", value: active_vrps.size, path: vrps_path(active_status: "active") },
        { title: "Final Approved", value: approved_vrps, path: vrps_path(approval_status: "final-approved", active_status: "active") },
        { title: "Pending Approval", value: pending_approvals, path: approvals_vrps_path }
      ], style: "registration"),
      dashboard_group_card("Jeevika Jankar Billing", billing_items, style: "billing")
    ]
    fco_names = %w[Sausar Turekela]
    gender_month = params[:month].presence || params[:training_month].presence || "August"
    gender_items = fco_names.flat_map do |fco_name|
      # Same JJ set as the FCO-wise JJ Requirement "Active" box, split by gender.
      fco_vrps = dashboard_fco_active_vrp_records(fco_name, gender_month, vrps)
      [
        { title: "#{fco_name} Male", value: fco_vrps.count { |vrp| normalize_dashboard_text(vrp.gender) == "male" }, path: vrps_path(gender: "male", fcoc: fco_name, active_status: "active") },
        { title: "#{fco_name} Female", value: fco_vrps.count { |vrp| normalize_dashboard_text(vrp.gender) == "female" }, path: vrps_path(gender: "female", fcoc: fco_name, active_status: "active") }
      ]
    end
    cards << dashboard_group_card("Gender Count", gender_items, style: "registration")
    cards << dashboard_group_card("FCO-wise JJ Requirement", fco_names.flat_map { |fco_name| dashboard_jj_requirement_items(fco_name, vrps, defined?(@filtered_targets) ? @filtered_targets : nil) }, style: "fco")

    cards
  end

  def dashboard_summary_cards(targets)
    summary_counts = dashboard_summary_login_counts(targets)
    main_activity_popup_items = dashboard_summary_activity_popup_items(:main_activity)
    sub_activity_popup_items = dashboard_summary_activity_popup_items(:sub_activity)

    [
      dashboard_summary_card("Total ICS Count", summary_counts[:ics_count], "Total ICS for selected login and filters", afls_path(dashboard_summary_afl_params.merge(summary_mode: "ics")), dashboard_path(dashboard_summary_target_params.merge(format: :xlsx))),
      dashboard_summary_card("Total Villages Count", summary_counts[:village_count], "Total villages for selected login and filters", afls_path(dashboard_summary_afl_params.merge(summary_mode: "village")), dashboard_path(dashboard_summary_target_params.merge(format: :xlsx))),
      dashboard_summary_card("Total Farmer Count", summary_counts[:farmer_count], "Total registered farmers for selected login and filters", afls_path(dashboard_summary_afl_params.merge(summary_mode: "farmer")), dashboard_path(dashboard_summary_target_params.merge(format: :xlsx))),
      dashboard_summary_card("Total Mapped Main Activities", summary_counts[:main_activity_count], "Filtered main activities", target_mappings_path(dashboard_summary_target_params.merge(summary_mode: "main_activity")), dashboard_path(dashboard_summary_target_params.merge(format: :xlsx)), popup_items: main_activity_popup_items),
      dashboard_summary_card("Total Mapped Sub-Activities", summary_counts[:sub_activity_count], "Filtered sub-activities", target_mappings_path(dashboard_summary_target_params.merge(summary_mode: "sub_activity")), dashboard_path(dashboard_summary_target_params.merge(format: :xlsx)), popup_items: sub_activity_popup_items)
    ]
  end

  def dashboard_summary_login_counts(targets)
    query_counts = dashboard_summary_query_counts
    return query_counts if query_counts.present?

    targets = Array(targets)
    {
      ics_count: dashboard_total_afl_ics_count,
      village_count: dashboard_total_afl_village_count,
      farmer_count: dashboard_total_afl_farmer_count,
      mapped_farmer_count: dashboard_distinct_target_array_count(targets, :afl_ids),
      main_activity_count: targets.map { |t| normalize_dashboard_text(t.main_activity_name) }.reject(&:blank?).uniq.size,
      sub_activity_count: targets.map { |t| normalize_dashboard_text(t.activity_name) }.reject(&:blank?).uniq.size
    }
  end

  def dashboard_summary_query_counts
    return nil unless model_ready?(:TargetMapping)

    target_conditions, binds = dashboard_summary_target_sql_filters
    target_where = target_conditions.join(" AND ")
    sql = <<~SQL.squish
      WITH mapped_rows AS (
        SELECT
          j.value AS afl_id
        FROM target_mappings t
        LEFT JOIN vrps v ON v.id = t.vrp_id
        CROSS JOIN LATERAL jsonb_array_elements_text(
          CASE
            WHEN jsonb_typeof(t.afl_ids::jsonb) = 'array' THEN t.afl_ids::jsonb
            ELSE jsonb_build_array(t.afl_ids::jsonb)
          END
        ) AS j(value)
        WHERE #{target_where}
      )
      SELECT
        COUNT(DISTINCT mapped_rows.afl_id) AS mapped_farmer_count
      FROM mapped_rows
    SQL

    row = ActiveRecord::Base.connection.exec_query(
      ActiveRecord::Base.send(:sanitize_sql_array, [sql, binds])
    ).first || {}

    activity_counts = dashboard_summary_activity_counts_direct

    {
      ics_count: dashboard_total_afl_ics_count,
      village_count: dashboard_total_afl_village_count,
      farmer_count: dashboard_total_afl_farmer_count,
      mapped_farmer_count: row["mapped_farmer_count"].to_i,
      main_activity_count: activity_counts[:main_activity_count],
      sub_activity_count: activity_counts[:sub_activity_count]
    }
  rescue StandardError => e
    Rails.logger.warn("Dashboard summary query counts failed: #{e.class} - #{e.message}")
    nil
  end

  def dashboard_summary_activity_counts_direct
    return { main_activity_count: 0, sub_activity_count: 0 } unless model_ready?(:TargetMapping)

    target_conditions, binds = dashboard_summary_target_sql_filters_base(include_activity_filters: false)
    target_where = target_conditions.join(" AND ")
    sql = <<~SQL.squish
      SELECT
        COUNT(DISTINCT NULLIF(LOWER(BTRIM(t.main_activity_name)), '')) AS main_activity_count,
        COUNT(DISTINCT NULLIF(LOWER(BTRIM(t.activity_name)), '')) AS sub_activity_count
      FROM target_mappings t
      LEFT JOIN vrps v ON v.id = t.vrp_id
      WHERE #{target_where}
    SQL

    row = ActiveRecord::Base.connection.exec_query(
      ActiveRecord::Base.send(:sanitize_sql_array, [sql, binds])
    ).first || {}

    {
      main_activity_count: row["main_activity_count"].to_i,
      sub_activity_count: row["sub_activity_count"].to_i
    }
  rescue StandardError => e
    { main_activity_count: 0, sub_activity_count: 0 }
  end

  def dashboard_summary_target_sql_filters_base(include_activity_filters: true)
    conditions = ["1=1"]
    binds = {}
    unless dashboard_global_view_user?
      conditions << "t.vrp_id IN (:authorized_vrp_ids)"
      binds[:authorized_vrp_ids] = dashboard_visible_vrp_ids
    end

    if @dashboard_month_filter_value.present?
      conditions << "LOWER(BTRIM(t.month_name)) = :summary_month"
      binds[:summary_month] = normalize_dashboard_text(@dashboard_month_filter_value)
    end

    if include_activity_filters
      main_activity_value = @dashboard_main_activity_filter_value.presence || dashboard_filter_param(:main_activity)
      if main_activity_value.present?
        conditions << "LOWER(BTRIM(t.main_activity_name)) = :summary_main_activity"
        binds[:summary_main_activity] = normalize_dashboard_text(main_activity_value)
      end

      sub_activity_value = dashboard_filter_param(:sub_activity)
      if sub_activity_value.present?
        conditions << "LOWER(BTRIM(t.activity_name)) = :summary_sub_activity"
        binds[:summary_sub_activity] = normalize_dashboard_text(sub_activity_value)
      end
    end

    fcoc_value = @dashboard_fcoc_filter_value.presence || dashboard_filter_param(:fcoc, :fco)
    fco_values = dashboard_summary_fco_filter_values(fcoc_value)
    conditions << "(LOWER(BTRIM(t.fco_name)) IN (:summary_fco_values) OR LOWER(BTRIM(t.fco_id)) IN (:summary_fco_values) OR LOWER(BTRIM(v.fcoc)) IN (:summary_fco_values))"
    binds[:summary_fco_values] = fco_values

    ics_value = dashboard_filter_param(:ics, :ics_name)
    if ics_value.present?
      conditions << "(LOWER(BTRIM(t.ics_name)) = :summary_ics OR LOWER(BTRIM(t.ics_id)) = :summary_ics)"
      binds[:summary_ics] = normalize_dashboard_text(ics_value)
    end

    selected_vrp_id = dashboard_filter_param(:vrp_id)
    if selected_vrp_id.present?
      conditions << "t.vrp_id = :summary_vrp_id"
      binds[:summary_vrp_id] = selected_vrp_id.to_i
    elsif vrp_login_user? && current_vrp_record.present?
      conditions << "t.vrp_id = :summary_vrp_id"
      binds[:summary_vrp_id] = current_vrp_record.id
    elsif dashboard_agronomics_login?
      conditions << "t.vrp_id IN (:summary_registered_vrp_ids)"
      binds[:summary_registered_vrp_ids] = dashboard_registered_vrp_ids_for_current_user
    elsif dashboard_cc_vrp_scope_active?
      conditions << "t.vrp_id IN (:summary_visible_vrp_ids)"
      binds[:summary_visible_vrp_ids] = module_cluster_visible_vrp_ids
    end

    [conditions, binds]
  end

  def dashboard_summary_target_sql_filters
    conditions, binds = dashboard_summary_target_sql_filters_base
    [["j.value <> ''"] + conditions[1..-1], binds]
  end

  def dashboard_summary_direct_afl_total?
    !vrp_login_user? && !dashboard_agronomics_login? && !dashboard_cc_vrp_scope_active?
  end

  def dashboard_agronomics_login?
    return @dashboard_agronomics_login if defined?(@dashboard_agronomics_login)

    @dashboard_agronomics_login = compute_dashboard_agronomics_login
  end

  def compute_dashboard_agronomics_login
    [
      current_app_user&.dig("role"),
      current_app_user&.dig("role_name"),
      current_app_user&.dig("stakeholder_role"),
      current_app_user&.dig("user_management_role"),
      current_app_user&.dig("person_type"),
      current_app_user&.dig("designation")
    ].compact_blank.any? { |value| normalize_dashboard_text(value).include?("agronom") }
  end

  def dashboard_registered_vrp_ids_for_current_user
    @dashboard_registered_vrp_ids_for_current_user ||= dashboard_own_vrps_list.map(&:id).compact
  end

  def dashboard_cc_vrp_scope_active?
    return false if dashboard_global_view_user? || vrp_login_user? || dashboard_agronomics_login?
    return false if dashboard_source_fcoc_login?

    module_mapped_vrp_scope_active?
  end

  def dashboard_source_fcoc_login?
    return @dashboard_source_fcoc_login if defined?(@dashboard_source_fcoc_login)

    @dashboard_source_fcoc_login = compute_dashboard_source_fcoc_login
  end

  def compute_dashboard_source_fcoc_login
    values = [
      current_app_user&.dig("role"),
      current_app_user&.dig("role_name"),
      current_app_user&.dig("stakeholder_role"),
      current_app_user&.dig("user_management_role"),
      current_app_user&.dig("person_type"),
      current_app_user&.dig("designation")
    ].compact_blank.map { |value| normalize_dashboard_text(value) }

    values.any? { |value| value.include?("fcoc") || value.include?("fco-c") || value.include?("fco c") || value == "fco" || value.include?("source") }
  end

  def demonstration_method_cards
    report = @demonstration_method_report || DemonstrationMethodReport.new(
      targets: @filtered_targets || dashboard_target_mappings,
      month: params.key?(:month) ? dashboard_filter_param(:month) : Date.current.prev_month.strftime("%B"))
    # Display titles only; the underlying metric/data keys ("OPG Target", "FFS") are unchanged.
    demonstration_method_card_titles = { "OPG Target" => "OPG Training Target", "FFS" => "FFS Exposure" }
    DemonstrationMethodReport::METRICS.map do |metric|
      dashboard_summary_card(demonstration_method_card_titles.fetch(metric, metric),
        dashboard_quantity(report.summary.sum { |row| row[metric] }), "Training method entries",
        demonstration_method_list_path(request.query_parameters),
        demonstration_method_list_path(request.query_parameters.merge(format: :xlsx)))
    end
  end

  def dashboard_opg_achievement_count
    return 0 unless model_ready?(:ModuleRecord)

    month_value = @participation_selected_month.presence || @dashboard_month_filter_value.presence
    fcoc_value = @participation_fcoc_filter_value.presence || @dashboard_fcoc_filter_value.presence || dashboard_filter_param(:fcoc, :fco)
    selected_vrp_id = dashboard_filter_param(:vrp_id)

    training_conditions = ["mr.module_slug = 'training-form'", "sf.farmer_id <> ''"]
    if !dashboard_global_view_user? || dashboard_filter_param(:ics, :ics_name).present?
      training_conditions << "sf.farmer_id IN (#{dashboard_visible_farmer_scope.select('afls.id::text').to_sql})"
    end
    training_binds = {}

    if month_value.present?
      training_conditions << "LOWER(COALESCE(mr.data::jsonb ->> 'month', '')) = :training_month"
      training_binds[:training_month] = normalize_dashboard_text(month_value)
    end

    if selected_vrp_id.present?
      training_conditions << "mr.data::jsonb ->> 'created_by_id' = :created_by_id"
      training_binds[:created_by_id] = selected_vrp_id.to_s
    elsif vrp_login_user? && current_vrp_record.present?
      training_conditions << "mr.data::jsonb ->> 'created_by_id' = :created_by_id"
      training_binds[:created_by_id] = current_vrp_record.id.to_s
    elsif dashboard_agronomics_login?
      training_conditions << "COALESCE(mr.data::jsonb ->> 'created_by_id', '') IN (:created_by_ids)"
      training_binds[:created_by_ids] = dashboard_registered_vrp_ids_for_current_user.map(&:to_s)
    elsif dashboard_cc_vrp_scope_active?
      training_conditions << "COALESCE(mr.data::jsonb ->> 'created_by_id', '') IN (:created_by_ids)"
      training_binds[:created_by_ids] = module_cluster_visible_vrp_ids.map(&:to_s)
    end

    fco_values = dashboard_summary_fco_filter_values(fcoc_value)
    if fco_values.present?
      training_conditions << "LOWER(COALESCE(mr.data::jsonb ->> 'trainee_department', '')) IN (:fco_values)"
      training_binds[:fco_values] = fco_values
    end

    sql = <<~SQL.squish
      SELECT COUNT(DISTINCT sf.farmer_id)
      FROM module_records mr
      CROSS JOIN LATERAL jsonb_array_elements_text(
        COALESCE(mr.data::jsonb -> 'selected_farmer_ids', '[]'::jsonb)
      ) AS sf(farmer_id)
      WHERE #{training_conditions.join(' AND ')}
    SQL

    ActiveRecord::Base.connection.select_value(
      ActiveRecord::Base.send(:sanitize_sql_array, [sql, training_binds])
    ).to_i
  rescue StandardError => e
    Rails.logger.warn("OPG achievement count failed: #{e.class} - #{e.message}")
    0
  end

  def dashboard_training_method_counts
    return training_method_count_defaults unless model_ready?(:TargetMapping) && model_ready?(:ModuleRecord)

    month_value = @participation_selected_month.presence || @dashboard_month_filter_value.presence
    fcoc_value = @participation_fcoc_filter_value.presence || @dashboard_fcoc_filter_value.presence || dashboard_filter_param(:fcoc, :fco)
    selected_vrp_id = dashboard_filter_param(:vrp_id)
    target_conditions = ["j.value <> ''"]
    unless dashboard_global_view_user?
      target_conditions << "t.vrp_id IN (#{Vrp.where(id: dashboard_visible_vrp_ids).select(:id).to_sql})"
    end
    target_binds = {}
    if month_value.present?
      target_conditions << "LOWER(BTRIM(t.month_name)) = :target_month"
      target_binds[:target_month] = normalize_dashboard_text(month_value)
    end
    target_conditions << "LOWER(BTRIM(t.main_activity_name)) = :target_main_activity"
    target_binds[:target_main_activity] = normalize_dashboard_text("Farmers' Training")
    if dashboard_filter_param(:sub_activity).present?
      target_conditions << "LOWER(BTRIM(t.activity_name)) = :target_sub_activity"
      target_binds[:target_sub_activity] = normalize_dashboard_text(dashboard_filter_param(:sub_activity))
    end
    fco_values = dashboard_summary_fco_filter_values(fcoc_value)
    target_conditions << "(LOWER(BTRIM(t.fco_name)) IN (:fco_values) OR LOWER(BTRIM(t.fco_id)) IN (:fco_values) OR LOWER(BTRIM(v.fcoc)) IN (:fco_values))"
    target_binds[:fco_values] = fco_values
    if selected_vrp_id.present?
      target_conditions << "t.vrp_id = :target_vrp_id"
      target_binds[:target_vrp_id] = selected_vrp_id.to_i
    elsif vrp_login_user? && current_vrp_record.present?
      target_conditions << "t.vrp_id = :target_vrp_id"
      target_binds[:target_vrp_id] = current_vrp_record.id
    elsif dashboard_agronomics_login?
      target_conditions << "t.vrp_id IN (:target_registered_vrp_ids)"
      target_binds[:target_registered_vrp_ids] = dashboard_registered_vrp_ids_for_current_user
    elsif dashboard_cc_vrp_scope_active?
      target_conditions << "t.vrp_id IN (:target_visible_vrp_ids)"
      target_binds[:target_visible_vrp_ids] = module_cluster_visible_vrp_ids
    end
    if dashboard_filter_param(:ics, :ics_name).present?
      target_conditions << "(LOWER(BTRIM(t.ics_name)) = :target_ics OR LOWER(BTRIM(t.ics_id)) = :target_ics)"
      target_binds[:target_ics] = normalize_dashboard_text(dashboard_filter_param(:ics, :ics_name))
    end

    training_conditions = ["mr.module_slug = 'training-form'", "sf.farmer_id <> ''"]
    if !dashboard_global_view_user? || dashboard_filter_param(:ics, :ics_name).present?
      training_conditions << "sf.farmer_id IN (#{dashboard_visible_farmer_scope.select('afls.id::text').to_sql})"
    end
    training_binds = {}
    if month_value.present?
      training_conditions << "LOWER(COALESCE(mr.data::jsonb ->> 'month', '')) = :training_month"
      training_binds[:training_month] = normalize_dashboard_text(month_value)
    end
    if selected_vrp_id.present?
      training_conditions << "mr.data::jsonb ->> 'created_by_id' = :created_by_id"
      training_binds[:created_by_id] = selected_vrp_id.to_s
    elsif vrp_login_user? && current_vrp_record.present?
      training_conditions << "mr.data::jsonb ->> 'created_by_id' = :created_by_id"
      training_binds[:created_by_id] = current_vrp_record.id.to_s
    elsif dashboard_agronomics_login?
      training_conditions << "COALESCE(mr.data::jsonb ->> 'created_by_id', '') IN (:created_by_ids)"
      training_binds[:created_by_ids] = dashboard_registered_vrp_ids_for_current_user.map(&:to_s)
    end

    sql = <<~SQL.squish
      WITH mapped_farmers AS MATERIALIZED (
        SELECT DISTINCT j.value AS afl_id
        FROM target_mappings t
        LEFT JOIN vrps v ON v.id = t.vrp_id
        CROSS JOIN LATERAL jsonb_array_elements_text(
          CASE
            WHEN jsonb_typeof(t.afl_ids::jsonb) = 'array' THEN t.afl_ids::jsonb
            ELSE jsonb_build_array(t.afl_ids::jsonb)
          END
        ) AS j(value)
        WHERE #{target_conditions.join(' AND ')}
      ),
      training_entries AS MATERIALIZED (
        SELECT DISTINCT
          sf.farmer_id,
          BTRIM(mr.data::jsonb ->> 'training_method') AS training_method
        FROM module_records mr
        CROSS JOIN LATERAL jsonb_array_elements_text(
          COALESCE(mr.data::jsonb -> 'selected_farmer_ids', '[]'::jsonb)
        ) AS sf(farmer_id)
        WHERE #{training_conditions.join(' AND ')}
      )
      SELECT
        COUNT(DISTINCT mf.afl_id) FILTER (WHERE te.training_method = 'General Training/Meeting') AS general_training_meeting,
        COUNT(DISTINCT mf.afl_id) FILTER (WHERE te.training_method = 'Input Demo INM') AS input_demo_inm,
        COUNT(DISTINCT mf.afl_id) FILTER (WHERE te.training_method = 'FFS') AS ffs,
        COUNT(DISTINCT mf.afl_id) FILTER (WHERE UPPER(te.training_method) = 'INPUT DEMO PM') AS input_demo_pm,
        COUNT(DISTINCT mf.afl_id) FILTER (WHERE UPPER(te.training_method) = 'OPG') AS opg
      FROM mapped_farmers mf
      LEFT JOIN training_entries te ON te.farmer_id = mf.afl_id
    SQL

    row = ActiveRecord::Base.connection.exec_query(
      ActiveRecord::Base.send(:sanitize_sql_array, [sql, target_binds.merge(training_binds)])
    ).first || {}
    {
      "General Training/Meeting" => row["general_training_meeting"].to_i,
      "Input Demo INM" => row["input_demo_inm"].to_i,
      "FFS" => row["ffs"].to_i,
      "Input Demo PM" => row["input_demo_pm"].to_i,
      "OPG" => row["opg"].to_i
    }
  rescue StandardError => e
    Rails.logger.warn("Dashboard training method counts failed: #{e.class} - #{e.message}")
    training_method_count_defaults
  end

  def training_method_count_defaults
    {
      "General Training/Meeting" => 0,
      "Input Demo INM" => 0,
      "FFS" => 0,
      "Input Demo PM" => 0,
      "OPG" => 0
    }
  end

  def dashboard_total_afl_village_count
    dashboard_total_afl_distinct_count(:village)
  end

  def dashboard_total_afl_farmer_count
    dashboard_total_afl_distinct_count(:farmer)
  end

  def dashboard_total_afl_ics_count
    dashboard_total_afl_distinct_count(:ics)
  end

  def dashboard_total_afl_distinct_count(kind)
    return 0 unless model_ready?(:Afl)

    case kind
    when :village
      # Matches: SELECT fco_id, fco, fpo_id, fpo_name, ics_id, ics_name, village_id, village_name, COUNT(tracenet_no) FROM afls WHERE fco_id = '1004' OR fco_id = '1006' GROUP BY fco_id, fco, fpo_id, fpo_name, ics_id, ics_name, village_id, village_name
      scope = dashboard_total_afl_farmer_scope.where.not(village_id: [nil, ""])
      groups = scope.select(:fco_id, :fco, :fpo_id, :fpo_name, :ics_id, :ics_name, :village_id, :village_name).distinct
      Afl.unscoped.from(groups, :afl_groups).count
    when :ics
      # Matches: SELECT fco_id, fco, fpo_id, fpo_name, ics_id, ics_name, COUNT(tracenet_no) FROM afls WHERE fco_id = '1004' OR fco_id = '1006' GROUP BY fco_id, fco, fpo_id, fpo_name, ics_id, ics_name
      scope = dashboard_total_afl_farmer_scope.where.not(ics_id: [nil, ""])
      groups = scope.select(:fco_id, :fco, :fpo_id, :fpo_name, :ics_id, :ics_name).distinct
      Afl.unscoped.from(groups, :afl_groups).count
    else
      # Farmer count: COUNT(tracenet_no) using fco_id ONLY — no name matching
      # Matches: SELECT COUNT(tracenet_no) FROM afls WHERE (fco_id = '1004' OR fco_id = '1006')
      farmer_scope = dashboard_total_afl_farmer_scope
      farmer_scope.count("NULLIF(BTRIM(tracenet_no), '')")
    end
  rescue StandardError => e
    Rails.logger.warn("Dashboard total AFL #{kind} count failed: #{e.class} - #{e.message}")
    0
  end

  # Farmer-count scope: filter strictly by fco_id (numeric IDs only), not by fco name.
  # This prevents name-based double-counting when some AFL rows have fco = 'FCO-C Sausar'
  # but a different fco_id, which would inflate the count.
  def dashboard_total_afl_farmer_scope
    scope = dashboard_visible_farmer_scope.where.not(id: nil)
    fcoc_value = @dashboard_fcoc_filter_value.presence || dashboard_filter_param(:fcoc, :fco)
    fco_values = dashboard_summary_fco_filter_values(fcoc_value)

    # Extract only the numeric-style fco_id values (e.g., '1004', '1006')
    fco_id_values = fco_values.select { |v| v.match?(/\A\d+\z/) }

    if fco_id_values.any?
      scope = scope.where("LOWER(BTRIM(COALESCE(fco_id, ''))) IN (:fco_id_values)", fco_id_values: fco_id_values)
    else
      # Fallback to standard name+id scope if no numeric IDs found
      scope = scope.where(
        "LOWER(BTRIM(COALESCE(fco, ''))) IN (:fco_values) OR LOWER(BTRIM(COALESCE(fco_id, ''))) IN (:fco_values)",
        fco_values: fco_values
      )
    end

    ics_value = dashboard_filter_param(:ics, :ics_name)
    if ics_value.present?
      normalized_ics = normalize_dashboard_text(ics_value)
      scope = scope.where(
        "LOWER(BTRIM(COALESCE(ics_name, ''))) = :ics OR LOWER(BTRIM(COALESCE(ics_id, ''))) = :ics",
        ics: normalized_ics
      )
    end

    scope
  end

  def dashboard_total_afl_scope
    scope = dashboard_visible_farmer_scope.where.not(id: nil)
    fcoc_value = @dashboard_fcoc_filter_value.presence || dashboard_filter_param(:fcoc, :fco)
    fco_values = dashboard_summary_fco_filter_values(fcoc_value)
    scope = scope.where(
      "LOWER(BTRIM(COALESCE(fco, ''))) IN (:fco_values) OR LOWER(BTRIM(COALESCE(fco_id, ''))) IN (:fco_values)",
      fco_values: fco_values
    )

    ics_value = dashboard_filter_param(:ics, :ics_name)
    if ics_value.present?
      normalized_ics = normalize_dashboard_text(ics_value)
      scope = scope.where(
        "LOWER(BTRIM(COALESCE(ics_name, ''))) = :ics OR LOWER(BTRIM(COALESCE(ics_id, ''))) = :ics",
        ics: normalized_ics
      )
    end

    scope
  end

  def dashboard_summary_fco_filter_values(fcoc_value = nil)
    fcoc_value = nil if normalize_dashboard_text(fcoc_value) == "all fco"
    selected_values = training_fcoc_filter_values(fcoc_value)
    return selected_values if selected_values.any?

    training_fcoc_filter_values("1004", "1006", "Sausar", "Turekela", "FCO-C Sausar", "FCO-C Turekela")
  end

  def dashboard_fco_active_vrp_count(fco_name_or_id, month_name = "August", vrps = nil)
    return 0 if fco_name_or_id.blank?

    selected_month = month_name.presence || "August"
    normalized = normalize_dashboard_text(fco_name_or_id)
    fco_conditions = if normalized.include?("1004") || normalized.include?("sausar")
                       "(LOWER(TRIM(t.fco_id)) IN ('1004', 'sausar') OR LOWER(TRIM(t.fco_name)) LIKE '%sausar%')"
                     elsif normalized.include?("1006") || normalized.include?("turekela")
                       "(LOWER(TRIM(t.fco_id)) IN ('1006', 'turekela') OR LOWER(TRIM(t.fco_name)) LIKE '%turekela%')"
                     else
                       "(LOWER(TRIM(t.fco_id)) = :norm OR LOWER(TRIM(t.fco_name)) = :norm)"
                     end

    sql = <<~SQL.squish
      SELECT COUNT(DISTINCT t.vrp_id) AS active_vrp_count
      FROM public.target_mappings t
      WHERE #{fco_conditions}
        AND LOWER(TRIM(t.month_name)) = :month_name
        AND t.vrp_id IS NOT NULL AND TRIM(t.vrp_id::text) != '';
    SQL

    binds = { norm: normalized, month_name: selected_month.strip.downcase }
    res = ActiveRecord::Base.connection.exec_query(
      ActiveRecord::Base.send(:sanitize_sql_array, [sql, binds])
    ).first
    count = res ? res["active_vrp_count"].to_i : 0

    return count if count > 0

    if vrps.present?
      matching_vrps = Array(vrps).select do |vrp|
        training_fcoc_text_matches?(vrp.fcoc, fco_name_or_id) &&
          (vrp.respond_to?(:is_active) ? (vrp.is_active == true || vrp.is_active == 1) : true) &&
          !(vrp.respond_to?(:is_deleted) && (vrp.is_deleted == true || vrp.is_deleted == 1))
      end
      return matching_vrps.count { |vrp| dashboard_vrp_active_for_requirement?(vrp) }
    end

    0
  rescue StandardError => e
    Rails.logger.warn("dashboard_fco_active_vrp_count SQL failed: #{e.message}")
    if vrps.present?
      matching_vrps = Array(vrps).select do |vrp|
        training_fcoc_text_matches?(vrp.fcoc, fco_name_or_id) &&
          (vrp.respond_to?(:is_active) ? (vrp.is_active == true || vrp.is_active == 1) : true) &&
          !(vrp.respond_to?(:is_deleted) && (vrp.is_deleted == true || vrp.is_deleted == 1))
      end
      matching_vrps.count { |vrp| dashboard_vrp_active_for_requirement?(vrp) }
    else
      0
    end
  end

  # The exact JJ set that the "FCO-wise JJ Requirement" Active count is built from:
  # distinct vrp_id having a target mapping in this FCO + month. Gender Count splits
  # this same set so the two always agree. Falls back to the fcoc/active-flag set
  # (same fallback the count uses) when no target mappings exist.
  def dashboard_fco_active_vrp_records(fco_name_or_id, month_name = "August", vrps = nil)
    return [] if fco_name_or_id.blank?

    selected_month = month_name.presence || "August"
    normalized = normalize_dashboard_text(fco_name_or_id)
    fco_conditions = if normalized.include?("1004") || normalized.include?("sausar")
                       "(LOWER(TRIM(t.fco_id)) IN ('1004', 'sausar') OR LOWER(TRIM(t.fco_name)) LIKE '%sausar%')"
                     elsif normalized.include?("1006") || normalized.include?("turekela")
                       "(LOWER(TRIM(t.fco_id)) IN ('1006', 'turekela') OR LOWER(TRIM(t.fco_name)) LIKE '%turekela%')"
                     else
                       "(LOWER(TRIM(t.fco_id)) = :norm OR LOWER(TRIM(t.fco_name)) = :norm)"
                     end

    sql = <<~SQL.squish
      SELECT DISTINCT t.vrp_id
      FROM public.target_mappings t
      WHERE #{fco_conditions}
        AND LOWER(TRIM(t.month_name)) = :month_name
        AND t.vrp_id IS NOT NULL AND TRIM(t.vrp_id::text) != ''
    SQL
    ids = ActiveRecord::Base.connection.exec_query(
      ActiveRecord::Base.send(:sanitize_sql_array, [sql, { norm: normalized, month_name: selected_month.strip.downcase }])
    ).rows.flatten.compact

    if ids.present?
      by_id = Array(vrps).index_by(&:id)
      missing = ids.map(&:to_i) - by_id.keys
      by_id.merge!(Vrp.where(id: missing).index_by(&:id)) if missing.any? && model_ready?(:Vrp)
      return ids.filter_map { |id| by_id[id.to_i] }
    end

    Array(vrps).select do |vrp|
      training_fcoc_text_matches?(vrp.fcoc, fco_name_or_id) &&
        (vrp.respond_to?(:is_active) ? (vrp.is_active == true || vrp.is_active == 1) : true) &&
        !(vrp.respond_to?(:is_deleted) && (vrp.is_deleted == true || vrp.is_deleted == 1)) &&
        dashboard_vrp_active_for_requirement?(vrp)
    end
  rescue StandardError => e
    Rails.logger.warn("dashboard_fco_active_vrp_records failed: #{e.message}")
    []
  end

  def dashboard_jj_requirement_items(fco_name, vrps, targets = nil)
    normalized_fco = normalize_dashboard_text(fco_name)
    fco_id = if normalized_fco.include?("1004") || normalized_fco.include?("sausar")
               "1004"
             elsif normalized_fco.include?("1006") || normalized_fco.include?("turekela")
               "1006"
             else
               nil
             end

    selected_month = params[:month].presence || params[:training_month].presence || "August"
    active_count   = dashboard_fco_active_vrp_count(fco_name, selected_month, vrps)

    if normalized_fco.include?("sausar") || fco_id == "1004"
      required_count = [34, active_count].max
    elsif normalized_fco.include?("turekela") || fco_id == "1006"
      required_count = [24, active_count].max
    else
      fco_targets    = Array(targets).select { |t| normalize_dashboard_text(t.fco_name).include?(normalized_fco) }
      req            = fco_targets.map { |t| normalize_dashboard_text(t.village_name) }.reject(&:blank?).uniq.size
      required_count = [req, active_count].max
    end

    vacant_count = [required_count - active_count, 0].max

    [
      { title: "#{fco_name} Required", value: required_count, path: target_mappings_path(fcoc: fco_name) },
      { title: "#{fco_name} Active", value: active_count, path: vrps_path(fcoc: fco_name, active_status: "active", approval_status: "final-approved") },
      { title: "#{fco_name} Vacant", value: vacant_count, path: vrps_path(fcoc: fco_name, active_status: "vacant") }
    ]
  end

  def dashboard_vrp_active_for_requirement?(vrp)
    return false unless vrp
    return false if vrp.respond_to?(:is_active) && !vrp.is_active
    return false if vrp.respond_to?(:is_deleted) && vrp.is_deleted

    dashboard_approved_vrps([vrp]).any?
  end

  def dashboard_distinct_target_array_count_for_fco(column_name, fco_name, targets: nil)
    conditions = []
    binds = {}
    target_ids = Array(targets).filter_map { |target| target.id if target.respond_to?(:id) }.uniq
    if targets
      return 0 if target_ids.blank?

      conditions << "t.id IN (:target_ids)"
      binds[:target_ids] = target_ids
    end
    if fco_name.present?
      normalized_fco = normalize_dashboard_text(fco_name)
      conditions << "(LOWER(BTRIM(t.fco_name)) LIKE :fco_name OR LOWER(BTRIM(v.fcoc)) LIKE :fco_name)"
      binds[:fco_name] = "%#{ActiveRecord::Base.sanitize_sql_like(normalized_fco)}%"
    end
    dashboard_distinct_target_array_count_sql(column_name, conditions, binds)
  end

  def dashboard_distinct_target_array_count(targets, column_name)
    target_ids = Array(targets).filter_map { |target| target.id if target.respond_to?(:id) }.uniq
    return 0 if target_ids.blank?

    dashboard_distinct_target_array_count_sql(column_name, ["t.id IN (:target_ids)"], target_ids: target_ids)
  end

  def dashboard_distinct_target_scalar_count(targets, column_name)
    target_ids = Array(targets).filter_map { |target| target.id if target.respond_to?(:id) }.uniq
    return 0 if target_ids.blank?

    sql = <<~SQL.squish
      SELECT COUNT(DISTINCT NULLIF(BTRIM(t.#{column_name}), ''))
      FROM target_mappings t
      WHERE t.id IN (:target_ids)
    SQL
    ActiveRecord::Base.connection.select_value(
      ActiveRecord::Base.send(:sanitize_sql_array, [sql, { target_ids: target_ids }])
    ).to_i
  end

  def dashboard_distinct_target_array_count_sql(column_name, conditions, binds)
    column_name = column_name.to_s
    return 0 unless %w[village_id afl_ids].include?(column_name)

    where_sql = Array(conditions).presence&.join(" AND ") || "1=1"
    sql = <<~SQL.squish
      SELECT COUNT(DISTINCT NULLIF(BTRIM(j.value), ''))
      FROM target_mappings t
      LEFT JOIN vrps v ON v.id = t.vrp_id
      CROSS JOIN LATERAL jsonb_array_elements_text(
        CASE
          WHEN BTRIM(COALESCE(t.#{column_name}, '')) LIKE '[%' THEN t.#{column_name}::jsonb
          ELSE jsonb_build_array(t.#{column_name})
        END
      ) AS j(value)
      WHERE #{where_sql}
    SQL
    ActiveRecord::Base.connection.select_value(
      ActiveRecord::Base.send(:sanitize_sql_array, [sql, binds])
    ).to_i
  rescue StandardError => e
    Rails.logger.warn("Dashboard distinct #{column_name} count failed: #{e.class} - #{e.message}")
    0
  end

  def dashboard_summary_farmer_status_counts(targets)
    farmer_states = Hash.new { |hash, farmer_id| hash[farmer_id] = { complete: 0, pending: 0 } }

    Array(targets).each do |target|
      assigned_ids = target_farmer_ids(target).map(&:to_s).reject(&:blank?).uniq
      next if assigned_ids.blank?

      completed_ids = completed_training_farmer_ids_for(target, assigned_ids).map(&:to_s).to_set
      assigned_ids.each do |farmer_id|
        state = farmer_states[farmer_id]
        if completed_ids.include?(farmer_id)
          state[:complete] += 1
        else
          state[:pending] += 1
        end
      end
    end

    {
      mapped: farmer_states.keys.size,
      complete: farmer_states.count { |_farmer_id, state| state[:complete].positive? },
      pending: farmer_states.count { |_farmer_id, state| state[:pending].positive? }
    }
  end

  def dashboard_summary_activity_entries(targets)
    Array(targets).flat_map do |target|
      entries = training_participation_target_activity_entries(target)
      entries.presence || [{ main_activity: target.main_activity_name.to_s, sub_activity: target.activity_name.to_s }]
    end.map do |entry|
      {
        main_activity_key: normalize_dashboard_text(entry[:main_activity]),
        sub_activity_key: normalize_dashboard_text(entry[:sub_activity])
      }
    end
  end

  def dashboard_summary_card(title, value, caption, path, export_path, popup_items: nil)
    dashboard_card(title, value, caption, path).merge(export_path: export_path, popup_items: Array(popup_items).compact_blank)
  end

  def dashboard_summary_activity_popup_items(summary_mode)
    return [] unless model_ready?(:TargetMapping)

    target_conditions, binds = dashboard_summary_target_sql_filters_base(include_activity_filters: false)
    select_clause = if summary_mode.to_sym == :main_activity
      "NULLIF(BTRIM(t.main_activity_name), '') AS activity_name, NULL AS parent_activity"
    else
      "NULLIF(BTRIM(t.activity_name), '') AS activity_name, NULLIF(BTRIM(t.main_activity_name), '') AS parent_activity"
    end

    sql = <<~SQL.squish
      SELECT #{select_clause}
      FROM target_mappings t
      LEFT JOIN vrps v ON v.id = t.vrp_id
      WHERE #{target_conditions.join(' AND ')}
      ORDER BY activity_name
    SQL

    items_by_key = {}
    ActiveRecord::Base.connection.exec_query(
      ActiveRecord::Base.send(:sanitize_sql_array, [sql, binds])
    ).map do |row|
      activity_name = row["activity_name"].to_s.strip
      next if activity_name.blank?

      parent_activity = row["parent_activity"].to_s.strip
      label = parent_activity.present? ? "#{activity_name} (#{parent_activity})" : activity_name
      key = [
        normalize_dashboard_text(activity_name),
        summary_mode.to_sym == :sub_activity ? normalize_dashboard_text(parent_activity) : nil
      ].compact.join("|")
      items_by_key[key] ||= label
    end

    items_by_key.values.compact.sort_by { |item| normalize_dashboard_text(item) }
  rescue StandardError => e
    Rails.logger.warn("Dashboard summary activity popup items failed: #{e.class} - #{e.message}")
    []
  end

  def dashboard_summary_target_params
    @dashboard_summary_target_params ||= begin
      target_params = params.permit(:main_activity, :sub_activity, :fcoc, :ics, :month, :vrp_id).to_h
        .reverse_merge(
        "month" => @dashboard_month_filter_value,
        "fcoc" => @dashboard_fcoc_filter_value
      )
      .compact_blank
      target_params["fco_id"] = %w[1004 1006] if target_params["fcoc"].blank?
      target_params
    end
  end

  def dashboard_summary_participation_params(status:, format: nil)
    params_hash = {
      status: status,
      training_month: @participation_selected_month,
      training_fcoc: @participation_fcoc_filter_value,
      main_activity: @dashboard_main_activity_filter_value.presence || dashboard_filter_param(:main_activity),
      training_sub_activity: dashboard_filter_param(:sub_activity),
      ics: dashboard_filter_param(:ics, :ics_name),
      format: format
    }.compact_blank
    params_hash[:fco_id] = %w[1004 1006] if params_hash[:training_fcoc].blank?
    params_hash
  end

  def dashboard_summary_afl_params
    params_hash = {}
    fcoc_value = @dashboard_fcoc_filter_value.presence || dashboard_filter_param(:fcoc, :fco)
    if fcoc_value.present?
      params_hash[:fcoc] = fcoc_value
    else
      params_hash[:fco_id] = %w[1004 1006]
    end
    params_hash[:ics] = dashboard_filter_param(:ics, :ics_name) if dashboard_filter_param(:ics, :ics_name).present?
    params_hash
  end

  def dashboard_summary_weekly_params(status:, format: nil)
    {
      status: status,
      training_month: @weekly_dashboard_selected_month,
      training_fcoc: @weekly_target_fcoc_filter_value,
      week: @weekly_target_week_filter_value,
      format: format
    }.compact_blank
  end

  # A target assignment can create one TargetMapping row per selected activity.
  # The Target Mapping list combines those rows into a single assignment, so the
  # dashboard uses the same assignment fields and stays in sync dynamically.
  def dashboard_target_record_count(targets)
    dashboard_target_assignment_groups(targets).size
  end

  def dashboard_target_assignment_groups(targets)
    group_key_counts = dashboard_target_mapping_group_key_counts(targets)
    Array(targets).group_by { |target| dashboard_target_assignment_key(target, group_key_counts) }.values
  end

  def dashboard_target_assignment_key(target, group_key_counts = nil)
    group_key = target.mapping_group_key.to_s.strip if target.respond_to?(:mapping_group_key)
    if group_key.present?
      group_key_counts ||= dashboard_target_mapping_group_key_counts(dashboard_target_mappings)
      return [:mapping_group_key, group_key] if group_key_counts[group_key].to_i > 1
    end

    dashboard_target_assignment_signature(target) + [
      normalize_dashboard_text(target.main_activity_name),
      normalize_dashboard_text(target.activity_name)
    ]
  end

  def dashboard_target_assignment_signature(target)
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
  end

  def dashboard_target_mapping_group_key_counts(targets)
    targets = Array(targets)
    @dashboard_target_mapping_group_key_counts_cache ||= {}
    cache_key = targets.map { |target| target.respond_to?(:id) ? target.id : target.object_id }.join(":")
    return @dashboard_target_mapping_group_key_counts_cache[cache_key] if @dashboard_target_mapping_group_key_counts_cache.key?(cache_key)

    @dashboard_target_mapping_group_key_counts_cache[cache_key] = targets.filter_map do |target|
      target.mapping_group_key.to_s.strip.presence if target.respond_to?(:mapping_group_key)
    end.tally
  end

  def dashboard_reports
    targets = @filtered_targets || dashboard_target_mappings
    hierarchy_summary = user_hierarchy_dashboard_summary

    reports = [
      {
        title: "VRP Target Summary",
        headers: ["Month", "Targets", "Target Quantity"],
        rows: dashboard_target_summary_rows(targets)
      },
      {
        title: "Live Clock",
        clock: true
      }
    ]

    reports.insert(0, user_hierarchy_dashboard_report(hierarchy_summary)) if hierarchy_summary[:total].positive?
    if admin_dashboard_user?
      reports.insert(0, vrp_assigned_target_report.merge(collapsible: true, collapsed: true))
      reports.insert(0, vrp_declaration_acceptance_report.merge(collapsible: true, collapsed: true))
    end
    reports
  end

  def dashboard_card(title, value, caption, path = nil)
    {
      title: title,
      value: value,
      caption: caption,
      path: path.presence || dashboard_path
    }
  end

  def dashboard_group_card(title, items, style: nil)
    {
      title: title,
      items: items,
      style: style
    }
  end

  # Billing cards use active bills visible to this login, independently of target filters.
  def dashboard_billing_records
    @dashboard_billing_records ||= ModuleRecord.where(module_slug: "jeevika-jankar-bill-process").to_a.select do |record|
      jeevika_jankar_bill_blocks_duplicate?(record) &&
        (admin_dashboard_user? || jeevika_jankar_bill_record_visible?(record))
    end
  end

  def dashboard_bill_approved?(record)
    jeevika_bill_status_label(record).to_s.downcase.include?("final approved")
  end

  def dashboard_bill_pending?(record)
    status = jeevika_bill_status_label(record).to_s
    return false unless status.downcase.include?("pending")
    return true if admin_dashboard_user?

    jeevika_bill_current_approver?(record)
  end

  def weekly_activity_target_status_cards(targets, month_name: nil, fcoc_name: nil, week_number: nil, include_activity_filters: true, participation_counts: nil)
    if week_number.blank? && !weekly_activity_other_targets?(targets)
      participation_counts ||= training_participation_dashboard_counts(
        month_name: month_name,
        fcoc_name: fcoc_name,
        records: dashboard_training_participation_records(month_name: month_name, fcoc_name: fcoc_name)
      )
      target_quantity = participation_counts[:total]
      completed_quantity = participation_counts[:green]
      partial_quantity = participation_counts[:yellow]
      pending_quantity = participation_counts[:red]
    else
      rows = weekly_activity_target_farmer_status_rows(targets, month_name: month_name, fcoc_name: fcoc_name, week_number: week_number)
      totals = weekly_activity_target_status_counts_for_rows(rows)
      target_quantity = training_mapped_farmer_distinct_count_for_participation(
        month_name: month_name,
        fcoc_name: fcoc_name,
        targets: targets
      )
      completed_quantity = totals[:green]
      partial_quantity = totals[:yellow]
      pending_quantity = totals[:red]
    end
    filter_params = dashboard_weekly_report_filter_params
    filter_params.except!(:activity, :training_sub_activity) unless include_activity_filters
    filter_params.delete(:training_month)
    filter_params[:training_month] = month_name if month_name.present?
    filter_params[:training_fcoc] = fcoc_name if fcoc_name.present?

    filter_params[:week] = week_number if week_number.present?

    [
      {
        status: "total",
        title: "Target Assigned",
        value: target_quantity.to_i,
        caption: "Distinct mapped farmers.",
        path: weekly_activity_target_report_path(filter_params.merge(status: "total"))
      },
      {
        status: "green",
        title: "1+ Trainings",
        value: completed_quantity.to_i,
        caption: "Farmer attended more than 1 training.",
        path: weekly_activity_target_report_path(filter_params.merge(status: "green"))
      },
      {
        status: "yellow",
        title: "Only 1 Training",
        value: partial_quantity.to_i,
        caption: "Farmer attended only 1 training.",
        path: weekly_activity_target_report_path(filter_params.merge(status: "yellow"))
      },
      {
        status: "red",
        title: "Pending",
        value: pending_quantity.to_i,
        caption: "Farmer not attended training. Missing training.",
        path: weekly_activity_target_report_path(filter_params.merge(status: "red"))
      }
    ]
  end

  def filter_weekly_activity_targets(targets, activity: nil, sub_activity: nil, fcoc: nil)
    filtered_targets = Array(targets)
    if activity.present?
      selected_activity = normalize_dashboard_text(activity)
      filtered_targets = filtered_targets.select do |target|
        dashboard_training_activity_text_matches?(selected_activity, normalize_dashboard_text(target.main_activity_name)) ||
          dashboard_training_activity_text_matches?(selected_activity, normalize_dashboard_text(target.activity_name)) ||
          dashboard_training_activity_text_matches?(normalize_dashboard_text(target.main_activity_name), selected_activity) ||
          dashboard_training_activity_text_matches?(normalize_dashboard_text(target.activity_name), selected_activity)
      end
    end
    if sub_activity.present?
      selected_sub_activity = normalize_dashboard_text(sub_activity)
      filtered_targets = filtered_targets.select do |target|
        normalize_dashboard_text(target.activity_name) == selected_sub_activity
      end
    end
    if fcoc.present?
      filtered_targets = filtered_targets.select do |target|
        training_target_matches_fcoc?(target, fcoc)
      end
    end
    filtered_targets
  end

  def weekly_activity_target_status_totals(targets, week_number: nil)
    weekly_activity_target_groups(targets).each_with_object({ target: 0.0, completed: 0.0, pending: 0.0 }) do |group, totals|
      assigned_ids = group.flat_map { |target| target_farmer_ids(target) }.map(&:to_s).reject(&:blank?).uniq
      if week_number.present?
        index = week_number - 1
        target_quantity = group.map { |target| Array(target.weekly_target_values)[index].to_f }.max.to_f
        completed_ids = unique_training_farmer_ids(group.flat_map do |target|
          Array(training_weekly_achievement_farmer_ids(target, target_farmer_ids(target)))[index] || []
        end) & assigned_ids
      else
        target_quantity = assigned_ids.any? ? assigned_ids.size.to_f : group.map { |target| weekly_activity_target_quantity(target) }.max.to_f
        completed_ids = unique_training_farmer_ids(group.flat_map do |target|
          completed_training_farmer_ids_for(target, target_farmer_ids(target))
        end) & assigned_ids
      end
      completed_quantity = [completed_ids.size.to_f, target_quantity].min
      totals[:target] += target_quantity
      totals[:completed] += completed_quantity
      totals[:pending] += [target_quantity - completed_quantity, 0].max
    end
  end

  def dashboard_weekly_activity_summary_totals(targets, participation_counts, week_number: nil)
    return weekly_activity_target_status_totals(targets, week_number: week_number) if week_number.present?
    return weekly_activity_target_status_totals(targets, week_number: week_number) if weekly_activity_other_targets?(targets)

    {
      target: participation_counts[:total].to_f,
      completed: participation_counts[:green].to_f + participation_counts[:yellow].to_f,
      pending: participation_counts[:red].to_f
    }
  end

  def weekly_activity_target_groups(targets)
    Array(targets).group_by do |target|
      dashboard_target_assignment_key(target) + [
        normalize_dashboard_text(target.main_activity_name),
        normalize_dashboard_text(target.activity_name)
      ]
    end.values
  end

  def weekly_activity_target_quantity(target)
    [
      target.target_quantity.to_f,
      target.farmer_count.to_f,
      Array(target.weekly_target_values).sum(&:to_f)
    ].max
  end

  def dashboard_weekly_report_filter_params
    params_hash = {
      training_month: params[:month].presence || params[:training_month].presence,
      main_activity: params[:main_activity].presence || @dashboard_main_activity_filter_value.presence,
      activity: params[:activity].presence || params[:main_activity].presence || @dashboard_main_activity_filter_value.presence,
      training_sub_activity: params[:training_sub_activity].presence || params[:sub_activity].presence,
      training_fcoc: params[:weekly_target_fcoc].presence || params[:fcoc].presence,
      week: params[:weekly_target_week].presence,
      cluster_incharge: params[:cluster_incharge].presence,
      post: params[:post].presence,
      vrp_id: params[:vrp_id].presence
    }.compact_blank
    params_hash[:fco_id] = %w[1004 1006] if params_hash[:training_fcoc].blank?
    params_hash
  end

  def weekly_activity_target_report_rows(targets, week_number: nil)
    training_target_status_rows(targets).map do |row|
      completion = row[:completion_date_sort]
      week_label = if completion.present?
        week_start = completion.beginning_of_week
        week_end = completion.end_of_week
        "Week #{completion.cweek} (#{week_start.strftime("%d-%m")} - #{week_end.strftime("%d-%m")})"
      else
        "-"
      end

      next row.merge(week: week_label) if week_number.blank?

      index = week_number - 1
      target_quantity = Array(row[:weekly_targets])[index].to_f
      completed_quantity = Array(row[:weekly_achievements])[index].to_f
      pending_quantity = [target_quantity - completed_quantity, 0].max
      progress_percent = target_quantity.positive? ? ((completed_quantity / target_quantity) * 100).round : 0
      status_class = training_target_status_for_percent(progress_percent)

      row.merge(
        week: "Week #{week_number}",
        target_quantity: target_quantity,
        completed_quantity: completed_quantity,
        pending_quantity: pending_quantity,
        progress_percent: progress_percent,
        status_class: status_class,
        status_label: training_target_status_label(status_class)
      )
    end
  end

  def weekly_activity_target_farmer_status_rows(targets, month_name: nil, fcoc_name: nil, week_number: nil)
    targets = Array(targets)
    if weekly_activity_other_targets?(targets)
      other_targets, training_targets = weekly_activity_partition_targets(targets)
      other_rows = weekly_activity_other_target_status_rows(other_targets, week_number: week_number)
      return other_rows if training_targets.blank?

      return other_rows + weekly_activity_target_farmer_status_rows(
        training_targets,
        month_name: month_name,
        fcoc_name: fcoc_name,
        week_number: week_number
      )
    end

    records = dashboard_training_participation_records(month_name: month_name, fcoc_name: fcoc_name)
    rows = training_participation_population_rows(
      month_name: month_name,
      fcoc_name: fcoc_name,
      records: records,
      targets: targets,
      week_number: week_number
    )
    week_label = week_number.present? ? "Week #{week_number}" : "All Weeks"

    rows.map do |row|
      assigned_count = row[:assigned_activity_count].to_i
      completed_count = row[:completed_activity_count].to_i
      progress_percent = assigned_count.positive? ? ((completed_count.to_f / assigned_count) * 100).round : 0
      status_class = row[:status].to_s
      target_quantity = 1
      completed_quantity = %w[green yellow].include?(status_class) ? 1 : 0
      pending_quantity = status_class == "red" ? 1 : 0

      row.merge(
        week: week_label,
        month: row[:months],
        completion_date: "-",
        vrp: row[:vrp],
        main_activity: row[:main_activities],
        sub_activity: row[:sub_activities],
        fco: row[:fcoc],
        cluster_incharge: row[:cluster_incharge],
        post: row[:jeevika_jankar_name],
        target_owner: row[:jeevika_jankar_name],
        registered_by: row[:registered_by],
        target_quantity: target_quantity,
        completed_quantity: completed_quantity,
        pending_quantity: pending_quantity,
        progress_percent: progress_percent,
        status_class: status_class,
        status_label: training_target_status_label(status_class),
        training_register_urls: row[:training_register_urls],
        training_photo_urls: row[:training_photo_urls]
      )
    end
  end

  def weekly_activity_other_targets?(targets)
    Array(targets).any? { |target| weekly_activity_other_target?(target) }
  end

  def weekly_activity_partition_targets(targets)
    Array(targets).partition { |target| weekly_activity_other_target?(target) }
  end

  def weekly_activity_other_target?(target)
    activity_settings = jeevika_jankar_main_activity_settings
    sub_activity_settings = jeevika_jankar_sub_activity_settings(activity_settings)
    setting = jeevika_jankar_activity_setting_for(target, activity_settings, sub_activity_settings)
    setting.present? && !training_main_activity_type?(setting[:main_activity_type])
  end

  def weekly_activity_other_target_status_rows(targets, week_number: nil)
    week_label = week_number.present? ? "Week #{week_number}" : "All Weeks"
    achievement_index = approved_other_target_achievement_index

    Array(targets).filter_map do |target|
      farmer_ids = target_farmer_ids(target)
      weekly_targets = target.respond_to?(:weekly_target_values) ? target.weekly_target_values.map(&:to_f) : [0, 0, 0, 0]
      target_quantity = if week_number.present?
        weekly_targets[week_number.to_i - 1].to_f
      else
        farmer_ids.size.nonzero? || target.target_quantity.to_f
      end
      target_quantity = target.target_quantity.to_f if target_quantity.to_f.zero? && week_number.blank?
      next if target_quantity.to_f.zero?

      achievement = weekly_other_target_achievement_for(target, achievement_index[target.id.to_s], week_number: week_number)
      completed_quantity = [achievement.to_f, target_quantity.to_f].min
      pending_quantity = [target_quantity.to_f - completed_quantity, 0].max
      status_class = if target_quantity.to_f.positive? && completed_quantity >= target_quantity.to_f
        "green"
      elsif completed_quantity.positive?
        "yellow"
      else
        "red"
      end

      {
        week: week_label,
        farmer_id: "-",
        farmer_name: "-",
        father_name: nil,
        mobile_no: nil,
        tracenet_no: nil,
        khasara_no: nil,
        ics: target_ics_label(target).presence || "-",
        village: target_village_label(target).presence || "-",
        vrp: target.vrp&.name.presence || "-",
        month: target.month_name.presence || "-",
        completion_date: target.completion_date&.strftime("%d-%m-%Y") || "-",
        main_activity: target.main_activity_name.presence || "-",
        sub_activity: target.activity_name.presence || "-",
        fco: target.fco_name.presence || target.fco_id.presence || "-",
        cluster_incharge: target.vrp&.cluster_incharge.presence || "-",
        post: target.vrp&.name.presence || "-",
        target_owner: target.vrp&.name.presence || "-",
        registered_by: target_mapping_registered_by_name(target),
        target_quantity: target_quantity,
        completed_quantity: completed_quantity,
        pending_quantity: pending_quantity,
        progress_percent: target_quantity.to_f.positive? ? ((completed_quantity / target_quantity.to_f) * 100).round : 0,
        status_class: status_class,
        status_label: training_target_status_label(status_class),
        training_register_urls: [],
        training_photo_urls: []
      }
    end
  end

  def weekly_other_target_achievement_for(target, achievement, week_number: nil)
    return 0.0 if achievement.blank?
    return achievement[:achievement].to_f if week_number.blank?

    dates = achievement[:achieved_at].to_s.split(",").map { |date| parse_module_date(date.strip) }.compact
    return 0.0 if dates.blank?

    dates.any? { |date| [((date.day - 1) / 7) + 1, 4].min == week_number.to_i } ? achievement[:achievement].to_f : 0.0
  end

  def weekly_activity_target_report_csv(rows)
    CSV.generate(headers: true) do |csv|
      csv << [
        "Week",
        "Month",
        "Completion Date",
        "Jeevika Jankar Name",
        "FCO",
        "Cluster Incharge",
        "Registered By",
        "Main Activity",
        "Sub Activity",
        "ICS",
        "Village",
        "FCOC",
        "ClusterCoordinator",
        "Target",
        "Completed",
        "Pending",
        "Progress %",
        "Status",
        "Training Register Upload",
        "Training Photo Upload with Geo Tag"
      ]

      Array(rows).each do |row|
        csv << [
          row[:week],
          row[:month],
          row[:completion_date],
          row[:vrp],
          row[:fco],
          row[:cluster_incharge],
          row[:registered_by],
          row[:main_activity],
          row[:sub_activity],
          row[:ics],
          row[:village],
          row[:fco].presence || row[:fcoc],
          row[:cluster_incharge],
          dashboard_quantity(row[:target_quantity]),
          dashboard_quantity(row[:completed_quantity]),
          dashboard_quantity(row[:pending_quantity]),
          row[:progress_percent],
          row[:status_label],
          Array(row[:training_register_urls]).join(", "),
          Array(row[:training_photo_urls]).join(", ")
        ]
      end
    end
  end

  def weekly_activity_target_status_counts_for_rows(rows)
    Array(rows).each_with_object({ green: 0.0, yellow: 0.0, red: 0.0, total: 0.0 }) do |row, counts|
      counts[:total] += row[:target_quantity].to_f
      status = row[:status_class].to_s.to_sym
      next unless counts.key?(status)

      counts[status] += if status == :green
        row[:completed_quantity].to_f
      elsif status == :yellow
        row[:completed_quantity].to_f
      elsif status == :red
        row[:pending_quantity].to_f
      else
        0.0
      end
    end
  end

  def weekly_progress_export_value(row, index)
    achieved = Array(row[:weekly_achievements])[index].to_f
    target = Array(row[:weekly_targets])[index].to_f
    "#{dashboard_quantity(achieved)} / #{dashboard_quantity(target)}"
  end

  def dashboard_participation_targets
    if vrp_login_user?
      current_vrp_record.present? ? vrp_dashboard_targets(current_vrp_record) : []
    else
      dashboard_target_mappings
    end
  end

  def training_participation_targets_for_dashboard(month_name: nil, fcoc_name: nil, main_activity_name: nil, sub_activity_name: nil)
    @training_participation_targets_cache ||= {}
    cache_key = [normalize_dashboard_text(month_name), normalize_dashboard_text(fcoc_name), normalize_dashboard_text(main_activity_name), normalize_dashboard_text(sub_activity_name)]
    return @training_participation_targets_cache[cache_key] if @training_participation_targets_cache.key?(cache_key)

    targets = dashboard_participation_targets
    targets = training_participation_active_vrp_targets(targets)
    if dashboard_filter_param(:ics, :ics_name).present?
      selected_ics = normalize_dashboard_text(dashboard_filter_param(:ics, :ics_name))
      targets = targets.select { |target| [target.ics_id, target.ics_name].any? { |value| normalize_dashboard_text(value) == selected_ics } }
    end

    targets = dashboard_targets_for_month(targets, month_name) if month_name.present?
    if fcoc_name.present?
      targets = Array(targets).select { |target| training_target_matches_fcoc?(target, fcoc_name) }
    end
    if main_activity_name.present?
      normalized_main_activity = normalize_dashboard_text(main_activity_name)
      targets = Array(targets).select { |target| normalize_dashboard_text(target.main_activity_name) == normalized_main_activity }
    end
    if sub_activity_name.present?
      normalized_sub_activity = normalize_dashboard_text(sub_activity_name)
      targets = Array(targets).select { |target| normalize_dashboard_text(target.activity_name) == normalized_sub_activity }
    end
    @training_participation_targets_cache[cache_key] = targets
  end

  def training_participation_active_vrp_targets(targets)
    Array(targets).select do |target|
      vrp = target.respond_to?(:vrp) ? target.vrp : nil
      dashboard_vrp_active_for_requirement?(vrp)
    end
  end

  def dashboard_training_participation_records(month_name: nil, main_activity_name: nil, sub_activity_name: nil, fcoc_name: nil)
    return [] unless model_ready?(:ModuleRecord)

    @dashboard_training_participation_records_cache ||= {}
    cache_key = [normalize_dashboard_text(month_name), normalize_dashboard_text(main_activity_name), normalize_dashboard_text(sub_activity_name), normalize_dashboard_text(fcoc_name)]
    return @dashboard_training_participation_records_cache[cache_key] if @dashboard_training_participation_records_cache.key?(cache_key)

    targets = training_participation_targets_for_dashboard(month_name: month_name, fcoc_name: fcoc_name, main_activity_name: main_activity_name, sub_activity_name: sub_activity_name)
    farmer_ids = training_participation_valid_farmer_ids_for_targets(targets)
    records = active_module_records_scope("training-form").order(created_at: :desc)
    if month_name.present?
      records = records.where("LOWER(BTRIM(data::jsonb ->> 'month')) = ?", month_name.to_s.strip.downcase)
    end
    records = training_record_scope_for_farmer_ids(records, farmer_ids) if farmer_ids.any?
    records = records
      .select { |record| training_record_countable?(record) }
      .select { |record| module_record_visible_for_current_context?(record) }
      .select { |record| training_record_main_activity_type?(record) }
      .select { |record| training_record_selected_farmer_ids(record).any? }
      .select { |record| month_name.blank? || normalize_dashboard_text(training_record_month_name(record)) == normalize_dashboard_text(month_name) }
      .select { |record| main_activity_name.blank? || normalize_dashboard_text(training_summary(record)[:training_topic]) == normalize_dashboard_text(main_activity_name) }
      .select { |record| sub_activity_name.blank? || normalize_dashboard_text(training_summary(record)[:training_subject]) == normalize_dashboard_text(sub_activity_name) }
      .select { |record| fcoc_name.blank? || training_record_matches_fcoc?(record, fcoc_name) }

    if vrp_login_user?
      vrp = current_vrp_record
      records = vrp ? records.select { |record| training_record_matches_vrp?(record, vrp) } : []
    end

    if @filtered_vrps.present?
      records = records.select do |record|
        @filtered_vrps.any? { |vrp| training_record_matches_vrp?(record, vrp) }
      end
    end

    preload_training_target_mappings_for_records!(records)
    @dashboard_training_participation_records_cache[cache_key] = records
  end

  def training_record_scope_for_farmer_ids(scope, farmer_ids)
    farmer_ids = Array(farmer_ids).map(&:to_s).reject(&:blank?).uniq
    return scope if farmer_ids.blank?

    # Use the GIN lookup for string IDs, retaining legacy numeric JSON IDs.
    # The old text expansion matched both representations.
    scope.where(
      <<~SQL.squish,
        (data::jsonb -> 'selected_farmer_ids' ?| array[:farmer_ids]
         OR (jsonb_path_exists(data::jsonb -> 'selected_farmer_ids', '$[*] ? (@.type() == "number")')
             AND EXISTS (
               SELECT 1 FROM jsonb_array_elements_text(data::jsonb -> 'selected_farmer_ids') AS selected(id)
               WHERE selected.id IN (:farmer_ids)
             )))
      SQL
      farmer_ids: farmer_ids
    )
  end

  def training_afl_farmer_rows_for_participation(month_name: nil, fcoc_name: nil)
    return [] unless model_ready?(:Afl)

    @training_afl_farmer_rows_cache ||= {}
    cache_key = [normalize_dashboard_text(month_name), normalize_dashboard_text(fcoc_name)]
    return @training_afl_farmer_rows_cache[cache_key] if @training_afl_farmer_rows_cache.key?(cache_key)

    targets = training_participation_targets_for_dashboard(
      month_name: month_name,
      fcoc_name: fcoc_name
    )

    assigned_farmer_ids = training_participation_valid_farmer_ids_for_targets(targets)
    return [] if assigned_farmer_ids.blank?

    # Participation belongs to the farmers assigned to the visible VRPs.
    farmer_scope = Afl.where(id: assigned_farmer_ids)
    assignments_by_farmer_key = Hash.new do |hash, key|
      hash[key] = {
        assigned_activity_keys: [],
        main_activities: [],
        sub_activities: [],
        months: [],
        vrp: []
      }
    end
    targets.each do |target|
      training_participation_target_farmer_ids(target).each do |farmer_id|
        farmer_key = training_participation_target_farmer_key(farmer_id)
        assignments_by_farmer_key[farmer_key][:assigned_activity_keys] |= training_participation_target_activity_keys(target)
        assignments_by_farmer_key[farmer_key][:main_activities] |= [target.main_activity_name.to_s.strip].reject(&:blank?)
        assignments_by_farmer_key[farmer_key][:sub_activities] |= [target.activity_name.to_s.strip].reject(&:blank?)
        assignments_by_farmer_key[farmer_key][:months] |= [target.month_name.to_s.strip].reject(&:blank?)
        assignments_by_farmer_key[farmer_key][:vrp] |= [target.vrp&.name.to_s.strip].reject(&:blank?)
      end
    end

    rows = farmer_scope.order(:id).each_with_object({}) do |farmer, rows_by_key|
      farmer_key = training_participation_target_farmer_key(farmer.id)
      rows_by_key[farmer_key] ||= {
        farmer_key: farmer_key,
        farmer_id: farmer.id.to_s,
        source_farmer_ids: [],
        farmer_name: dashboard_text_value(farmer.farmer_name).presence || "Farmer ##{farmer.id}",
        father_name: dashboard_text_value(farmer.father_name),
        mobile_no: dashboard_text_value(farmer.mobile_no),
        tracenet_no: dashboard_text_value(farmer.tracenet_no),
        khasara_no: dashboard_text_value(farmer.khasara_no),
        ics: dashboard_text_value(farmer.ics_name).presence || dashboard_text_value(farmer.ics_id).presence || "-",
        village: dashboard_text_value(farmer.village_name).presence || dashboard_text_value(farmer.village_id).presence || "-",
        vrp: assignments_by_farmer_key[farmer_key][:vrp].join(", ").presence || "-",
        months: assignments_by_farmer_key[farmer_key][:months].join(", ").presence || month_name.presence || "-",
        main_activities: assignments_by_farmer_key[farmer_key][:main_activities].join(", ").presence || "-",
        sub_activities: assignments_by_farmer_key[farmer_key][:sub_activities].join(", ").presence || "-",
        attendance_count: 0,
        assigned_activity_count: assignments_by_farmer_key[farmer_key][:assigned_activity_keys].size,
        completed_activity_count: 0,
        status: "unique",
        status_label: "AFL Farmer",
        training_dates: "-",
        last_training_date: "-",
        training_register_urls: [],
        training_photo_urls: []
      }
      rows_by_key[farmer_key][:source_farmer_ids] |= [farmer.id.to_s]
    end.values.sort_by { |row| row[:farmer_name].to_s.downcase }
    @training_afl_farmer_rows_cache[cache_key] = rows
  end

  def training_participation_population_rows(month_name:, fcoc_name:, records:, targets: nil, week_number: nil)
    targets ||= training_participation_targets_for_dashboard(month_name: month_name, fcoc_name: fcoc_name)
    targets = training_participation_targets_for_week(targets, week_number) if week_number.present?
    memberships = training_participation_target_memberships(targets)
    return [] if memberships.blank?

    attendance_details = training_attendance_details_for_targets(targets, month_name: month_name, week_number: week_number)
    farmers_by_id = training_farmers_by_id(training_participation_valid_farmer_ids_for_targets(targets))

    rows = memberships.map do |membership_key, membership|
      farmer_id = membership[:farmer_id].to_s
      farmer = farmers_by_id[farmer_id]
      details = attendance_details[membership_key] || { attendance_count: 0, training_dates: "", completed_activity_keys: [] }
      assigned_activity_count = membership[:assigned_activity_count].to_i
      completed_activity_count = [Array(details[:completed_activity_keys]).size, assigned_activity_count].min
      attendance_count = details[:attendance_count].to_i

      # Green: completed > 0 AND has repeat training (attendance > 1)
      # Yellow: completed > 0 AND no repeat training
      # Red: no completed activity
      status = if membership[:pending_available] && assigned_activity_count.zero?
                 "pending"
               elsif completed_activity_count.zero?
                 "red"
               elsif attendance_count > 1
                 "green"
               else
                 "yellow"
               end
      {
        farmer_key: membership_key,
        farmer_id: farmer_id,
        source_farmer_ids: Array(membership[:source_farmer_ids].to_s.split(",")).map(&:strip).reject(&:blank?),
        farmer_name: dashboard_text_value(farmer&.farmer_name).presence || "Farmer ##{farmer_id}",
        father_name: dashboard_text_value(farmer&.father_name),
        mobile_no: dashboard_text_value(farmer&.mobile_no),
        tracenet_no: dashboard_text_value(farmer&.tracenet_no),
        khasara_no: dashboard_text_value(farmer&.khasara_no),
        ics: membership[:ics].presence || dashboard_text_value(farmer&.ics_name).presence || dashboard_text_value(farmer&.ics_id).presence || "-",
        village: membership[:village].presence || dashboard_text_value(farmer&.village_name).presence || dashboard_text_value(farmer&.village_id).presence || "-",
        vrp: membership[:vrp].presence || "-",
        fcoc: membership[:fcoc].presence || "-",
        cluster_incharge: membership[:cluster_incharge].presence || "-",
        jeevika_jankar_name: membership[:jeevika_jankar_name].presence || membership[:vrp].presence || "-",
        target_owner: membership[:jeevika_jankar_name].presence || membership[:vrp].presence || "-",
        registered_by: membership[:registered_by].presence || "-",
        months: membership[:months].presence || month_name.presence || "-",
        main_activities: membership[:main_activities].presence || "-",
        sub_activities: membership[:sub_activities].presence || "-",
        attendance_count: attendance_count,
        assigned_activity_count: assigned_activity_count,
        completed_activity_count: completed_activity_count,
        status: status,
        status_label: training_participation_status_label(status),
        training_dates: details[:training_dates].presence || "-",
        last_training_date: details[:last_training_date].presence || "-",
        training_register_urls: [],
        training_photo_urls: []
      }
    end

    rows = rows.select { |row| row[:attendance_count].to_i.positive? } if week_number.present?
    rows.sort_by { |row| [row[:status], -row[:completed_activity_count].to_i, row[:farmer_name].to_s.downcase] }
  end

  def training_participation_targets_for_week(targets, week_number)
    week_index = week_number.to_i - 1
    return Array(targets) unless (0..3).include?(week_index)

    Array(targets).select do |target|
      Array(target.weekly_target_values)[week_index].to_i.positive?
    end
  end

  # Dashboard boxes only need counts. Avoid materializing thousands of AFL
  # objects and their display hashes; the dedicated list page still builds the
  # full farmer rows when the user opens a box.
  def cached_training_participation_dashboard_counts(month_name:, fcoc_name:, week_number: nil)
    cache_key = training_participation_dashboard_counts_cache_key(month_name: month_name, fcoc_name: fcoc_name, week_number: week_number)
    return training_participation_dashboard_counts_uncached(month_name: month_name, fcoc_name: fcoc_name, week_number: week_number) if cache_key.blank?

    DashboardCacheFill.synchronize(cache_key) do
      Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
        training_participation_dashboard_counts_uncached(month_name: month_name, fcoc_name: fcoc_name, week_number: week_number)
      end
    end
  end

  def training_participation_dashboard_counts_uncached(month_name:, fcoc_name:, week_number: nil)
    participation_targets = training_participation_targets_for_dashboard(month_name: month_name, fcoc_name: fcoc_name)
    if week_number.blank?
      sql_counts = training_participation_dashboard_counts_from_sql(month_name: month_name, fcoc_name: fcoc_name, targets: participation_targets)
      return sql_counts if sql_counts.present?
    end

    participation_records = dashboard_training_participation_records(month_name: month_name, fcoc_name: fcoc_name)
    participation_records = participation_records.select { |record| training_record_week_number(record) == week_number.to_i } if week_number.present?
    participation_targets = training_participation_targets_for_week(participation_targets, week_number) if week_number.present?
    training_participation_dashboard_counts(
      month_name: month_name,
      fcoc_name: fcoc_name,
      records: participation_records,
      targets: participation_targets,
      week_number: week_number
    )
  end

  def training_participation_dashboard_counts_cache_key(month_name:, fcoc_name:, week_number: nil)
    return unless model_ready?(:TargetMapping) && model_ready?(:ModuleRecord)

    scope_signature = [
      current_app_user&.dig("record_type"),
      current_app_user&.dig("id"),
      current_app_user&.dig("username"),
      admin_dashboard_user?,
      vrp_login_user?,
      module_mapped_vrp_scope_active? ? module_cluster_visible_vrp_id_strings.sort.join(",") : nil
    ].join(":")
    target_version = dashboard_table_version(TargetMapping)
    training_version = dashboard_module_record_version("training-form")
    afl_version = dashboard_table_version(Afl)
    vrp_version = dashboard_table_version(Vrp)

    [
      "dashboard/training-participation-counts/v7",
      normalize_dashboard_text(dashboard_filter_param(:ics, :ics_name)),
      normalize_dashboard_text(month_name),
      normalize_dashboard_text(fcoc_name),
      week_number.presence,
      scope_signature,
      target_version,
      training_version,
      afl_version,
      vrp_version
    ].join("/")
  rescue StandardError => e
    Rails.logger.warn("Dashboard counts cache key failed: #{e.class} - #{e.message}")
    nil
  end

  def dashboard_table_version(model_class)
    return unless model_ready?(model_class.name)

    Rails.cache.fetch(["dashboard/table-version", model_class.table_name], expires_in: 1.minute) do
      version = model_class.pick(Arel.sql("COUNT(*)"), Arel.sql("COALESCE(MAX(id), 0)"), Arel.sql("COALESCE(EXTRACT(EPOCH FROM MAX(updated_at))::bigint, 0)"))
      version.join(":")
    end
  end

  def dashboard_module_record_version(module_slug)
    return unless model_ready?(:ModuleRecord)

    Rails.cache.fetch(["dashboard/module-record-version", module_slug], expires_in: 1.minute) do
      version = ModuleRecord.where(module_slug: module_slug).pick(Arel.sql("COUNT(*)"), Arel.sql("COALESCE(MAX(id), 0)"), Arel.sql("COALESCE(EXTRACT(EPOCH FROM MAX(updated_at))::bigint, 0)"))
      version.join(":")
    end
  end

  def training_participation_dashboard_counts(month_name:, fcoc_name:, records:, targets: nil, week_number: nil)
    targets ||= training_participation_targets_for_dashboard(month_name: month_name, fcoc_name: fcoc_name)
    targets = training_participation_targets_for_week(targets, week_number) if week_number.present?
    sql_counts = training_participation_dashboard_counts_from_sql(month_name: month_name, fcoc_name: fcoc_name, targets: targets) if week_number.blank?
    return sql_counts if sql_counts.present?

    if week_number.present?
      rows = training_participation_population_rows(
        month_name: month_name,
        fcoc_name: fcoc_name,
        records: records,
        targets: targets,
        week_number: week_number
      )

      return {
        green: rows.count { |row| row[:status] == "green" },
        yellow: rows.count { |row| row[:status] == "yellow" },
        red: rows.count { |row| row[:status] == "red" },
        pending: 0,
        completed: rows.count { |row| row[:status] == "green" },
        completed_target_map_total: rows.sum { |row| row[:completed_activity_count].to_i },
        registered_farmer_total: training_registered_afl_farmer_count_for_participation(targets, fcoc_name: fcoc_name),
        total: rows.size,
        target_map_total: rows.sum { |row| row[:assigned_activity_count].to_i }
      }
    end

    memberships = training_participation_target_memberships(targets)
    mapped_farmer_total = training_mapped_farmer_distinct_count_for_participation(
      month_name: month_name,
      fcoc_name: fcoc_name,
      targets: targets
    )
    if memberships.blank?
      counts = { green: 0, yellow: 0, red: 0, pending: 0, completed: 0, total: 0 }
      counts[:registered_farmer_total] = training_registered_afl_farmer_count_for_participation(targets, fcoc_name: fcoc_name)
      counts[:target_map_total] = 0
      counts[:completed_target_map_total] = 0
      counts[:total] = mapped_farmer_total
      return counts
    end

    completed_activity_keys = Hash.new { |hash, key| hash[key] = [] }
    attendance_record_ids = Hash.new { |hash, key| hash[key] = Set.new }
    target_sets = Array(targets).filter_map do |target|
      farmer_ids = training_participation_target_farmer_ids(target)
      farmer_ids.blank? ? nil : [target, farmer_ids]
    end
    target_sets_by_farmer_id = Hash.new { |hash, key| hash[key] = [] }
    target_sets.each do |target_set|
      _target, farmer_ids = target_set
      farmer_ids.each { |farmer_id| target_sets_by_farmer_id[farmer_id.to_s] << target_set }
    end

    Array(records).each do |record|
      selected_farmer_ids = training_record_selected_farmer_ids(record)
      candidate_target_sets = selected_farmer_ids.flat_map { |farmer_id| target_sets_by_farmer_id[farmer_id.to_s] }.uniq
      candidate_target_sets.each do |target, farmer_ids|
        next unless training_record_matches_dashboard_target?(record, target, farmer_ids)

        (selected_farmer_ids & farmer_ids).each do |farmer_id|
          farmer_key = training_participation_target_farmer_key(farmer_id)
          membership_key = training_participation_membership_key(farmer_key, target.month_name)
          attendance_record_ids[membership_key] << record.id.to_s
          completed_activity_keys[membership_key] |= training_record_completed_activity_keys_for_target(record, target)
        end
      end
    end

    counts = {
      green: 0,
      yellow: 0,
      red: 0,
      pending: 0,
      completed: 0,
      completed_target_map_total: 0,
      registered_farmer_total: training_registered_afl_farmer_count_for_participation(targets, fcoc_name: fcoc_name),
      total: mapped_farmer_total,
      target_map_total: memberships.values.sum { |membership| membership[:assigned_activity_count].to_i }
    }
    memberships.each do |membership_key, membership|
      assigned_count = membership[:assigned_activity_count].to_i
      completed_count = [completed_activity_keys[membership_key].size, assigned_count].min
      attendance_count = attendance_record_ids[membership_key].size
      counts[:completed_target_map_total] += completed_count

      # Green: completed at least 1 activity AND has repeat training (attended >1 times)
      # Yellow: completed at least 1 activity but NO repeat training
      # Red: no completed activity at all
      status = if membership[:pending_available] && assigned_count.zero?
                 "pending"
               elsif completed_count.zero?
                 "red"
               elsif attendance_count > 1
                 "green"
               else
                 "yellow"
               end
      counts[status.to_sym] += 1 if counts.key?(status.to_sym)
    end
    counts
  end

  def training_participation_dashboard_counts_from_sql(month_name:, fcoc_name:, targets:)
    return nil unless model_ready?(:TargetMapping) && model_ready?(:ModuleRecord)

    target_conditions = ["j.value <> ''"]
    unless dashboard_global_view_user?
      target_conditions << "t.vrp_id IN (#{Vrp.where(id: dashboard_visible_vrp_ids).select(:id).to_sql})"
    end
    target_binds = {}
    if dashboard_filter_param(:ics, :ics_name).present?
      target_conditions << "(LOWER(BTRIM(t.ics_id)) = :participation_ics OR LOWER(BTRIM(t.ics_name)) = :participation_ics)"
      target_binds[:participation_ics] = normalize_dashboard_text(dashboard_filter_param(:ics, :ics_name))
    end


    if month_name.present?
      target_conditions << "LOWER(TRIM(t.month_name)) = :participation_month"
      target_binds[:participation_month] = normalize_dashboard_text(month_name)
    end

    if fcoc_name.present?
      fco_values = training_fcoc_filter_values(fcoc_name)
      target_conditions << "(LOWER(BTRIM(t.fco_name)) IN (:participation_fco_values) OR LOWER(BTRIM(t.fco_id)) IN (:participation_fco_values) OR LOWER(BTRIM(v.fcoc)) IN (:participation_fco_values))"
      target_binds[:participation_fco_values] = fco_values
    end

    if vrp_login_user? && current_vrp_record.present?
      target_conditions << "t.vrp_id = :participation_vrp_id"
      target_binds[:participation_vrp_id] = current_vrp_record.id
    elsif dashboard_agronomics_login?
      target_conditions << "t.vrp_id IN (:participation_vrp_ids)"
      target_binds[:participation_vrp_ids] = dashboard_registered_vrp_ids_for_current_user
    end

    # training_records conditions: only training-form with main_activity_type='training' and main_activity='farmers'' training'
    training_conditions = [
      "mr.module_slug = 'training-form'",
      "LOWER(TRIM(COALESCE(mr.data::jsonb ->> 'main_activity_type', ''))) = 'training'",
      "(LOWER(TRIM(COALESCE(mr.data::jsonb ->> 'main_activity', ''))) = 'farmers'' training' OR (jsonb_typeof(mr.data::jsonb -> 'main_activity') = 'array' AND EXISTS (SELECT 1 FROM jsonb_array_elements_text(mr.data::jsonb -> 'main_activity') AS ma(activity) WHERE LOWER(TRIM(ma.activity)) = 'farmers'' training')))"
    ]
    completed_binds = {}
    if month_name.present?
      training_conditions << "LOWER(TRIM(COALESCE(mr.data::jsonb ->> 'month', ''))) = :completed_month"
      completed_binds[:completed_month] = normalize_dashboard_text(month_name)
    end

    creator_ids = dashboard_participation_completion_creator_ids
    if creator_ids.any?
      training_conditions << "COALESCE(mr.data::jsonb ->> 'created_by_id', '') IN (:completed_creator_ids)"
      completed_binds[:completed_creator_ids] = creator_ids
    end

    sql = <<~SQL.squish
      WITH assigned AS MATERIALIZED (
        SELECT DISTINCT
          t.id::text AS target_mapping_id,
          TRIM(j.value) AS afl_id
        FROM target_mappings t
        LEFT JOIN vrps v ON v.id = t.vrp_id
        CROSS JOIN LATERAL jsonb_array_elements_text(
          CASE
            WHEN jsonb_typeof(t.afl_ids::jsonb) = 'array' THEN t.afl_ids::jsonb
            ELSE jsonb_build_array(t.afl_ids::jsonb)
          END
        ) AS j(value)
        WHERE #{target_conditions.join(' AND ')}
      ),
      training_records AS (
        SELECT mr.id, mr.data::jsonb AS data
        FROM module_records mr
        WHERE #{training_conditions.join(' AND ')}
      ),
      completed_raw AS (
        SELECT
          TRIM(sf.farmer_id) AS farmer_id,
          TRIM(tm.mapping_id) AS target_mapping_id,
          tr.id AS module_record_id
        FROM training_records tr
        CROSS JOIN LATERAL jsonb_array_elements_text(
          COALESCE(tr.data -> 'selected_farmer_ids', '[]'::jsonb)
        ) AS sf(farmer_id)
        CROSS JOIN LATERAL jsonb_array_elements_text(
          CASE
            WHEN jsonb_typeof(tr.data -> 'target_mapping_ids') = 'array'
              THEN tr.data -> 'target_mapping_ids'
            WHEN NULLIF(TRIM(tr.data ->> 'target_mapping_id'), '') IS NOT NULL
              THEN jsonb_build_array(TRIM(tr.data ->> 'target_mapping_id'))
            ELSE '[]'::jsonb
          END
        ) AS tm(mapping_id)
      ),
      completion_count AS MATERIALIZED (
        SELECT
          farmer_id,
          target_mapping_id,
          COUNT(DISTINCT module_record_id) AS entry_count
        FROM completed_raw
        GROUP BY farmer_id, target_mapping_id
      ),
      farmer_status AS (
        SELECT
          a.afl_id,
          COUNT(DISTINCT a.target_mapping_id) AS assigned_activity,
          COUNT(DISTINCT CASE WHEN cc.entry_count >= 1 THEN a.target_mapping_id END) AS completed_activity,
          MAX(CASE WHEN cc.entry_count > 1 THEN 1 ELSE 0 END) AS has_repeat_training
        FROM assigned a
        LEFT JOIN completion_count cc
          ON cc.farmer_id = a.afl_id
         AND cc.target_mapping_id = a.target_mapping_id
        GROUP BY a.afl_id
      )
      SELECT
        COUNT(*) AS total_mapped_farmer,
        COUNT(*) FILTER (
          WHERE completed_activity > 0
            AND has_repeat_training = 1
        ) AS green_count,
        COUNT(*) FILTER (
          WHERE completed_activity > 0
            AND has_repeat_training = 0
        ) AS yellow_count,
        COUNT(*) FILTER (
          WHERE completed_activity = 0
        ) AS red_count,
        COALESCE(SUM(assigned_activity), 0) AS target_map_total,
        COALESCE(SUM(completed_activity), 0) AS completed_target_map_total
      FROM farmer_status
    SQL

    row = ActiveRecord::Base.connection.exec_query(
      ActiveRecord::Base.send(:sanitize_sql_array, [sql, target_binds.merge(completed_binds)])
    ).first || {}

    {
      green: row["green_count"].to_i,
      yellow: row["yellow_count"].to_i,
      red: row["red_count"].to_i,
      pending: row["red_count"].to_i,
      completed: row["green_count"].to_i,
      completed_target_map_total: row["completed_target_map_total"].to_i,
      registered_farmer_total: training_registered_afl_farmer_count_for_participation(targets, fcoc_name: fcoc_name),
      total: row["total_mapped_farmer"].to_i,
      target_map_total: row["target_map_total"].to_i
    }
  rescue StandardError => e
    Rails.logger.warn("Dashboard participation SQL counts failed: #{e.class} - #{e.message}")
    nil
  end

  def dashboard_participation_completion_creator_ids
    if vrp_login_user?
      dashboard_current_app_user_ids.map(&:to_s)
    elsif dashboard_agronomics_login?
      dashboard_registered_vrp_ids_for_current_user.map(&:to_s)
    else
      []
    end
  end

  def training_mapped_farmer_distinct_count_for_participation(month_name:, fcoc_name:, targets:)
    return 0 unless model_ready?(:TargetMapping)

    @training_mapped_farmer_distinct_count_cache ||= {}
    fco_ids = Array(targets).filter_map { |target| target.fco_id.to_s.strip.presence }.uniq
    fco_names = Array(targets).flat_map do |target|
      training_fcoc_filter_values(
        target.fco_name.to_s.strip.presence,
        target.vrp&.fcoc.to_s.strip.presence
      )
    end.compact_blank.uniq
    if fcoc_name.present?
      fco_names = (fco_names + training_fcoc_filter_values(fcoc_name)).compact_blank.uniq
    end

    target_ids = Array(targets).filter_map { |target| target.respond_to?(:id) ? target.id : nil }.uniq
    cache_key = [
      normalize_dashboard_text(month_name),
      fco_ids.sort.join(","),
      fco_names.sort.join(","),
      module_mapped_vrp_scope_active? ? target_ids.sort.join(",") : nil
    ].join("|")
    return @training_mapped_farmer_distinct_count_cache[cache_key] if @training_mapped_farmer_distinct_count_cache.key?(cache_key)

    conditions = ["t.afl_ids IS NOT NULL", "j.value <> ''"]
    binds = {}
    if module_mapped_vrp_scope_active? && target_ids.any?
      conditions << "t.id IN (:target_ids)"
      binds[:target_ids] = target_ids
    end
    if month_name.present?
      conditions << "LOWER(BTRIM(t.month_name)) = :month_name"
      binds[:month_name] = normalize_dashboard_text(month_name)
    end
    fcoc_conditions = []
    if fco_ids.any?
      fcoc_conditions << "t.fco_id IN (:fco_ids)"
      binds[:fco_ids] = fco_ids
    end
    if fco_names.any?
      fcoc_conditions << "(LOWER(BTRIM(t.fco_name)) IN (:fco_names) OR LOWER(BTRIM(v.fcoc)) IN (:fco_names))"
      binds[:fco_names] = fco_names.map { |name| normalize_dashboard_text(name) }.reject(&:blank?).uniq
    end
    conditions << "(#{fcoc_conditions.join(' OR ')})" if fcoc_conditions.any?

    sql = <<~SQL.squish
      SELECT COUNT(DISTINCT CASE
        WHEN LOWER(BTRIM(COALESCE(a.tracenet_no, ''))) NOT IN ('', 'null') THEN CONCAT('tracenet:', LOWER(BTRIM(a.tracenet_no)))
        ELSE CONCAT('id:', a.id::text)
      END) AS unique_farmer_count
      FROM target_mappings t
      CROSS JOIN LATERAL jsonb_array_elements_text(t.afl_ids::jsonb) AS j(value)
      JOIN afls a ON a.id::text = j.value
      LEFT JOIN vrps v ON v.id = t.vrp_id
      WHERE #{conditions.join(' AND ')}
    SQL

    sanitized_sql = ActiveRecord::Base.send(:sanitize_sql_array, [sql, binds])
    @training_mapped_farmer_distinct_count_cache[cache_key] = ActiveRecord::Base.connection.select_value(sanitized_sql).to_i
  end

  def training_registered_afl_farmer_count_for_participation(targets, fcoc_name: nil)
    return 0 unless model_ready?(:Afl)

    fco_ids = Array(targets).filter_map { |target| target.fco_id.to_s.strip.presence }.uniq
    fco_names = Array(targets).flat_map do |target|
      training_fcoc_filter_values(
        target.fco_name.to_s.strip.presence,
        target.vrp&.fcoc.to_s.strip.presence
      )
    end.compact_blank.uniq

    if fcoc_name.present?
      selected_values = training_fcoc_filter_values(fcoc_name)
      fco_names = (fco_names + selected_values).compact_blank.uniq
    end

    @training_registered_afl_count_cache ||= {}
    cache_key = [fco_ids.sort.join(","), fco_names.sort.join(",")].join("|")
    return @training_registered_afl_count_cache[cache_key] if @training_registered_afl_count_cache.key?(cache_key)

    scope = dashboard_visible_farmer_scope.where.not(id: nil)
    if fco_ids.any? || fco_names.any?
      conditions = []
      binds = {}
      if fco_ids.any?
        conditions << "afls.fco_id IN (:fco_ids)"
        binds[:fco_ids] = fco_ids
      end
      if fco_names.any?
        conditions << "LOWER(BTRIM(afls.fco)) IN (:fco_names)"
        binds[:fco_names] = fco_names.map { |name| normalize_dashboard_text(name) }.reject(&:blank?).uniq
      end
      scope = scope.where(conditions.join(" OR "), binds)
    end

    @training_registered_afl_count_cache[cache_key] = scope.count(:id)
  end

  def training_fcoc_ids_from_param(fcoc_name)
    raw_values = Array(fcoc_name).flatten.map(&:to_s).reject(&:blank?)
    return %w[1004 1006] if raw_values.blank?

    ids = []
    raw_values.each do |val|
      normalized = val.to_s.downcase.strip
      if normalized.include?("1004") || normalized.include?("sausar")
        ids << "1004"
      end
      if normalized.include?("1006") || normalized.include?("turekela")
        ids << "1006"
      end
      if normalized.match?(/\A\d+\z/)
        ids << normalized
      end
    end
    ids = ids.uniq
    ids.presence || %w[1004 1006]
  end

  def farmer_training_mapped_farmer_count_and_popups(month_name:, fcoc_name:)
    @farmer_training_mapped_farmer_count_and_popups_cache ||= {}
    key = [month_name, fcoc_name]
    return @farmer_training_mapped_farmer_count_and_popups_cache[key] if @farmer_training_mapped_farmer_count_and_popups_cache.key?(key)

    @farmer_training_mapped_farmer_count_and_popups_cache[key] = compute_farmer_training_mapped_farmer_count_and_popups(month_name: month_name, fcoc_name: fcoc_name)
  end

  def compute_farmer_training_mapped_farmer_count_and_popups(month_name:, fcoc_name:)
    selected_month = month_name.presence || "August"
    fco_ids = training_fcoc_ids_from_param(fcoc_name)
    fco_filter_sql = "AND LOWER(BTRIM(t.fco_id)) IN (:fco_ids)"

    sql = <<~SQL.squish
      SELECT
          t.fco_id,
          COALESCE(MAX(NULLIF(BTRIM(t.fco_name), '')), t.fco_id) AS fco_name,
          COUNT(DISTINCT v.afl_id) AS farmer_count
      FROM public.target_mappings t
      CROSS JOIN LATERAL jsonb_array_elements_text(
          CASE
            WHEN jsonb_typeof(t.afl_ids::jsonb) = 'array' THEN t.afl_ids::jsonb
            ELSE jsonb_build_array(t.afl_ids::jsonb)
          END
      ) AS v(afl_id)
      WHERE LOWER(BTRIM(t.month_name)) = :month_name
        #{fco_filter_sql}
      GROUP BY t.fco_id
      ORDER BY t.fco_id;
    SQL

    binds = { month_name: selected_month.strip.downcase, fco_ids: fco_ids.map(&:downcase) }
    rows = ActiveRecord::Base.connection.exec_query(
      ActiveRecord::Base.send(:sanitize_sql_array, [dashboard_scoped_training_sql(sql), binds])
    ).to_a

    total_count = rows.sum { |r| r["farmer_count"].to_i }
    popups = format_fco_popups(rows, fco_ids, "farmer_count")

    [total_count, popups]
  rescue StandardError => e
    Rails.logger.warn("Mapped farmer count SQL failed: #{e.message}")
    [0, format_fco_popups([], fco_ids, "farmer_count")]
  end

  def farmer_training_no_training_count_and_popups(month_name:, fcoc_name:)
    @farmer_training_no_training_count_and_popups_cache ||= {}
    key = [month_name, fcoc_name, selected_participation_sql_week]
    return @farmer_training_no_training_count_and_popups_cache[key] if @farmer_training_no_training_count_and_popups_cache.key?(key)

    @farmer_training_no_training_count_and_popups_cache[key] = compute_farmer_training_no_training_count_and_popups(month_name: month_name, fcoc_name: fcoc_name)
  end

  def compute_farmer_training_no_training_count_and_popups(month_name:, fcoc_name:)
    selected_month = month_name.presence || "August"
    fco_ids = training_fcoc_ids_from_param(fcoc_name)
    fco_values = fco_ids.flat_map { |id| training_fcoc_filter_values(id) }.uniq.map(&:downcase)
    fco_filter_sql = "AND LOWER(BTRIM(a.fco_id)) IN (:fco_ids)"
    fco_filter_t = "AND (LOWER(BTRIM(t.fco_id)) IN (:fco_values) OR LOWER(BTRIM(t.fco_name)) IN (:fco_values))"

    sql = <<~SQL.squish
      WITH august_any_mapping AS (
          SELECT DISTINCT v.afl_id
          FROM public.target_mappings t
          CROSS JOIN LATERAL jsonb_array_elements_text(
              CASE
                WHEN jsonb_typeof(t.afl_ids::jsonb) = 'array' THEN t.afl_ids::jsonb
                ELSE jsonb_build_array(t.afl_ids::jsonb)
              END
          ) AS v(afl_id)
          WHERE LOWER(TRIM(t.month_name)) = :month_name
            #{fco_filter_t}
      ),
      august_training_mapping AS (
          SELECT DISTINCT v.afl_id
          FROM public.target_mappings t
          CROSS JOIN LATERAL jsonb_array_elements_text(
              CASE
                WHEN jsonb_typeof(t.afl_ids::jsonb) = 'array' THEN t.afl_ids::jsonb
                ELSE jsonb_build_array(t.afl_ids::jsonb)
              END
          ) AS v(afl_id)
          WHERE LOWER(TRIM(t.month_name)) = :month_name
            #{fco_filter_t}
            AND LOWER(COALESCE(t.main_activity_name, '')) LIKE '%farmers'' training%'
      ),
      august_training_done AS (
          SELECT DISTINCT sf.farmer_id
          FROM public.module_records mr
          CROSS JOIN LATERAL jsonb_array_elements_text(
              COALESCE(
                  mr.data::jsonb -> 'selected_farmer_ids',
                  '[]'::jsonb
              )
          ) AS sf(farmer_id)
          WHERE mr.module_slug = 'training-form'
            AND LOWER(TRIM(mr.data::jsonb ->> 'month')) = :month_name
            #{training_participation_week_filter_sql(selected_participation_sql_week)}
            AND LOWER(COALESCE(mr.data::jsonb ->> 'main_activity', '')) LIKE '%farmers'' training%'
      )
      SELECT
          a.fco_id,
          COALESCE(MAX(NULLIF(BTRIM(a.fco), '')), a.fco_id) AS fco_name,
          COUNT(DISTINCT a.id) AS total_farmer_count,
          COUNT(DISTINCT CASE WHEN am.afl_id IS NOT NULL THEN a.id END) AS total_mapped_farmer_count,
          COUNT(DISTINCT CASE WHEN am.afl_id IS NULL AND td.farmer_id IS NULL THEN a.id END) AS no_activity_mapping_count,
          COUNT(DISTINCT CASE WHEN am.afl_id IS NOT NULL AND tm.afl_id IS NULL AND td.farmer_id IS NULL THEN a.id END) AS no_training_mapping_count,
          COUNT(DISTINCT CASE WHEN tm.afl_id IS NOT NULL AND td.farmer_id IS NULL THEN a.id END) AS training_mapped_but_no_entry_count,
          COUNT(DISTINCT a.id) FILTER (WHERE td.farmer_id IS NULL) AS red_farmer_count
      FROM public.afls a
      LEFT JOIN august_any_mapping am ON am.afl_id = a.id::text
      LEFT JOIN august_training_mapping tm ON tm.afl_id = a.id::text
      LEFT JOIN august_training_done td ON td.farmer_id = a.id::text
      WHERE 1=1
        #{fco_filter_sql}
      GROUP BY a.fco_id
      ORDER BY a.fco_id;
    SQL

    binds = { month_name: selected_month.strip.downcase, fco_ids: fco_ids.map(&:downcase), fco_values: fco_values }
    rows = ActiveRecord::Base.connection.exec_query(
      ActiveRecord::Base.send(:sanitize_sql_array, [dashboard_scoped_training_sql(sql), binds])
    ).to_a

    total_count = rows.sum { |r| r["red_farmer_count"].to_i }
    popups = format_red_fco_popups(rows, fco_ids)
    details = format_red_fco_details(rows, fco_ids)

    [total_count, popups, details]
  rescue StandardError => e
    Rails.logger.warn("No training count SQL failed: #{e.message}")
    [0, format_fco_popups([], fco_ids, "red_farmer_count"), []]
  end

  def format_red_fco_popups(rows, fco_ids)
    fco_name_map = { "1004" => "Sausar", "1006" => "Turekela" }
    target_ids = Array(fco_ids).presence || %w[1004 1006]
    rows_by_id = Array(rows).index_by { |r| r["fco_id"].to_s.strip.downcase }

    target_ids.flat_map do |id|
      row = rows_by_id[id.to_s.strip.downcase]
      raw_name = row&.dig("fco_name").presence || fco_name_map[id.to_s] || "FCO #{id}"
      # Show the plain FCO name (e.g. "Sausar") without the "(1004)" id suffix.
      name = fco_name_map[id.to_s] || raw_name.to_s.sub(/\s*\(\s*\d+\s*\)\s*/, " ").squish.titleize
      total_red = row ? row["red_farmer_count"].to_i : 0
      no_activity = row ? row["no_activity_mapping_count"].to_i : 0
      no_training = row ? row["no_training_mapping_count"].to_i : 0
      no_entry = row ? row["training_mapped_but_no_entry_count"].to_i : 0

      [
        "#{name}: #{total_red}",
        "  • कुल मेप नहीं किये गये किसान: #{no_activity}",
        "  • कुल फार्मर ट्रेनिंग से मेप नहीं किये गये किसान: #{no_training}",
        "  • कुल फार्मर ट्रेनिंग में किसान की एंट्री नहीं हुई: #{no_entry}"
      ]
    end
  end

  def format_red_fco_details(rows, fco_ids)
    fco_name_map = { "1004" => "Sausar", "1006" => "Turekela" }
    target_ids = Array(fco_ids).presence || %w[1004 1006]
    rows_by_id = Array(rows).index_by { |r| r["fco_id"].to_s.strip.downcase }

    target_ids.map do |id|
      row = rows_by_id[id.to_s.strip.downcase]
      raw_name = row&.dig("fco_name").presence || fco_name_map[id.to_s] || "FCO #{id}"
      # Show the plain FCO name (e.g. "Sausar") without the "(1004)" id suffix.
      name = fco_name_map[id.to_s] || raw_name.to_s.sub(/\s*\(\s*\d+\s*\)\s*/, " ").squish.titleize
      total_red = row ? row["red_farmer_count"].to_i : 0
      no_activity = row ? row["no_activity_mapping_count"].to_i : 0
      no_training = row ? row["no_training_mapping_count"].to_i : 0
      no_entry = row ? row["training_mapped_but_no_entry_count"].to_i : 0

      {
        fco_id: id,
        name: name,
        total_red: total_red,
        no_activity: no_activity,
        no_training: no_training,
        no_entry: no_entry
      }
    end
  end

  def farmer_training_yellow_farmer_count_and_popups(month_name:, fcoc_name:)
    @farmer_training_yellow_farmer_count_and_popups_cache ||= {}
    key = [month_name, fcoc_name, selected_participation_sql_week]
    return @farmer_training_yellow_farmer_count_and_popups_cache[key] if @farmer_training_yellow_farmer_count_and_popups_cache.key?(key)

    @farmer_training_yellow_farmer_count_and_popups_cache[key] = compute_farmer_training_yellow_farmer_count_and_popups(month_name: month_name, fcoc_name: fcoc_name)
  end

  def compute_farmer_training_yellow_farmer_count_and_popups(month_name:, fcoc_name:)
    rows = farmer_training_attendance_counts_by_fco(month_name: month_name, fcoc_name: fcoc_name)
    [rows.sum { |row| row["yellow_count"].to_i }, format_fco_popups(rows, training_fcoc_ids_from_param(fcoc_name), "yellow_count")]
  end

  def farmer_training_green_farmer_count_and_popups(month_name:, fcoc_name:)
    @farmer_training_green_farmer_count_and_popups_cache ||= {}
    key = [month_name, fcoc_name, selected_participation_sql_week]
    return @farmer_training_green_farmer_count_and_popups_cache[key] if @farmer_training_green_farmer_count_and_popups_cache.key?(key)

    @farmer_training_green_farmer_count_and_popups_cache[key] = compute_farmer_training_green_farmer_count_and_popups(month_name: month_name, fcoc_name: fcoc_name)
  end

  def compute_farmer_training_green_farmer_count_and_popups(month_name:, fcoc_name:)
    rows = farmer_training_attendance_counts_by_fco(month_name: month_name, fcoc_name: fcoc_name)
    [rows.sum { |row| row["green_count"].to_i }, format_fco_popups(rows, training_fcoc_ids_from_param(fcoc_name), "green_count")]
  end

  def farmer_training_attendance_counts_by_fco(month_name:, fcoc_name:)
    @farmer_training_attendance_counts_by_fco ||= {}
    fco_ids = training_fcoc_ids_from_param(fcoc_name).map(&:downcase)
    month = normalize_dashboard_text(month_name.presence || "August")
    key = [month, fco_ids.sort, selected_participation_sql_week]
    return @farmer_training_attendance_counts_by_fco[key] if @farmer_training_attendance_counts_by_fco.key?(key)

    sql = <<~SQL
      WITH attendance AS MATERIALIZED (
        SELECT sf.farmer_id, COUNT(DISTINCT mr.id) AS training_count
        FROM public.module_records mr
        CROSS JOIN LATERAL jsonb_array_elements_text(
          COALESCE(mr.data::jsonb -> 'selected_farmer_ids', '[]'::jsonb)
        ) AS sf(farmer_id)
        WHERE mr.module_slug = 'training-form'
          AND LOWER(TRIM(mr.data::jsonb ->> 'month')) = :month_name
          #{training_participation_week_filter_sql(selected_participation_sql_week)}
          AND LOWER(COALESCE(mr.data::jsonb ->> 'main_activity', '')) LIKE '%farmers'' training%'
        GROUP BY sf.farmer_id
      )
      SELECT a.fco_id,
        COALESCE(MAX(NULLIF(BTRIM(a.fco), '')), a.fco_id) AS fco_name,
        COUNT(DISTINCT a.id) FILTER (WHERE attendance.training_count = 1) AS yellow_count,
        COUNT(DISTINCT a.id) FILTER (WHERE attendance.training_count > 1) AS green_count
      FROM public.afls a
      JOIN attendance ON attendance.farmer_id = a.id::text
      WHERE LOWER(BTRIM(a.fco_id)) IN (:fco_ids)
      GROUP BY a.fco_id
      ORDER BY a.fco_id
    SQL
    @farmer_training_attendance_counts_by_fco[key] = ActiveRecord::Base.connection.exec_query(
      ActiveRecord::Base.send(:sanitize_sql_array, [dashboard_scoped_training_sql(sql), { month_name: month, fco_ids: fco_ids }])
    ).to_a
  end

  def format_fco_popups(rows, fco_ids, count_key)
    fco_name_map = { "1004" => "Sausar", "1006" => "Turekela" }
    target_ids = Array(fco_ids).presence || %w[1004 1006]
    rows_by_id = Array(rows).index_by { |r| r["fco_id"].to_s.strip.downcase }

    target_ids.map do |id|
      row = rows_by_id[id.to_s.strip.downcase]
      count = row ? row[count_key].to_i : 0
      raw_name = row&.dig("fco_name").presence || fco_name_map[id.to_s] || "FCO #{id}"
      # Plain FCO name (e.g. "Sausar"), no "(1004)" id suffix.
      name = fco_name_map[id.to_s] || raw_name.to_s.sub(/\s*\(\s*\d+\s*\)\s*/, " ").squish.titleize
      "#{name}: #{count}"
    end
  end

  # Mirrors training_record_week_number in SQL so the participation list can filter
  # training records to one week of the month: week = LEAST(((day - 1) / 7) + 1, 4),
  # day taken from training_date (DD/MM/YYYY or YYYY-MM-DD), falling back to created_at.
  def selected_participation_sql_week
    value = dashboard_filter_param(:week, :weekly_target_week).to_i
    (1..4).include?(value) ? value : nil
  end

  def training_participation_week_filter_sql(week_number)
    week = week_number.to_i
    return "" unless (1..4).include?(week)

    <<~SQL.squish
      AND LEAST(
        ((COALESCE(
            CASE
              WHEN btrim(mr.data::jsonb ->> 'training_date') ~ '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}'
                THEN split_part(btrim(mr.data::jsonb ->> 'training_date'), '/', 1)::int
              WHEN btrim(mr.data::jsonb ->> 'training_date') ~ '^[0-9]{4}-[0-9]{1,2}-[0-9]{1,2}'
                THEN substring(btrim(mr.data::jsonb ->> 'training_date') from '^[0-9]{4}-[0-9]{1,2}-([0-9]{1,2})')::int
              ELSE NULL
            END,
            EXTRACT(DAY FROM mr.created_at)::int
          ) - 1) / 7) + 1
      , 4) = #{week}
    SQL
  end

  def farmer_training_participation_rows_from_sql(status, month_name:, fcoc_name:, week_number: nil)
    selected_month = month_name.presence || "August"
    fco_ids = training_fcoc_ids_from_param(fcoc_name)
    week_filter = training_participation_week_filter_sql(week_number || selected_participation_sql_week)

    if status.to_s == "green" || status.to_s == "1_plus_trainings" || status.to_s == "more_than_1"
      fco_filter_sql = "AND LOWER(BTRIM(a.fco_id)) IN (:fco_ids)"
      sql = <<~SQL.squish
        WITH training_records AS MATERIALIZED (
            SELECT
                mr.id AS training_id,
                mr.created_at,
                mr.data::jsonb ->> 'training_date' AS training_date,
                mr.data::jsonb ->> 'sub_activity' AS sub_activity,
                mr.data::jsonb ->> 'training_method' AS training_method,
                mr.data::jsonb ->> 'trainer_name' AS trainer_name,
                mr.data::jsonb ->> 'training_register_upload' AS training_register_upload,
                mr.data::jsonb ->> 'training_photo_upload_with_geo_tag' AS training_photo_upload,
                COALESCE(mr.data::jsonb -> 'selected_farmer_ids', '[]'::jsonb) AS farmer_ids
            FROM public.module_records mr
            WHERE mr.module_slug = 'training-form'
              AND LOWER(TRIM(mr.data::jsonb ->> 'month')) = :month_name
              AND LOWER(COALESCE(mr.data::jsonb ->> 'main_activity', '')) LIKE '%farmers'' training%'
              #{week_filter}
        ), august_training AS (
            SELECT sf.farmer_id, tr.training_id, tr.created_at,
                tr.training_date, tr.sub_activity, tr.training_method,
                tr.trainer_name, tr.training_register_upload, tr.training_photo_upload
            FROM training_records tr
            CROSS JOIN LATERAL jsonb_array_elements_text(tr.farmer_ids) AS sf(farmer_id)
        )
        SELECT
            a.id AS farmer_id,
            a.fco_id,
            a.fco,
            a.fpo_id,
            a.fpo_name,
            a.ics_id,
            a.ics_name,
            a.village_id,
            a.village_name,
            a.tracenet_no,
            a.farmer_name,
            a.father_name,
            a.mobile_no,
            COUNT(DISTINCT at.training_id) AS training_count,
            MIN(at.training_date) AS training_date,
            MIN(at.sub_activity) AS sub_activity,
            STRING_AGG(DISTINCT NULLIF(BTRIM(at.training_method), ''), ', ') AS training_method,
            MIN(at.trainer_name) AS trainer_name,
            STRING_AGG(DISTINCT NULLIF(BTRIM(at.training_register_upload), ''), ', ') AS training_register_urls,
            STRING_AGG(DISTINCT NULLIF(BTRIM(at.training_photo_upload), ''), ', ') AS training_photo_urls
        FROM august_training at
        INNER JOIN public.afls a
            ON a.id::text = at.farmer_id
        WHERE LOWER(BTRIM(a.fco_id)) IN (:fco_ids)
        GROUP BY
            a.id,
            a.fco_id,
            a.fco,
            a.fpo_id,
            a.fpo_name,
            a.ics_id,
            a.ics_name,
            a.village_id,
            a.village_name,
            a.tracenet_no,
            a.farmer_name,
            a.father_name,
            a.mobile_no
        HAVING COUNT(DISTINCT at.training_id) > 1
        ORDER BY
            a.fco_id,
            a.village_name,
            a.farmer_name;
      SQL

      binds = { month_name: selected_month.strip.downcase, fco_ids: fco_ids.map(&:downcase) }
      raw_rows = ActiveRecord::Base.connection.exec_query(
        ActiveRecord::Base.send(:sanitize_sql_array, [dashboard_scoped_training_sql(sql), binds])
      )

      return raw_rows.map do |row|
        {
          farmer_id: row["farmer_id"].to_s,
          farmer_name: row["farmer_name"].to_s.presence || "Farmer ##{row['farmer_id']}",
          father_name: row["father_name"].to_s,
          mobile_no: row["mobile_no"].to_s,
          tracenet_no: row["tracenet_no"].to_s,
          ics: row["ics_name"].to_s.presence || row["ics_id"].to_s.presence || "-",
          village: row["village_name"].to_s.presence || row["village_id"].to_s.presence || "-",
          fcoc: row["fco"].to_s.presence || row["fco_id"].to_s.presence || "-",
          cluster_incharge: "-",
          jeevika_jankar_name: row["trainer_name"].to_s.presence || "-",
          vrp: row["trainer_name"].to_s.presence || "-",
          registered_by: row["trainer_name"].to_s.presence || "-",
          months: selected_month,
          main_activities: "Farmers' Training",
          sub_activities: row["sub_activity"].to_s.presence || "-",
          training_method: row["training_method"].to_s.presence || "-",
          attendance_count: row["training_count"].to_i,
          status: "green",
          status_label: "1+ Trainings",
          training_dates: row["training_date"].to_s.presence || "-",
          last_training_date: row["training_date"].to_s.presence || "-",
          training_register_urls: module_upload_public_urls(row["training_register_urls"]),
          training_photo_urls: module_upload_public_urls(row["training_photo_urls"])
        }
      end
    end

    if status.to_s == "yellow" || status.to_s == "only_1_training"
      sql = <<~SQL.squish
        WITH training_records AS MATERIALIZED (
            SELECT
                mr.id AS training_id,
                mr.created_at,
                mr.data::jsonb ->> 'training_date' AS training_date,
                mr.data::jsonb ->> 'sub_activity' AS sub_activity,
                mr.data::jsonb ->> 'training_method' AS training_method,
                mr.data::jsonb ->> 'trainer_name' AS trainer_name,
                mr.data::jsonb ->> 'training_register_upload' AS training_register_upload,
                mr.data::jsonb ->> 'training_photo_upload_with_geo_tag' AS training_photo_upload,
                COALESCE(mr.data::jsonb -> 'selected_farmer_ids', '[]'::jsonb) AS farmer_ids
            FROM public.module_records mr
            WHERE mr.module_slug = 'training-form'
              AND LOWER(TRIM(mr.data::jsonb ->> 'month')) = :month_name
              AND LOWER(COALESCE(mr.data::jsonb ->> 'main_activity', '')) LIKE '%farmers'' training%'
              #{week_filter}
        ), august_training AS (
            SELECT sf.farmer_id, tr.training_id, tr.created_at,
                tr.training_date, tr.sub_activity, tr.training_method,
                tr.trainer_name, tr.training_register_upload, tr.training_photo_upload
            FROM training_records tr
            CROSS JOIN LATERAL jsonb_array_elements_text(tr.farmer_ids) AS sf(farmer_id)
        )
        SELECT
            a.id AS farmer_id,
            a.fco_id,
            a.fco,
            a.fpo_id,
            a.fpo_name,
            a.ics_id,
            a.ics_name,
            a.village_id,
            a.village_name,
            a.tracenet_no,
            a.farmer_name,
            a.father_name,
            a.mobile_no,
            COUNT(at.training_id) AS training_count,
            MIN(at.training_date) AS training_date,
            MIN(at.sub_activity) AS sub_activity,
            STRING_AGG(DISTINCT NULLIF(BTRIM(at.training_method), ''), ', ') AS training_method,
            MIN(at.trainer_name) AS trainer_name,
            STRING_AGG(DISTINCT NULLIF(BTRIM(at.training_register_upload), ''), ', ') AS training_register_urls,
            STRING_AGG(DISTINCT NULLIF(BTRIM(at.training_photo_upload), ''), ', ') AS training_photo_urls
        FROM august_training at
        INNER JOIN public.afls a
            ON a.id::text = at.farmer_id
        WHERE LOWER(BTRIM(a.fco_id)) IN (:fco_ids)
        GROUP BY
            a.id,
            a.fco_id,
            a.fco,
            a.fpo_id,
            a.fpo_name,
            a.ics_id,
            a.ics_name,
            a.village_id,
            a.village_name,
            a.tracenet_no,
            a.farmer_name,
            a.father_name,
            a.mobile_no
        HAVING COUNT(at.training_id) = 1
        ORDER BY
            a.fco_id,
            a.village_name,
            a.farmer_name;
      SQL

      binds = { month_name: selected_month.strip.downcase, fco_ids: fco_ids.map(&:downcase) }
      raw_rows = ActiveRecord::Base.connection.exec_query(
        ActiveRecord::Base.send(:sanitize_sql_array, [dashboard_scoped_training_sql(sql), binds])
      )

      return raw_rows.map do |row|
        {
          farmer_id: row["farmer_id"].to_s,
          farmer_name: row["farmer_name"].to_s.presence || "Farmer ##{row['farmer_id']}",
          father_name: row["father_name"].to_s,
          mobile_no: row["mobile_no"].to_s,
          tracenet_no: row["tracenet_no"].to_s,
          ics: row["ics_name"].to_s.presence || row["ics_id"].to_s.presence || "-",
          village: row["village_name"].to_s.presence || row["village_id"].to_s.presence || "-",
          fcoc: row["fco"].to_s.presence || row["fco_id"].to_s.presence || "-",
          cluster_incharge: "-",
          jeevika_jankar_name: row["trainer_name"].to_s.presence || "-",
          vrp: row["trainer_name"].to_s.presence || "-",
          registered_by: row["trainer_name"].to_s.presence || "-",
          months: selected_month,
          main_activities: "Farmers' Training",
          sub_activities: row["sub_activity"].to_s.presence || "-",
          training_method: row["training_method"].to_s.presence || "-",
          attendance_count: row["training_count"].to_i,
          status: "yellow",
          status_label: "Only 1 Training",
          training_dates: row["training_date"].to_s.presence || "-",
          last_training_date: row["training_date"].to_s.presence || "-",
          training_register_urls: module_upload_public_urls(row["training_register_urls"]),
          training_photo_urls: module_upload_public_urls(row["training_photo_urls"])
        }
      end
    end

    fco_filter_t  = "AND t.fco_id IN (:fco_ids)"
    fco_filter_a  = "AND a.fco_id IN (:fco_ids)"

    sql = case status.to_s
    when "unique", "mapped"
      Rails.root.join("app/queries/mapped_farmer_details.sql").read
    when "no_activity"
      <<~SQL.squish
        WITH august_any_mapping AS (
            SELECT DISTINCT v.afl_id
            FROM public.target_mappings t
            CROSS JOIN LATERAL jsonb_array_elements_text(
                CASE
                  WHEN jsonb_typeof(t.afl_ids::jsonb) = 'array' THEN t.afl_ids::jsonb
                  ELSE jsonb_build_array(t.afl_ids::jsonb)
                END
            ) AS v(afl_id)
            WHERE LOWER(TRIM(t.month_name)) = :month_name
              #{fco_filter_t}
        )
        SELECT a.id, a.fco_id, a.fco, a.fpo_id, a.fpo_name, a.ics_id, a.ics_name, a.village_id, a.village_name, a.tracenet_no, a.farmer_name, a.father_name, a.mobile_no
        FROM public.afls a
        LEFT JOIN august_any_mapping am ON am.afl_id = a.id::text
        WHERE am.afl_id IS NULL #{fco_filter_a}
        ORDER BY a.fco_id, a.id;
      SQL
    when "no_training_mapping", "no_training"
      <<~SQL.squish
        WITH august_any_mapping AS (
            SELECT DISTINCT v.afl_id
            FROM public.target_mappings t
            CROSS JOIN LATERAL jsonb_array_elements_text(
                CASE
                  WHEN jsonb_typeof(t.afl_ids::jsonb) = 'array' THEN t.afl_ids::jsonb
                  ELSE jsonb_build_array(t.afl_ids::jsonb)
                END
            ) AS v(afl_id)
            WHERE LOWER(TRIM(t.month_name)) = :month_name
              #{fco_filter_t}
        ),
        august_training_mapping AS (
            SELECT DISTINCT v.afl_id
            FROM public.target_mappings t
            CROSS JOIN LATERAL jsonb_array_elements_text(
                CASE
                  WHEN jsonb_typeof(t.afl_ids::jsonb) = 'array' THEN t.afl_ids::jsonb
                  ELSE jsonb_build_array(t.afl_ids::jsonb)
                END
            ) AS v(afl_id)
            WHERE LOWER(TRIM(t.month_name)) = :month_name
              #{fco_filter_t}
              AND LOWER(COALESCE(t.main_activity_name, '')) LIKE '%farmers'' training%'
        )
        SELECT a.id, a.fco_id, a.fco, a.fpo_id, a.fpo_name, a.ics_id, a.ics_name, a.village_id, a.village_name, a.tracenet_no, a.farmer_name, a.father_name, a.mobile_no
        FROM public.afls a
        INNER JOIN august_any_mapping am ON am.afl_id = a.id::text
        LEFT JOIN august_training_mapping tm ON tm.afl_id = a.id::text
        WHERE tm.afl_id IS NULL #{fco_filter_a}
        ORDER BY a.fco_id, a.id;
      SQL
    when "training_mapped_no_entry", "no_entry"
      <<~SQL.squish
        WITH august_training_mapping AS (
            SELECT DISTINCT v.afl_id
            FROM public.target_mappings t
            CROSS JOIN LATERAL jsonb_array_elements_text(
                CASE
                  WHEN jsonb_typeof(t.afl_ids::jsonb) = 'array' THEN t.afl_ids::jsonb
                  ELSE jsonb_build_array(t.afl_ids::jsonb)
                END
            ) AS v(afl_id)
            WHERE LOWER(TRIM(t.month_name)) = :month_name
              #{fco_filter_t}
              AND LOWER(COALESCE(t.main_activity_name, '')) LIKE '%farmers'' training%'
        ),
        august_training_done AS (
            SELECT DISTINCT sf.farmer_id
            FROM public.module_records mr
            CROSS JOIN LATERAL jsonb_array_elements_text(
                COALESCE(
                    mr.data::jsonb -> 'selected_farmer_ids',
                    '[]'::jsonb
                )
            ) AS sf(farmer_id)
            WHERE mr.module_slug = 'training-form'
              AND LOWER(TRIM(mr.data::jsonb ->> 'month')) = :month_name
              AND LOWER(COALESCE(mr.data::jsonb ->> 'main_activity', '')) LIKE '%farmers'' training%'
        )
        SELECT a.id, a.fco_id, a.fco, a.fpo_id, a.fpo_name, a.ics_id, a.ics_name, a.village_id, a.village_name, a.tracenet_no, a.farmer_name, a.father_name, a.mobile_no
        FROM public.afls a
        INNER JOIN august_training_mapping tm ON tm.afl_id = a.id::text
        LEFT JOIN august_training_done td ON td.farmer_id = a.id::text
        WHERE td.farmer_id IS NULL #{fco_filter_a}
        ORDER BY a.fco_id, a.id;
      SQL
    else # "red", "total_red", "pending"
      Rails.root.join("app/queries/no_training_farmer_details.sql").read
    end

    sql = sql.gsub("WHERE mr.module_slug = 'training-form'", "WHERE mr.module_slug = 'training-form' #{week_filter}")

    if %w[unique mapped red pending total_red].include?(status.to_s)
      farmer_scope = dashboard_visible_farmer_scope.where(fco_id: fco_ids)
      binds = { month_name: selected_month.strip.downcase, fco_ids: fco_ids, visible_farmer_ids: farmer_scope.pluck(:id) }
      @mapped_farmer_details = ActiveRecord::Base.connection.exec_query(
        ActiveRecord::Base.send(:sanitize_sql_array, [dashboard_scoped_training_sql(sql), binds])
      )
      return @mapped_farmer_details.map do |row|
        { farmer_id: row["id"].to_s, farmer_name: row["farmer_name"], father_name: row["father_name"],
          mobile_no: row["mobile_no"], tracenet_no: row["tracenet_no"], ics: row["ics_name"],
          village: row["village_name"], fcoc: row["fco"], cluster_incharge: row["cluster_incharge"],
          vrp: row["vrp_name"], months: selected_month, status_label: row["status"],
          training_register_urls: module_upload_public_urls(row["training_register_urls"]),
          training_photo_urls: module_upload_public_urls(row["training_photo_urls"]) }
      end
    end

    binds = { month_name: selected_month.strip.downcase, fco_ids: fco_ids.flat_map { |id| [id.to_s, id.to_s.downcase] }.uniq }
    raw_rows = ActiveRecord::Base.connection.exec_query(
      ActiveRecord::Base.send(:sanitize_sql_array, [dashboard_scoped_training_sql(sql), binds])
    )

    raw_rows.map do |row|
      {
        farmer_id: row["id"].to_s,
        farmer_name: row["farmer_name"].to_s.presence || "Farmer ##{row['id']}",
        father_name: row["father_name"].to_s,
        mobile_no: row["mobile_no"].to_s,
        tracenet_no: row["tracenet_no"].to_s,
        ics: row["ics_name"].to_s.presence || row["ics_id"].to_s.presence || "-",
        village: row["village_name"].to_s.presence || row["village_id"].to_s.presence || "-",
        fcoc: row["fco"].to_s.presence || row["fco_id"].to_s.presence || "-",
        cluster_incharge: "-",
        jeevika_jankar_name: "-",
        vrp: "-",
        registered_by: "-",
        months: selected_month,
        main_activities: "Farmers' Training",
        sub_activities: "-",
        attendance_count: 0,
        status: status.to_s,
        status_label: training_participation_status_label(status),
        training_dates: "-",
        last_training_date: "-",
        training_register_urls: [],
        training_photo_urls: []
      }
    end
  rescue StandardError => e
    Rails.logger.warn("Farmer training participation rows SQL failed: #{e.message}")
    []
  end

  # Enrich display fields only. SQL remains authoritative for list membership,
  # attendance counts and statuses. Index once instead of querying per farmer.
  def enrich_training_participation_list_rows!(rows, records, targets)
    rows_by_farmer = Array(rows).group_by { |row| row[:farmer_id].to_s }
    coordinators = Hash.new { |hash, id| hash[id] = [] }
    vrp_ids = Array(records).flat_map { |record| record.data.values_at("jeevika_jankar_id", "vrp_id", "select_vrp") }
      .map(&:to_s).select { |id| id.match?(/\A\d+\z/) }.uniq
    vrp_coordinators = vrp_ids.empty? ? {} : Vrp.where(id: vrp_ids).pluck(:id, :cluster_incharge).to_h.transform_keys(&:to_s)
    Array(targets).each do |target|
      name = target.vrp&.cluster_incharge.to_s.strip
      next if name.blank?

      Array(target.afl_ids).each { |id| coordinators[id.to_s] |= [name] if rows_by_farmer.key?(id.to_s) }
    end
    Array(records).each do |record|
      ids = training_record_selected_farmer_ids(record).select { |id| rows_by_farmer.key?(id.to_s) }
      next if ids.empty?

      name = record.data["cluster_incharge"].presence || record.data["cluster_coordinator"]
      name ||= record.data.values_at("jeevika_jankar_id", "vrp_id", "select_vrp")
        .filter_map { |id| vrp_coordinators[id.to_s].presence }.first
      registers = module_upload_public_urls(record.data["training_register_upload"])
      photos = module_upload_public_urls(record.data["training_photo_upload_with_geo_tag"])
      ids.each do |id|
        coordinators[id.to_s] |= [name.to_s.strip] if name.present?
        rows_by_farmer[id.to_s].each do |row|
          row[:training_register_urls] = Array(row[:training_register_urls]) | registers
          row[:training_photo_urls] = Array(row[:training_photo_urls]) | photos
        end
      end
    end
    Array(rows).each do |row|
      names = coordinators[row[:farmer_id].to_s]
      existing = row[:cluster_incharge].to_s.strip
      names = [existing] | names if existing.present? && existing != "-"
      row[:cluster_incharge] = names.presence&.join(", ") || "-"
    end
  end

  def training_participation_search_match?(values)
    Array(values).flatten.join(" ").downcase.include?(@training_participation_search.downcase)
  end

  def training_participation_dashboard_status_cards(counts, month_name:, fcoc_name:, week_number: nil)
    %w[red yellow green].map do |status|
      path_params = { status: status, ics: dashboard_filter_param(:ics, :ics_name) }.compact_blank
      path_params[:training_month] = month_name if month_name.present?
      path_params[:training_fcoc] = fcoc_name if fcoc_name.present?
      path_params[:week] = week_number if week_number.present?
      {
        status: status,
        title: status == "red" ? "Pending" : training_participation_status_label(status),
        value: counts[status.to_sym].to_i,
        caption: status == "red" ? "August me koi training entry nahi hui." : training_participation_status_caption(status),
        path: farmer_training_participation_path(path_params)
      }
    end
  end

  def training_activity_status_cards(totals, month_name:, fcoc_name:)
    [
      ["red", "Red", :red_farmers, "Kisi selected activity me completion nahi hua."],
      ["green", "Green", :green_farmers, "Har selected activity me completion hua."],
      ["yellow", "Yellow", :yellow_farmers, "Kuch activities complete aur kuch pending hain."]
    ].map do |status, title, key, caption|
      path_params = { status: status }
      path_params[:training_month] = month_name if month_name.present?
      path_params[:training_fcoc] = fcoc_name if fcoc_name.present?
      {
        status: status,
        title: title,
        value: totals[key].to_i,
        caption: caption,
        path: farmer_training_participation_path(path_params)
      }
    end
  end

  def training_record_matches_fcoc?(record, fcoc_name)
    selected_values = training_fcoc_filter_values(fcoc_name)
    return true if selected_values.blank?

    summary = training_summary(record)
    record_values = training_fcoc_filter_values(
      summary[:department],
      record.data["fco"],
      record.data["fcoc"],
      record.data["fco_name"],
      record.data["department"]
    )
    return true if (record_values & selected_values).any?

    training_fcoc_vrps(fcoc_name).any? { |vrp| training_record_matches_vrp?(record, vrp) }
  end

  def training_target_matches_fcoc?(target, fcoc_name)
    selected_values = training_fcoc_filter_values(fcoc_name)
    return true if selected_values.blank?

    target_values = training_fcoc_filter_values(
      target.fco_id,
      target.fco_name,
      target.vrp&.fcoc
    )
    (target_values & selected_values).any?
  end

  def training_fcoc_vrps(fcoc_name)
    return [] unless model_ready?(:Vrp)

    @training_fcoc_vrps_cache ||= {}
    cache_key = normalize_dashboard_text(fcoc_name)
    fcoc_values = training_fcoc_filter_values(fcoc_name)
    @training_fcoc_vrps_cache[cache_key] ||= begin
      patterns = fcoc_values.map { |value| "%#{ActiveRecord::Base.sanitize_sql_like(value)}%" }
      conditions = patterns.map { "LOWER(BTRIM(COALESCE(fcoc, ''))) LIKE ?" }.join(" OR ")
      Vrp.where(conditions, *patterns).select { |vrp| training_fcoc_text_matches?(vrp.fcoc, cache_key) }
    end
  end

  def training_fcoc_filter_values(*values)
    Array(values).flatten.filter_map do |value|
      text = value.to_s.strip
      next if text.blank?

      short_name = text.sub(/\Afco\s*-\s*c\s+/i, "").strip
      [text, short_name]
    end.flatten.map { |value| normalize_dashboard_text(value) }.reject(&:blank?).uniq
  end

  def training_fcoc_text_matches?(value, selected_fcoc)
    selected_values = training_fcoc_filter_values(selected_fcoc)
    value_values = training_fcoc_filter_values(value)
    selected_values.any? && value_values.any? && (selected_values & value_values).any?
  end

  def farmer_participation_entries
    return [] unless model_ready?(:ModuleRecord) && model_ready?(:Afl)

    visible_vrps = farmer_participation_visible_vrps
    visible_vrps_by_id = visible_vrps.index_by { |vrp| vrp.id.to_s }
    visible_vrp_ids = visible_vrps_by_id.keys
    vrps_by_farmer_id = Hash.new { |hash, key| hash[key] = [] }
    visible_targets = if model_ready?(:TargetMapping)
      scope = TargetMapping.includes(:vrp)
      admin_dashboard_user? ? scope.to_a : scope.where(vrp_id: visible_vrp_ids).to_a
    else
      []
    end
    visible_targets.each do |target|
      next unless target.vrp

      Array(target.afl_ids).each do |farmer_id|
        vrps_by_farmer_id[farmer_id.to_s] |= [target.vrp]
      end
    end

    records = active_module_records_scope("training-form")
      .order(created_at: :desc)
      .select { |record| active_module_record?(record) }
      .select { |record| training_record_countable?(record) }
      .select { |record| training_record_selected_farmer_ids(record).any? }
    if vrp_login_user?
      records = records.select { |record| module_record_visible_for_current_context?(record) }
    end

    farmer_ids = records.flat_map { |record| training_record_selected_farmer_ids(record) }.uniq
    farmers_by_id = Afl.where(id: farmer_ids).index_by { |farmer| farmer.id.to_s }

    records.flat_map do |record|
      summary = training_summary(record)
      record_vrp_id = record.data["jeevika_jankar_id"].presence || record.data["vrp_id"].presence
      explicitly_matched_vrp = visible_vrps_by_id[record_vrp_id.to_s] if record_vrp_id.present?
      explicitly_matched_vrp ||= visible_vrps.find { |vrp| training_record_matches_vrp?(record, vrp) }

      # These values belong to the training entry, not to each attending farmer.
      training_method = Array(record.data["training_method"]).map(&:to_s).compact_blank.join(", ").presence || "Not Recorded"
      training_month = summary[:month].presence || parse_module_date(summary[:training_date])&.strftime("%B") || "-"
      training_date = bill_display_date(summary[:training_date]).presence || bill_display_date(record.created_at)
      register_urls = module_upload_public_urls(record.data["training_register_upload"])
      photo_urls = module_upload_public_urls(record.data["training_photo_upload_with_geo_tag"])
      selected_farmer_names = Array(record.data["selected_farmer_names"]).map(&:to_s)
      training_record_selected_farmer_ids(record).each_with_index.filter_map do |farmer_id, farmer_index|
        farmer = farmers_by_id[farmer_id]
        vrp = explicitly_matched_vrp || vrps_by_farmer_id[farmer_id].first
        next if !admin_dashboard_user? && vrp.blank?

        farmer_name = farmer&.farmer_name.presence || selected_farmer_names[farmer_index].presence || "Farmer ##{farmer_id}"
        farmer_context = [farmer&.tracenet_no.presence, farmer&.village_name.presence || record.data["gram_name"].presence].compact.join(" | ")

        {
          farmer_id: farmer_id,
          farmer_name: farmer_name,
          farmer_label: [farmer_name, farmer_context.presence].compact.join(" — "),
          tracenet_no: farmer&.tracenet_no.presence || "-",
          village: record.data["gram_name"].presence || farmer&.village_name.presence || "-",
          main_activity: summary[:training_topic].presence || "-",
          sub_activity: summary[:training_subject].presence || "-",
          training_method: training_method,
          month: training_month,
          training_date: training_date,
          training_register_urls: register_urls,
          training_photo_urls: photo_urls,
          fcoc: summary[:department].presence || vrp&.fcoc.presence || "-",
          cluster_incharge: vrp&.cluster_incharge.presence || "-",
          role: vrp&.role.presence || "-",
          vrp_id: vrp&.id&.to_s,
          vrp_name: record.data["trainer_name"].presence || record.data["jeevika_jankar_name"].presence || vrp&.name.presence || "-"
        }
      end
    end
  end

  def farmer_participation_visible_vrps
    return [] unless model_ready?(:Vrp)
    return [current_vrp_record].compact if vrp_login_user?

    dashboard_vrps
  end

  def participation_text_filter_options(entries, key)
    entries.map { |entry| entry[key] }.compact_blank.reject { |value| value == "-" }.uniq.sort
  end

  def training_record_main_activity_type?(record)
    normalize_dashboard_text(record.data["main_activity_type"].presence || "Training") == normalize_dashboard_text("Training")
  end

  def training_participation_status_cards(targets, month_name: nil, sub_activity_name: nil, fcoc_name: nil)
    counts = training_participation_status_counts(targets, month_name: month_name)

    %w[red yellow green].map do |status|
      path_params = { status: status }
      path_params[:training_month] = month_name if month_name.present?
      path_params[:training_sub_activity] = sub_activity_name if sub_activity_name.present?
      path_params[:training_fcoc] = fcoc_name if fcoc_name.present?

      {
        status: status,
        title: training_participation_status_label(status),
        value: counts[status.to_sym].to_i,
        caption: training_participation_status_caption(status),
        path: farmer_training_participation_path(path_params)
      }
    end
  end

  def training_participation_status_cards_from_records(records, month_name: nil, sub_activity_name: nil, fcoc_name: nil, population_rows: nil)
    counts = training_participation_status_counts_from_records(records)
    population_counts = population_rows.nil? ? {} : training_participation_status_counts_from_rows(population_rows)

    %w[red yellow green].map do |status|
      path_params = { status: status }
      path_params[:training_month] = month_name if month_name.present?
      path_params[:training_sub_activity] = sub_activity_name if sub_activity_name.present?
      path_params[:training_fcoc] = fcoc_name if fcoc_name.present?

      {
        status: status,
        title: training_participation_status_label(status),
        value: population_counts.fetch(status.to_sym, counts[status.to_sym]).to_i,
        caption: training_participation_status_caption(status),
        path: farmer_training_participation_path(path_params)
      }
    end
  end

  def training_participation_status_counts_from_records(records)
    rows = training_participation_farmer_rows_from_records(records)

    {
      unique: rows.size,
      green: rows.count { |row| row[:status] == "green" },
      yellow: rows.count { |row| row[:status] == "yellow" },
      red: rows.count { |row| row[:status] == "red" },
      pending: rows.count { |row| row[:status] == "pending" },
      total: training_total_farmer_count_from_records(records)
    }
  end

  def training_participation_status_counts_from_rows(rows)
    Array(rows).each_with_object({ green: 0, yellow: 0, red: 0, pending: 0 }) do |row, counts|
      status = row[:status].to_sym
      counts[status] += 1 if counts.key?(status)
    end
  end

  def training_unique_farmer_count_from_records(records)
    training_participation_farmer_rows_from_records(records).size
  end

  def training_record_unique_farmer_keys(records)
    farmer_ids = Array(records).flat_map { |record| training_record_selected_farmer_ids(record) }.map(&:to_s).reject(&:blank?).uniq
    training_farmers_by_id(farmer_ids)
    farmer_ids.map { |farmer_id| training_participation_target_farmer_key(farmer_id) }.uniq
  end

  def training_total_farmer_count_from_records(records)
    Array(records).sum { |record| training_record_selected_farmer_ids(record).size }
  end

  def training_participation_farmer_unique_key(farmer_id, farmer: nil, saved_name: nil, location_key: nil)
    tracenet = normalize_dashboard_text(farmer&.tracenet_no)
    normalized_name = normalize_dashboard_text(saved_name.presence || farmer&.farmer_name)
    normalized_location = location_key.presence

    if tracenet.present?
      "tracenet:#{tracenet}"
    elsif normalized_name.present?
      "name:#{normalized_name}|#{normalized_location}"
    else
      "id:#{farmer_id}"
    end
  end

  def training_participation_target_farmer_key(farmer_id)
    farmer_id = farmer_id.to_s.strip
    return "id:#{farmer_id}" if farmer_id.blank?

    farmer = training_farmers_by_id([farmer_id])[farmer_id]
    tracenet = normalize_dashboard_text(farmer&.tracenet_no)
    tracenet.present? && tracenet != "null" ? "tracenet:#{tracenet}" : "id:#{farmer_id}"
  end

  def training_participation_farmer_rows_from_records(records)
    records = Array(records)
    return [] if records.blank?

    farmer_ids = records.flat_map { |record| training_record_selected_farmer_ids(record) }.uniq
    farmers_by_id = training_farmers_by_id(farmer_ids)
    memberships = Hash.new do |hash, farmer_key|
      hash[farmer_key] = {
        farmer_key: farmer_key,
        farmer_id: nil,
        months: [],
        ics: [],
        village: [],
        vrp: [],
        fcoc: [],
        cluster_incharge: [],
        jeevika_jankar_name: [],
        target_owner: [],
        registered_by: [],
        main_activities: [],
        sub_activities: [],
        training_dates: [],
        training_register_urls: [],
        training_photo_urls: [],
        attendance_count: 0
      }
    end

    records.each do |record|
      summary = training_summary(record)
      training_date = bill_display_date(summary[:training_date]).presence || bill_display_date(record.created_at)
      saved_names = Array(record.data["selected_farmer_names"]).map(&:to_s)
      location_key = [record.data["ics_block"], record.data["gram_name"]]
        .map { |value| normalize_dashboard_text(value) }
        .reject(&:blank?)
        .join("|")

      training_record_selected_farmer_ids(record).each_with_index do |farmer_id, index|
        farmer = farmers_by_id[farmer_id]
        farmer_key = training_participation_farmer_unique_key(
          farmer_id,
          farmer: farmer,
          saved_name: saved_names[index],
          location_key: location_key
        )
        membership = memberships[farmer_key]
        membership[:farmer_id] ||= farmer_id
        membership[:months] |= [summary[:month].to_s.strip].reject(&:blank?)
        membership[:ics] |= [record.data["ics_block"].presence || record.data["ics"]].map(&:to_s).map(&:strip).reject(&:blank?)
        membership[:village] |= [record.data["gram_name"].presence || record.data["village"]].map(&:to_s).map(&:strip).reject(&:blank?)
        membership[:vrp] |= [record.data["trainer_name"].presence || record.data["jeevika_jankar_name"].presence || record.data["vrp_name"]].map(&:to_s).map(&:strip).reject(&:blank?)
        membership[:fcoc] |= [summary[:department].presence || record.data["fco"].presence || record.data["fcoc"].presence || record.data["fco_name"]].map(&:to_s).map(&:strip).reject(&:blank?)
        membership[:cluster_incharge] |= [record.data["cluster_incharge"].presence || record.data["cluster_coordinator"]].map(&:to_s).map(&:strip).reject(&:blank?)
        membership[:jeevika_jankar_name] |= [record.data["trainer_name"].presence || record.data["jeevika_jankar_name"].presence || record.data["vrp_name"]].map(&:to_s).map(&:strip).reject(&:blank?)
        membership[:target_owner] |= [record.data["trainer_name"].presence || record.data["jeevika_jankar_name"].presence || record.data["vrp_name"]].map(&:to_s).map(&:strip).reject(&:blank?)
        membership[:registered_by] |= [record.data["created_by_name"].presence || record.data["created_by_username"]].map(&:to_s).map(&:strip).reject(&:blank?)
        membership[:main_activities] |= [summary[:training_topic].to_s.strip].reject(&:blank?)
        membership[:sub_activities] |= [summary[:training_subject].to_s.strip].reject(&:blank?)
        membership[:training_dates] |= [training_date].reject(&:blank?)
        membership[:training_register_urls] |= module_upload_public_urls(record.data["training_register_upload"])
        membership[:training_photo_urls] |= module_upload_public_urls(record.data["training_photo_upload_with_geo_tag"])
        membership[:attendance_count] += 1
      end
    end

    memberships.values.map do |membership|
      farmer_id = membership[:farmer_id]
      farmer = farmers_by_id[farmer_id]
      attendance_count = membership[:attendance_count].to_i
      status = training_participation_status_for_count(attendance_count)
      dates = membership[:training_dates].sort_by { |date| parse_module_date(date)&.to_time || Time.zone.local(1900, 1, 1) }

      {
        farmer_id: farmer_id,
        farmer_name: dashboard_text_value(farmer&.farmer_name).presence || "Farmer ##{farmer_id}",
        father_name: dashboard_text_value(farmer&.father_name),
        mobile_no: dashboard_text_value(farmer&.mobile_no),
        tracenet_no: dashboard_text_value(farmer&.tracenet_no),
        khasara_no: dashboard_text_value(farmer&.khasara_no),
        ics: membership[:ics].presence&.join(", ") || dashboard_text_value(farmer&.ics_name).presence || dashboard_text_value(farmer&.ics_id).presence || "-",
        village: membership[:village].presence&.join(", ") || dashboard_text_value(farmer&.village_name).presence || dashboard_text_value(farmer&.village_id).presence || "-",
        vrp: membership[:vrp].presence&.join(", ") || "-",
        fcoc: membership[:fcoc].presence&.join(", ") || "-",
        cluster_incharge: membership[:cluster_incharge].presence&.join(", ") || "-",
        jeevika_jankar_name: membership[:jeevika_jankar_name].presence&.join(", ") || membership[:vrp].presence&.join(", ") || "-",
        target_owner: membership[:jeevika_jankar_name].presence&.join(", ") || membership[:target_owner].presence&.join(", ") || membership[:vrp].presence&.join(", ") || "-",
        registered_by: membership[:registered_by].presence&.join(", ") || "-",
        months: membership[:months].presence&.join(", ") || "-",
        main_activities: membership[:main_activities].presence&.join(", ") || "-",
        sub_activities: membership[:sub_activities].presence&.join(", ") || "-",
        attendance_count: attendance_count,
        status: status,
        status_label: training_participation_status_label(status),
        training_dates: dates.join(", ").presence || "-",
        last_training_date: dates.last.presence || "-",
        training_register_urls: membership[:training_register_urls],
        training_photo_urls: membership[:training_photo_urls]
      }
    end.sort_by { |row| [row[:status], -row[:attendance_count], row[:farmer_name].to_s.downcase] }
  end

  def training_participation_status_counts(targets, month_name: nil)
    rows = training_participation_farmer_rows(targets, month_name: month_name)

    {
      green: rows.count { |row| row[:status] == "green" },
      yellow: rows.count { |row| row[:status] == "yellow" },
      red: rows.count { |row| row[:status] == "red" },
      pending: rows.count { |row| row[:status] == "pending" },
      total: rows.size
    }
  end

  def training_participation_farmer_rows(targets, month_name: nil)
    targets = Array(targets)
    return [] if targets.blank?

    memberships = training_participation_target_memberships(targets)
    return [] if memberships.blank?

    attendance_details = training_attendance_details_for_targets(targets, month_name: month_name)
    farmers_by_id = training_farmers_by_id(memberships.values.map { |membership| membership[:farmer_id] })

    memberships.map do |membership_key, membership|
      farmer_id = membership[:farmer_id]
      farmer = farmers_by_id[farmer_id]
      details = attendance_details[membership_key] || { attendance_count: 0, training_dates: [] }
      completed_activity_count = details.fetch(:completed_activity_count, 0).to_i
      attendance_count = training_participation_effective_attendance_count(details[:attendance_count], completed_activity_count)
      status = training_participation_status_for_activity_progress(
        attendance_count,
        completed_activity_count,
        membership[:assigned_activity_count].to_i,
        pending_available: membership[:pending_available]
      )

      {
        farmer_id: farmer_id,
        farmer_name: dashboard_text_value(farmer&.farmer_name).presence || "Farmer ##{farmer_id}",
        father_name: dashboard_text_value(farmer&.father_name),
        mobile_no: dashboard_text_value(farmer&.mobile_no),
        tracenet_no: dashboard_text_value(farmer&.tracenet_no),
        khasara_no: dashboard_text_value(farmer&.khasara_no),
        ics: membership[:ics].presence || dashboard_text_value(farmer&.ics_name).presence || dashboard_text_value(farmer&.ics_id).presence || "-",
        village: membership[:village].presence || dashboard_text_value(farmer&.village_name).presence || dashboard_text_value(farmer&.village_id).presence || "-",
        vrp: membership[:vrp].presence || "-",
        fcoc: membership[:fcoc].presence || "-",
        cluster_incharge: membership[:cluster_incharge].presence || "-",
        jeevika_jankar_name: membership[:jeevika_jankar_name].presence || membership[:vrp].presence || "-",
        target_owner: membership[:jeevika_jankar_name].presence || membership[:target_owner].presence || membership[:vrp].presence || "-",
        registered_by: membership[:registered_by].presence || "-",
        months: membership[:months].presence || "-",
        main_activities: membership[:main_activities].presence || "-",
        sub_activities: membership[:sub_activities].presence || "-",
        attendance_count: attendance_count,
        assigned_activity_count: membership[:assigned_activity_count].to_i,
        completed_activity_count: completed_activity_count,
        status: status,
        status_label: training_participation_status_label(status),
        training_dates: details[:training_dates].presence || "-",
        last_training_date: details[:last_training_date].presence || "-"
      }
    end.sort_by { |row| [row[:status], -row[:attendance_count], row[:farmer_name].to_s.downcase] }
  end

  def training_participation_target_memberships(targets)
    targets = Array(targets)
    cache_key = targets.map { |target| target.id.to_s }.sort.join(":")
    @training_participation_target_memberships_cache ||= {}
    return @training_participation_target_memberships_cache[cache_key] if @training_participation_target_memberships_cache.key?(cache_key)

    # Prime all farmer IDs in one query. Without this, each target mapping can
    # issue its own AFL existence query while the memberships are built.
    valid_farmer_ids = training_participation_existing_farmer_id_set(targets).to_a
    # Farmer identity keys use TraceNet numbers where available. Load those
    # farmers in batches before the target loop instead of one SELECT per ID.
    training_farmers_by_id(valid_farmer_ids)
    memberships = targets.each_with_object({}) do |target, memberships|
      training_participation_target_farmer_ids(target).each do |farmer_id|
        unique_farmer_key = training_participation_target_farmer_key(farmer_id)
        membership_key = training_participation_membership_key(unique_farmer_key, target.month_name)
        memberships[membership_key] ||= {
          farmer_id: farmer_id.to_s,
          source_farmer_ids: [],
          months: [],
          ics: [],
          village: [],
          vrp: [],
          fcoc: [],
          cluster_incharge: [],
          jeevika_jankar_name: [],
          target_owner: [],
          registered_by: [],
          main_activities: [],
          sub_activities: [],
          assigned_activity_keys: [],
          assigned_activity_count: 0,
          pending_available: false
        }

        memberships[membership_key][:months] |= [target.month_name.to_s.strip].reject(&:blank?)
        memberships[membership_key][:ics] |= [target_ics_label(target).to_s.strip].reject(&:blank?)
        memberships[membership_key][:village] |= [target_village_label(target).to_s.strip].reject(&:blank?)
        memberships[membership_key][:vrp] |= [target.vrp&.name.to_s.strip].reject(&:blank?)
        memberships[membership_key][:fcoc] |= [target.fco_name.to_s.strip, target.vrp&.fcoc.to_s.strip].reject(&:blank?)
        memberships[membership_key][:cluster_incharge] |= [target.vrp&.cluster_incharge.to_s.strip].reject(&:blank?)
        memberships[membership_key][:jeevika_jankar_name] |= [target.vrp&.name.to_s.strip].reject(&:blank?)
        memberships[membership_key][:target_owner] |= [target.vrp&.name.to_s.strip].reject(&:blank?)
        memberships[membership_key][:registered_by] |= [target_mapping_registered_by_name(target)].reject(&:blank?)
        memberships[membership_key][:main_activities] |= [target.main_activity_name.to_s.strip].reject(&:blank?)
        memberships[membership_key][:sub_activities] |= [target.activity_name.to_s.strip].reject(&:blank?)
        memberships[membership_key][:assigned_activity_keys] |= training_participation_target_activity_keys(target)
        memberships[membership_key][:pending_available] ||= training_participation_month_open?(target.month_name)
        memberships[membership_key][:source_farmer_ids] |= [farmer_id.to_s]
      end
    end.transform_values do |membership|
      membership[:assigned_activity_count] = membership[:assigned_activity_keys].size
      membership.delete(:assigned_activity_keys)
      membership.transform_values do |values|
        values.is_a?(Array) ? values.uniq.join(", ") : values
      end
    end
    @training_participation_target_memberships_cache[cache_key] = memberships
  end

  def training_participation_target_map_rows(targets, month_name: nil)
    targets = Array(targets)
    return [] if targets.blank?

    attendance_details = training_attendance_details_for_targets(targets, month_name: month_name)
    memberships = training_participation_target_memberships(targets)
    farmers_by_id = training_farmers_by_id(training_participation_valid_farmer_ids_for_targets(targets))

    rows_by_map_key = {}
    targets.each do |target|
      training_participation_target_activity_entries(target).each_with_index do |activity_entry, activity_index|
        activity_key = activity_entry[:key]
        training_participation_target_farmer_ids(target).each do |farmer_id|
          farmer_key = training_participation_target_farmer_key(farmer_id)
          membership_key = training_participation_membership_key(farmer_key, target.month_name)
          details = attendance_details[membership_key] || { attendance_count: 0, training_dates: "", completed_activity_keys: [] }
          completed_keys = Array(details[:completed_activity_keys])
          farmer = farmers_by_id[farmer_id.to_s]
          assigned_count = memberships.dig(membership_key, :assigned_activity_count).to_i
          completed_count = [completed_keys.size, assigned_count].min
          attendance_count = training_participation_effective_attendance_count(details[:attendance_count], completed_count)
          completed = completed_keys.include?(activity_key)
          status = if completed_count >= assigned_count && assigned_count.positive?
            "green"
          elsif completed_count.positive?
            "yellow"
          else
            "red"
          end
          map_key = [membership_key, activity_key].join("::")
          next if rows_by_map_key.key?(map_key)

          rows_by_map_key[map_key] = {
            farmer_id: farmer_id.to_s,
            farmer_name: dashboard_text_value(farmer&.farmer_name).presence || "Farmer ##{farmer_id}",
            father_name: dashboard_text_value(farmer&.father_name),
            mobile_no: dashboard_text_value(farmer&.mobile_no),
            tracenet_no: dashboard_text_value(farmer&.tracenet_no),
            khasara_no: dashboard_text_value(farmer&.khasara_no),
            ics: target_ics_label(target).presence || dashboard_text_value(farmer&.ics_name).presence || dashboard_text_value(farmer&.ics_id).presence || "-",
            village: target_village_label(target).presence || dashboard_text_value(farmer&.village_name).presence || dashboard_text_value(farmer&.village_id).presence || "-",
            vrp: target.vrp&.name.presence || "-",
            fcoc: target.fco_name.presence || target.vrp&.fcoc.presence || target.fco_id.presence || "-",
            cluster_incharge: target.vrp&.cluster_incharge.presence || "-",
            jeevika_jankar_name: target.vrp&.name.presence || "-",
            target_owner: target.vrp&.name.presence || "-",
            registered_by: target_mapping_registered_by_name(target),
            months: target.month_name.to_s.presence || "-",
            main_activities: activity_entry[:main_activity].presence || target.main_activity_name.to_s.presence || "-",
            sub_activities: activity_entry[:sub_activity].presence || target.activity_name.to_s.presence || "-",
            attendance_count: completed ? 1 : 0,
            assigned_activity_count: 1,
            completed_activity_count: completed ? 1 : 0,
            status: status,
            status_label: training_participation_status_label(status),
            training_dates: completed ? details[:training_dates].presence || "-" : "-",
            last_training_date: completed ? details[:last_training_date].presence || "-" : "-",
            training_register_urls: [],
            training_photo_urls: []
          }
        end
      end
    end
    rows_by_map_key.values.sort_by { |row| [row[:status], row[:farmer_name].to_s.downcase, row[:sub_activities].to_s.downcase] }
  end

  def target_mapping_registered_by_name(target)
    return "-" unless target.respond_to?(:created_by_id) && target.created_by_id.present?

    creator_type = target.created_by_type.to_s
    user = if creator_type == "User" && model_ready?(:User)
      cached_user_find_by(id: target.created_by_id)
    end
    if user
      return [user.try(:first_name), user.try(:last_name)].compact_blank.join(" ").presence ||
        user.try(:full_name).presence ||
        user.try(:user_name).presence ||
        "User ##{target.created_by_id}"
    end

    record = if creator_type == "ModuleRecord" && model_ready?(:ModuleRecord)
      cached_module_record_find_by_id(target.created_by_id)
    end
    if record
      return [
        record.data["name"],
        [record.data["first_name"], record.data["last_name"]].compact_blank.join(" "),
        record.data["user_name"],
        record.data["email"]
      ].compact_blank.first || "User ##{target.created_by_id}"
    end

    "User ##{target.created_by_id}"
  end

  def training_attendance_details_for_targets(targets, month_name: nil, week_number: nil)
    return {} unless model_ready?(:ModuleRecord)

    target_sets = Array(targets).filter_map do |target|
      farmer_ids = training_participation_target_farmer_ids(target)
      farmer_ids.blank? ? nil : [target, farmer_ids]
    end
    return {} if target_sets.blank?

    target_sets_by_farmer_id = Hash.new { |hash, key| hash[key] = [] }
    target_sets.each do |target_set|
      _target, farmer_ids = target_set
      farmer_ids.each { |farmer_id| target_sets_by_farmer_id[farmer_id.to_s] << target_set }
    end
    target_farmer_ids = target_sets_by_farmer_id.keys

    records = ModuleRecord
      .where(module_slug: "training-form")
      .order(created_at: :desc)
    if month_name.present?
      records = records.where("LOWER(BTRIM(data::jsonb ->> 'month')) = ?", month_name.to_s.strip.downcase)
    end
    records = training_record_scope_for_farmer_ids(records, target_farmer_ids) if target_farmer_ids.any?
    records = records
      .select { |record| week_number.blank? || training_record_week_number(record) == week_number.to_i }

    preload_training_target_mappings_for_records!(records)
    records.each_with_object(Hash.new { |hash, key| hash[key] = { attendance_count: 0, training_dates: [], completed_activity_keys: [] } }) do |record, details|
        selected_farmer_ids = training_record_selected_farmer_ids(record)
        candidate_target_sets = selected_farmer_ids.flat_map { |farmer_id| target_sets_by_farmer_id[farmer_id.to_s] }.uniq
        matching_membership_keys = candidate_target_sets.each_with_object({}) do |(target, farmer_ids), keys|
          next unless training_record_matches_dashboard_target?(record, target, farmer_ids)

          (selected_farmer_ids & farmer_ids).each do |farmer_id|
            unique_farmer_key = training_participation_target_farmer_key(farmer_id)
            membership_key = training_participation_membership_key(unique_farmer_key, target.month_name)
            keys[membership_key] ||= []
            keys[membership_key] |= training_record_completed_activity_keys_for_target(record, target)
          end
        end
        next if matching_membership_keys.blank?

        training_date = bill_display_date(training_summary(record)[:training_date]).presence || bill_display_date(record.created_at)
        matching_membership_keys.each do |membership_key, activity_keys|
          details[membership_key][:attendance_count] += 1
          details[membership_key][:training_dates] |= [training_date].reject(&:blank?)
          details[membership_key][:completed_activity_keys] |= Array(activity_keys)
        end
      end.transform_values do |detail|
        dates = detail[:training_dates].sort_by { |date| parse_module_date(date)&.to_time || Time.zone.local(1900, 1, 1) }
        detail.merge(
          training_dates: dates.join(", "),
          last_training_date: dates.last,
          completed_activity_count: detail[:completed_activity_keys].size,
          completed_activity_keys: detail[:completed_activity_keys]
        )
      end
  end

  def training_farmers_by_id(farmer_ids)
    return {} unless model_ready?(:Afl)

    ids = Array(farmer_ids).map(&:to_s).reject(&:blank?).uniq
    return {} if ids.blank?

    @training_farmers_by_id_cache ||= {}
    missing_ids = ids.reject { |id| @training_farmers_by_id_cache.key?(id) }
    load_training_farmers_in_batches(missing_ids).each do |farmer|
      @training_farmers_by_id_cache[farmer.id.to_s] = farmer
    end
    missing_ids.each { |id| @training_farmers_by_id_cache[id] = nil unless @training_farmers_by_id_cache.key?(id) }

    ids.index_with { |id| @training_farmers_by_id_cache[id] }.compact
  end

  def preload_training_farmers_for_targets!(targets)
    farmer_ids = training_participation_valid_farmer_ids_for_targets(targets)
    training_farmers_by_id(farmer_ids)
  end

  def load_training_farmers_in_batches(farmer_ids)
    Array(farmer_ids).each_slice(5_000).flat_map do |ids|
      Afl
        .where(id: ids)
        .select(:id, :farmer_name, :father_name, :mobile_no, :tracenet_no, :khasara_no, :ics_name, :ics_id, :village_name, :village_id)
        .to_a
    end
  end

  def training_participation_membership_key(farmer_id, month_name)
    [farmer_id.to_s, normalize_dashboard_text(month_name)].join("|")
  end

  def training_participation_target_location_key(target)
    [
      target_ics_label(target).to_s.strip,
      target_village_label(target).to_s.strip
    ].reject(&:blank?).join("|")
  end

  def training_participation_target_activity_key(target)
    training_participation_target_activity_keys(target).first
  end

  def training_participation_target_activity_keys(target)
    training_participation_target_activity_entries(target).map { |entry| entry[:key] }
  end

  def training_participation_target_activity_entries(target)
    main_activity = target.main_activity_name.to_s.strip
    sub_activities = training_activity_values(target.activity_name, normalize: false)
    sub_activities = [target.activity_name.to_s.strip] if sub_activities.blank?

    sub_activities.map do |sub_activity|
      {
        main_activity: main_activity,
        sub_activity: sub_activity,
        key: [
          normalize_dashboard_text(main_activity),
          normalize_dashboard_text(sub_activity)
        ].join("|")
      }
    end.uniq { |entry| entry[:key] }
  end

  def training_record_completed_activity_keys_for_target(record, target)
    summary = training_summary(record)
    record_subjects = training_activity_values(record.data["sub_activities"].presence || summary[:training_subject])
    target_entries = training_participation_target_activity_entries(target)
    matched_entries = target_entries.select do |entry|
      target_subject = normalize_dashboard_text(entry[:sub_activity])
      record_subjects.any? { |subject| dashboard_training_activity_text_matches?(subject, target_subject) }
    end
    if matched_entries.blank? && target_entries.one? && training_record_matches_dashboard_target?(record, target, training_participation_target_farmer_ids(target))
      matched_entries = target_entries
    end
    matched_entries.map { |entry| entry[:key] }
  end

  def training_participation_status_for_activity_progress(attendance_count, completed_count, assigned_count, pending_available: false)
    completed_count = completed_count.to_i
    assigned_count = assigned_count.to_i
    return "pending" if pending_available && assigned_count.zero?
    return "red" if completed_count.zero?
    return "green" if assigned_count.positive? && completed_count >= assigned_count

    "yellow"
  end

  def training_participation_effective_attendance_count(attendance_count, completed_activity_count)
    [attendance_count.to_i, completed_activity_count.to_i].max
  end

  def training_participation_status_for_count(count, pending_available: false)
    count = count.to_i
    return "green" if count >= 2
    return "yellow" if count == 1

    "red"
  end

  def normalize_training_participation_status(status)
    value = status.to_s.strip.downcase
    %w[total unique training_unique completed_map green yellow red pending pending_achievement no_activity no_training_mapping no_training training_mapped_no_entry no_entry].include?(value) ? value : nil
  end

  def training_participation_status_label(status)
    {
      "total" => "Multiple Total Target Map",
      "unique" => "Mapped Farmer",
      "no_activity" => "No Activity Mapping",
      "no_training_mapping" => "No Training Mapping",
      "no_training" => "No Training Mapping",
      "training_mapped_no_entry" => "Training Mapped But No Entry",
      "no_entry" => "Training Mapped But No Entry",
      "training_unique" => "Total Complete Farmers",
      "completed_map" => "Multiple Total Complete Training",
      "green" => "1+ Trainings",
      "yellow" => "Only 1 Training",
      "red" => "Pending",
      "pending" => "Pending",
      "pending_achievement" => "Pending Achievement",
      "completed" => "Completed"
    }[status.to_s] || "Farmer"
  end

  def training_participation_status_caption(status)
    {
      "total" => "Farmer x mapped activity target entries.",
      "unique" => "Unique mapped farmers for the selected filters.",
      "no_activity" => "Farmers not mapped to any activity.",
      "no_training_mapping" => "Farmers mapped to activity but not mapped to Farmers' Training.",
      "no_training" => "Farmers mapped to activity but not mapped to Farmers' Training.",
      "training_mapped_no_entry" => "Farmers mapped to Farmers' Training but with zero training entries.",
      "no_entry" => "Farmers mapped to Farmers' Training but with zero training entries.",
      "training_unique" => "Mapped farmers with at least one completed training.",
      "completed_map" => "Multiple total target map me completed training count.",
      "green" => "Farmer attended more than 1 training.",
      "yellow" => "Farmer attended only 1 training.",
      "red" => "Farmer not attended training. Missing training.",
      "pending" => "Month open and farmer training is still pending.",
      "pending_achievement" => "Red and yellow farmer achievement rows."
    }[status.to_s] || "Farmer training participation status."
  end

  def training_participation_rows_csv(rows)
    CSV.generate(headers: true) do |csv|
      csv << training_participation_export_headers
      training_participation_export_rows(rows).each { |row| csv << row }
    end
  end

  def training_participation_export_headers
    [
      "Farmer ID",
      "Farmer",
      "Father Name",
      "Mobile",
      "TraceNet No",
      "ICS",
      "Village",
      "FCOC",
      "ClusterCoordinator",
      "Jeevika Jankar Name",
      "Registered By",
      "Target Months",
      "Main Activities",
      "Sub Activities",
      "Training Count",
      "Status",
      "Training Dates",
      "Last Training Date",
      "Training Register Upload",
      "Training Photo Upload with Geo Tag"
    ]
  end

  def training_participation_export_rows(rows)
    Array(rows).map do |row|
      [
        row[:farmer_id],
        row[:farmer_name],
        row[:father_name],
        row[:mobile_no],
        row[:tracenet_no],
        row[:ics],
        row[:village],
        row[:fcoc],
        row[:cluster_incharge],
        row[:jeevika_jankar_name].presence || row[:target_owner].presence || row[:vrp],
        row[:registered_by],
        row[:months],
        row[:main_activities],
        row[:sub_activities],
        row[:attendance_count],
        row[:status_label],
        row[:training_dates],
        row[:last_training_date],
        Array(row[:training_register_urls]).join(", "),
        Array(row[:training_photo_urls]).join(", ")
      ]
    end
  end

  def training_participation_attachments_zip(rows)
    files = training_participation_attachment_files(rows)

    Zip::OutputStream.write_buffer do |zip|
      files.each do |file|
        zip.put_next_entry(file[:name])
        zip.write(file[:content])
      end
    end.string
  end

  def training_participation_attachment_files(rows)
    used_names = Hash.new(0)

    Array(rows).flat_map do |row|
      attachment_urls = Array(row[:training_register_urls]) + Array(row[:training_photo_urls])
      attachment_urls.filter_map do |url|
        attachment = module_upload_attachment_file(url)
        next if attachment.blank?

        base_name = attachment[:name].presence || "attachment"
        used_names[base_name] += 1
        file_name = if used_names[base_name] > 1
          extension = File.extname(base_name)
          stem = File.basename(base_name, extension)
          "#{stem}-#{used_names[base_name]}#{extension}"
        else
          base_name
        end

        { name: file_name, content: attachment[:content] }
      end
    end
  end

  def module_upload_attachment_file(url)
    return if url.blank?

    uri = URI.parse(url.to_s)
    path = uri.path.to_s
    return if path.blank?

    public_path = Rails.root.join("public", path.delete_prefix("/"))
    return unless public_path.exist? && public_path.file?

    {
      name: File.basename(public_path.to_s),
      content: public_path.binread
    }
  rescue URI::InvalidURIError
    nil
  end

  def training_target_status_cards(targets, month_name: nil, sub_activity_name: nil)
    counts = training_target_status_counts(targets)

    %w[green yellow red].map do |status|
      path_params = { status: status }
      path_params[:training_month] = month_name if month_name.present?
      path_params[:training_sub_activity] = sub_activity_name if sub_activity_name.present?

      {
        status: status,
        title: training_target_status_label(status),
        value: counts[status.to_sym].to_i,
        caption: training_target_status_caption(status),
        path: farmer_training_target_status_path(path_params)
      }
    end
  end

  def training_target_status_rows(targets)
    dashboard_target_assignment_groups(targets)
      .map { |group| combined_training_target_detail_row(group) }
      .sort_by do |row|
        [
          dashboard_month_index(row[:month]),
          row[:completion_date_sort].presence || Date.new(9999, 12, 31),
          row[:vrp].to_s,
          row[:ics].to_s,
          row[:village].to_s,
          row[:main_activity].to_s,
          row[:sub_activity].to_s
        ]
      end
  end

  def combined_training_target_detail_row(targets)
    targets = Array(targets)
    rows = targets.map { |target| training_target_detail_row(target) }
    first = rows.first
    return first if rows.one?

    main_activities = rows.map { |row| row[:main_activity].to_s.strip }.reject(&:blank?).uniq
    sub_activities = rows.map { |row| row[:sub_activity].to_s.strip }.reject(&:blank?).uniq
    assigned_ids = rows.flat_map { |row| Array(row[:assigned_farmer_ids]) }.map(&:to_s).reject(&:blank?).uniq
    completed_ids = unique_training_farmer_ids(rows.flat_map { |row| Array(row[:completed_farmer_ids]) })
    weekly_ids = (0..3).map do |index|
      unique_training_farmer_ids(rows.flat_map { |row| Array(row[:weekly_completed_farmer_ids])[index] || [] })
    end
    target_quantity = assigned_ids.any? ? assigned_ids.size.to_f : rows.map { |row| row[:target_quantity].to_f }.max.to_f
    completed_quantity = assigned_ids.any? ? completed_ids.size.to_f : rows.map { |row| row[:completed_quantity].to_f }.max.to_f
    completed_quantity = [completed_quantity, target_quantity].min
    pending_quantity = [target_quantity - completed_quantity, 0].max
    progress_percent = target_quantity.positive? ? ((completed_quantity / target_quantity) * 100).round : 0
    status_class = training_target_status_for_percent(progress_percent)

    first.merge(
      target_mapping_ids: rows.map { |row| row[:target_mapping_id] }.compact_blank.uniq,
      main_activity: main_activities.join("\n"),
      sub_activity: sub_activities.join("\n"),
      assigned_farmer_ids: assigned_ids,
      completed_farmer_ids: completed_ids,
      weekly_completed_farmer_ids: weekly_ids,
      weekly_targets: (0..3).map { |index| rows.map { |row| Array(row[:weekly_targets])[index].to_f }.max.to_f },
      weekly_achievements: weekly_ids.map(&:size),
      target_quantity: target_quantity,
      completed_quantity: completed_quantity,
      pending_quantity: pending_quantity,
      progress_percent: progress_percent,
      status_class: status_class,
      status_label: training_target_status_label(status_class),
      training_register_urls: rows.flat_map { |row| Array(row[:training_register_urls]) }.uniq,
      training_photo_urls: rows.flat_map { |row| Array(row[:training_photo_urls]) }.uniq,
      completed_farmers: training_farmers_for_ids(completed_ids).map { |farmer| farmer.merge(status_label: "Completed", status_class: "green") },
      pending_farmers: training_farmers_for_ids(assigned_ids - completed_ids).map { |farmer| farmer.merge(status_label: "Pending", status_class: "red") }
    )
  end

  def training_target_status_counts(targets)
    rows = training_target_status_rows(targets)

    {
      green: rows.count { |row| row[:status_class] == "green" },
      yellow: rows.count { |row| row[:status_class] == "yellow" },
      red: rows.count { |row| row[:status_class] == "red" },
      total: rows.size
    }
  end

  def training_target_status_label(status)
    {
      "green" => "1 Training",
      "yellow" => "2+ Trainings",
      "red" => "No Training"
    }[status.to_s] || "Target"
  end

  def training_target_status_caption(status)
    {
      "green" => "Target 100% completed by Completion Date.",
      "yellow" => "Target progress is 75% to 99%.",
      "red" => "Target progress is below 75% or no training done."
    }[status.to_s] || "Target completion status."
  end

  def normalize_training_target_status(status)
    value = status.to_s.strip.downcase
    %w[green yellow red].include?(value) ? value : nil
  end

  def training_target_status_for_percent(percent)
    value = percent.to_f
    return "green" if value >= 100
    return "yellow" if value >= 75

    "red"
  end

  def training_target_status_rows_csv(rows)
    CSV.generate(headers: true) do |csv|
      csv << [
        "Target Mapping ID",
        "VRP",
        "Month",
        "Completion Date",
        "ICS",
        "Village",
        "Main Activity",
        "Sub Activity",
        "Target",
        "Completed",
        "Pending",
        "Progress %",
        "Status",
        "Training Register Upload",
        "Training Photo Upload with Geo Tag"
      ]

      Array(rows).each do |row|
        csv << [
          row[:target_mapping_id],
          row[:vrp],
          row[:month],
          row[:completion_date],
          row[:ics],
          row[:village],
          row[:main_activity],
          row[:sub_activity],
          dashboard_quantity(row[:target_quantity]),
          dashboard_quantity(row[:completed_quantity]),
          dashboard_quantity(row[:pending_quantity]),
          row[:progress_percent],
          row[:status_label],
          Array(row[:training_register_urls]).join(", "),
          Array(row[:training_photo_urls]).join(", ")
        ]
      end
    end
  end

  def training_participation_summary(targets, month_name: nil)
    targets = Array(targets)
    attendance_counts = training_attendance_counts_for_targets(targets, month_name: month_name)
    ics_memberships = Hash.new { |hash, key| hash[key] = { label: "", farmer_ids: [] } }
    village_memberships = Hash.new { |hash, key| hash[key] = { ics: "", village: "", farmer_ids: [] } }

    targets.each do |target|
      farmer_ids = Array(target.respond_to?(:afl_ids) ? target.afl_ids : []).map(&:to_s).reject(&:blank?).uniq
      next if farmer_ids.blank?

      ics = target_ics_label(target)
      village = target_village_label(target)
      ics_key = normalize_dashboard_text(ics)
      village_key = [ics_key, normalize_dashboard_text(village)].join("|")

      ics_memberships[ics_key][:label] = ics
      ics_memberships[ics_key][:farmer_ids].concat(farmer_ids)
      village_memberships[village_key][:ics] = ics
      village_memberships[village_key][:village] = village
      village_memberships[village_key][:farmer_ids].concat(farmer_ids)
    end

    ics_rows = ics_memberships.values.map do |row|
      counts = training_status_counts(row[:farmer_ids].uniq, attendance_counts)
      row.merge(counts)
    end.sort_by { |row| row[:label].to_s }

    village_rows = village_memberships.values.map do |row|
      counts = training_status_counts(row[:farmer_ids].uniq, attendance_counts)
      row.merge(counts)
    end.sort_by { |row| [row[:ics].to_s, row[:village].to_s] }

    {
      totals: training_status_counts(ics_memberships.values.flat_map { |row| row[:farmer_ids] }.uniq, attendance_counts).merge(
        cumulative_participants: attendance_counts.values.sum,
        monthly_unique: attendance_counts.keys.size
      ),
      ics_rows: ics_rows,
      village_rows: village_rows
    }
  end

  def ics_farmer_report_options(records, targets = [])
    record_options = Array(records).map do |record|
      summary = training_summary(record)
      summary[:ics].presence || record.data["ics_block"].presence || record.data["ics"].presence
    end

    target_options = Array(targets).map { |target| target_ics_label(target) }

    (record_options + target_options)
      .map { |value| value.to_s.strip }
      .reject(&:blank?)
      .reject { |value| value == "-" }
      .uniq
      .sort
  end

  def ics_farmer_report_rows(targets, records, selected_ics: nil)
    targets = Array(targets)
    records = Array(records)
    return [] if targets.blank?

    selected_ics_key = normalize_dashboard_text(selected_ics)
    targets = targets.select do |target|
      selected_ics_key.blank? || normalize_dashboard_text(target_ics_label(target)) == selected_ics_key
    end
    return [] if targets.blank?

    farmer_ids = targets.flat_map { |target| target_farmer_ids(target) }.uniq
    farmers_by_id = training_farmers_by_id(farmer_ids)
    farmer_profiles_by_id = dashboard_farmer_profiles_by_id(farmer_ids)

    rows = targets.flat_map do |target|
      target_farmer_ids(target).map do |farmer_id|
        farmer = farmers_by_id[farmer_id.to_s]
        farmer_profile = farmer_profiles_by_id[farmer_id.to_s] || {}
        matching_records = records.select do |record|
          training_record_matches_dashboard_target?(record, target, [farmer_id.to_s])
        end
        summary_rows = matching_records.map { |record| training_summary(record) }
        training_dates = matching_records.map do |record|
          summary = training_summary(record)
          bill_display_date(summary[:training_date]).presence || bill_display_date(record.created_at)
        end.compact_blank.uniq

        {
          farmer_id: farmer_id.to_s,
          farmer_name: dashboard_text_value(farmer_profile[:farmer_name]).presence || dashboard_text_value(farmer&.farmer_name).presence || "Farmer ##{farmer_id}",
          father_name: dashboard_text_value(farmer_profile[:father_name]).presence || dashboard_text_value(farmer&.father_name),
          mobile_no: dashboard_text_value(farmer_profile[:mobile_no]).presence || dashboard_text_value(farmer&.mobile_no),
          tracenet_no: dashboard_text_value(farmer_profile[:tracenet_no]).presence || dashboard_text_value(farmer&.tracenet_no),
          month: target.month_name.presence || "-",
          village: dashboard_text_value(farmer&.village_name).presence || target_village_label(target),
          ics: dashboard_text_value(farmer&.ics_name).presence || dashboard_text_value(farmer&.ics_id).presence || target_ics_label(target),
          vrp_name: target.vrp&.name.presence || "VRP ##{target.vrp_id}",
          main_activity: target.main_activity_name.presence || "-",
          sub_activity: target.activity_name.presence || "-",
          training_date: training_dates.last.presence || "-",
          training_dates: training_dates.join(", ").presence || "-",
          training_register_urls: matching_records.flat_map { |record| module_upload_public_urls(record.data["training_register_upload"]) }.compact_blank.uniq,
          training_photo_urls: matching_records.flat_map { |record| module_upload_public_urls(record.data["training_photo_upload_with_geo_tag"]) }.compact_blank.uniq,
          trained: matching_records.any?,
          participation_count: summary_rows.size
        }
      end
    end

    rows
      .group_by do |row|
        [
          row[:farmer_id],
          row[:ics],
          row[:village],
          row[:vrp_name],
          row[:main_activity],
          row[:sub_activity]
        ]
      end
      .values
      .map do |grouped|
        first = grouped.first
        first.merge(
          training_dates: grouped.map { |row| row[:training_date] }.compact_blank.uniq.join(", ").presence || "-",
          training_register_urls: grouped.flat_map { |row| Array(row[:training_register_urls]) }.compact_blank.uniq,
          training_photo_urls: grouped.flat_map { |row| Array(row[:training_photo_urls]) }.compact_blank.uniq,
          participation_count: grouped.sum { |row| row[:participation_count].to_i }
        )
      end
      .sort_by { |row| [row[:ics].to_s.downcase, row[:farmer_name].to_s.downcase, row[:main_activity].to_s.downcase, row[:sub_activity].to_s.downcase] }
  end

  def ics_farmer_report_summary(rows, selected_ics: nil)
    rows = Array(rows)
    afl_summary = ics_afl_mapping_summary(selected_ics)
    distinct_farmers = rows.map { |row| row[:farmer_id].to_s }.reject(&:blank?).uniq.size

    {
      farmers: afl_summary[:farmers],
      villages: afl_summary[:villages],
      main_activities: rows.map { |row| row[:main_activity].to_s.strip }.reject(&:blank?).reject { |value| value == "-" }.uniq.size,
      sub_activities: rows.map { |row| row[:sub_activity].to_s.strip }.reject(&:blank?).reject { |value| value == "-" }.uniq.size,
      achievement: distinct_farmers,
      trained_farmers: distinct_farmers
    }
  end

  def ics_farmer_report_export_headers
    ["ICS", "Farmer Name", "Father Name", "Mobile No.", "Tracenet No.", "Village", "Jeevika Jankar", "Month", "Main Activity", "Sub Activity", "Training Date", "Register", "Photo"]
  end

  def ics_farmer_report_export_rows(rows)
    Array(rows).map do |row|
      [
        row[:ics].presence || "-",
        row[:farmer_name].presence || "-",
        row[:father_name].presence || "-",
        row[:mobile_no].presence || "-",
        row[:tracenet_no].presence || "-",
        row[:village].presence || "-",
        row[:vrp_name].presence || "-",
        row[:month].presence || "-",
        row[:main_activity].presence || "-",
        row[:sub_activity].presence || "-",
        row[:training_dates].presence || "-",
        Array(row[:training_register_urls]).join(", "),
        Array(row[:training_photo_urls]).join(", ")
      ]
    end
  end

  def ics_afl_mapping_summary(selected_ics)
    return { farmers: 0, villages: 0 } unless model_ready?(:Afl) && selected_ics.present?

    normalized_ics = normalize_dashboard_text(selected_ics)
    afl_rows = Afl
      .where(
        "LOWER(BTRIM(COALESCE(ics_name, ''))) = :ics OR LOWER(BTRIM(COALESCE(ics_id::text, ''))) = :ics",
        ics: normalized_ics
      )
      .pluck(:id, :village_id, :village_name)

    village_keys = afl_rows.filter_map do |_farmer_id, village_id, village_name|
      normalized_id = normalize_dashboard_text(village_id)
      normalized_name = normalize_dashboard_text(village_name)
      normalized_id.present? ? "id:#{normalized_id}" : ("name:#{normalized_name}" if normalized_name.present?)
    end.uniq

    {
      farmers: afl_rows.map(&:first).uniq.size,
      villages: village_keys.size
    }
  end

  def training_attendance_counts_for_targets(targets, month_name: nil)
    return {} unless model_ready?(:ModuleRecord)

    target_sets = Array(targets).filter_map do |target|
      farmer_ids = target_farmer_ids(target)
      farmer_ids.blank? ? nil : [target, farmer_ids]
    end
    return {} if target_sets.blank?

    ModuleRecord
      .where(module_slug: "training-form")
      .order(created_at: :desc)
      .select { |record| active_module_record?(record) }
      .select { |record| month_name.blank? || normalize_dashboard_text(training_record_month_name(record)) == normalize_dashboard_text(month_name) }
      .each_with_object(Hash.new(0)) do |record, counts|
        matching_farmer_ids = target_sets.each_with_object([]) do |(target, farmer_ids), ids|
          next unless training_record_matches_dashboard_target?(record, target, farmer_ids)

          ids.concat(training_record_selected_farmer_ids(record) & farmer_ids)
        end.uniq

        matching_farmer_ids.each { |farmer_id| counts[farmer_id] += 1 }
      end
  end

  def training_status_counts(farmer_ids, attendance_counts)
    counts = { green: 0, yellow: 0, red: 0, total: farmer_ids.size }

    farmer_ids.each do |farmer_id|
      attended = attendance_counts[farmer_id].to_i
      if attended >= 3
        counts[:green] += 1
      elsif attended.positive?
        counts[:yellow] += 1
      else
        counts[:red] += 1
      end
    end

    counts
  end

  def farmer_training_dashboard_rows(targets, month_name: nil)
    targets = Array(targets)
    return [] if targets.blank? || !model_ready?(:ModuleRecord)

    training_records = ModuleRecord
      .where(module_slug: "training-form")
      .order(created_at: :desc)
      .select { |record| active_module_record?(record) }
      .select { |record| month_name.blank? || normalize_dashboard_text(training_record_month_name(record)) == normalize_dashboard_text(month_name) }

    grouped_targets = targets.each_with_object({}) do |target, groups|
      farmer_ids = target_farmer_ids(target)
      next if farmer_ids.blank?

      key = dashboard_target_assignment_key(target)
      groups[key] ||= {
        month: target.month_name.presence || "-",
        ics: target_ics_label(target),
        village: target_village_label(target),
        activity: [],
        sub_activity: [],
        farmer_ids: [],
        target_quantity: 0.0,
        targets: []
      }
      groups[key][:activity] |= [target.main_activity_name.presence || "Farmer Training"]
      groups[key][:sub_activity] |= [target.activity_name.presence || "-"]
      groups[key][:farmer_ids] |= farmer_ids
      groups[key][:target_quantity] = [groups[key][:target_quantity], farmer_ids.size.to_f, target.target_quantity.to_f].max
      groups[key][:targets] << target
    end

    grouped_targets.values.map do |group|
      farmer_ids = group[:farmer_ids].uniq
      matching_records = training_records.select do |record|
        group[:targets].any? { |target| training_record_matches_dashboard_target?(record, target, farmer_ids) }
      end.uniq(&:id)
      session_participants = matching_records.flat_map { |record| training_record_selected_farmer_ids(record) & farmer_ids }
      unique_participants = session_participants.uniq
      target_quantity = group[:target_quantity].to_f
      target_detail_rows = [combined_training_target_detail_row(group[:targets])]
      status_counts = training_target_status_counts_for_rows(target_detail_rows)
      farmer_rows = farmer_rows_for_training_group(group[:targets])

      group.merge(
        activity: group[:activity].join("\n"),
        sub_activity: group[:sub_activity].join("\n"),
        sessions: matching_records.size,
        training_photo_count: matching_records.count { |record| module_upload_present?(record.data["training_photo_upload_with_geo_tag"]) },
        register_count: matching_records.count { |record| module_upload_present?(record.data["training_register_upload"]) },
        male_count: matching_records.sum { |record| dashboard_numeric(record.data["male_count"]) },
        female_count: matching_records.sum { |record| dashboard_numeric(record.data["female_count"]) },
        cumulative_participants: session_participants.size,
        unique_monthly: unique_participants.size,
        target_quantity: target_quantity,
        achievement_percent: farmer_rows[:progress_percent],
        training_dates: matching_records.filter_map { |record| bill_display_date(record.data["training_date"]) if record.data["training_date"].present? }.uniq,
        green: status_counts[:green],
        yellow: status_counts[:yellow],
        red: status_counts[:red],
        total: status_counts[:total],
        target_rows: target_detail_rows,
        completed_farmers: farmer_rows[:completed_farmers],
        pending_farmers: farmer_rows[:pending_farmers],
        completed_quantity: farmer_rows[:completed_quantity],
        pending_quantity: farmer_rows[:pending_quantity],
        progress_percent: farmer_rows[:progress_percent]
      )
    end.sort_by do |row|
      [dashboard_month_index(row[:month]), row[:ics].to_s, row[:village].to_s, row[:activity].to_s, row[:sub_activity].to_s]
    end
  end

  def training_target_detail_row(target)
    farmer_ids = target_farmer_ids(target)
    matching_training_records = training_records_matching_dashboard_target(target, farmer_ids)
    completed_farmer_ids = completed_training_farmer_ids_for(target, farmer_ids)
    pending_farmer_ids = farmer_ids - completed_farmer_ids
    target_quantity = target.target_quantity.to_f
    completed_quantity = completed_farmer_ids.size.to_f
    pending_quantity = [target_quantity - completed_quantity, 0].max
    progress_percent = target_quantity.positive? ? ((completed_quantity / target_quantity) * 100).round : 0
    status_class = training_target_status_for_percent(progress_percent)
    weekly_targets = target.respond_to?(:weekly_target_values) ? target.weekly_target_values.map(&:to_f) : [0, 0, 0, 0]
    weekly_completed_farmer_ids = training_weekly_achievement_farmer_ids(target, farmer_ids)
    weekly_achievements = weekly_completed_farmer_ids.map(&:size)

    {
      target_mapping_id: target.id.to_s,
      assigned_farmer_ids: farmer_ids,
      completed_farmer_ids: completed_farmer_ids,
      weekly_completed_farmer_ids: weekly_completed_farmer_ids,
      month: target.month_name.presence || "-",
      vrp: target.vrp&.name.presence || "VRP ##{target.vrp_id}",
      fco: target.vrp&.fcoc.presence || "-",
      cluster_incharge: target.vrp&.cluster_incharge.presence || "-",
      post: target.vrp&.role.presence || "-",
      ics: target.ics_name.presence || target.ics_id.presence || "-",
      village: target.village_name.presence || target.village_id.presence || "-",
      main_activity: target.main_activity_name.presence || "Farmer Training",
      sub_activity: target.activity_name.presence || "-",
      completion_date: target.completion_date&.strftime("%d-%m-%Y") || "-",
      completion_date_sort: target.completion_date,
      target_quantity: target_quantity,
      weekly_targets: weekly_targets,
      weekly_achievements: weekly_achievements,
      completed_quantity: completed_quantity,
      pending_quantity: pending_quantity,
      progress_percent: progress_percent,
      status_label: training_target_status_label(status_class),
      status_class: status_class,
      training_register_urls: matching_training_records.flat_map { |record| module_upload_public_urls(record.data["training_register_upload"]) }.uniq,
      training_photo_urls: matching_training_records.flat_map { |record| module_upload_public_urls(record.data["training_photo_upload_with_geo_tag"]) }.uniq,
      completed_farmers: training_farmers_for_ids(completed_farmer_ids).map { |farmer| farmer.merge(status_label: "Completed", status_class: "green") },
      pending_farmers: training_farmers_for_ids(pending_farmer_ids).map { |farmer| farmer.merge(status_label: "Pending", status_class: "red") }
    }
  end

  def training_weekly_achievement_values(target, farmer_ids)
    training_weekly_achievement_farmer_ids(target, farmer_ids).map(&:size)
  end

  def training_weekly_achievement_farmer_ids(target, farmer_ids)
    farmer_ids = Array(farmer_ids).map(&:to_s).reject(&:blank?).uniq
    return Array.new(4) { [] } if farmer_ids.blank? || !model_ready?(:ModuleRecord)

    weekly_farmer_ids = Array.new(4) { [] }
    matching_training_records_for_target(target, farmer_ids).each do |record|
      training_date = parse_module_date(training_summary(record)[:training_date]) || record.created_at&.to_date
      next unless training_date

      week_index = [((training_date.day - 1) / 7), 3].min
      weekly_farmer_ids[week_index] |= training_record_selected_farmer_ids(record) & farmer_ids
    end

    weekly_farmer_ids
  end

  def training_record_week_number(record)
    training_date = parse_module_date(training_summary(record)[:training_date]) || record.created_at&.to_date
    return unless training_date

    [((training_date.day - 1) / 7) + 1, 4].min
  end

  def training_target_status_counts_for_rows(rows)
    rows = Array(rows)

    {
      green: rows.count { |row| row[:status_class] == "green" },
      yellow: rows.count { |row| row[:status_class] == "yellow" },
      red: rows.count { |row| row[:status_class] == "red" },
      total: rows.size
    }
  end

  def farmer_rows_for_training_group(targets)
    target_rows = Array(targets)
    return {
      completed_farmers: [],
      pending_farmers: [],
      completed_quantity: 0,
      pending_quantity: 0,
      progress_percent: 0
    } if target_rows.blank?

    completed_farmer_ids = unique_training_farmer_ids(target_rows.flat_map do |target|
      completed_training_farmer_ids_for(target, target_farmer_ids(target))
    end)
    target_farmer_ids = target_rows.flat_map { |target| target_farmer_ids(target) }.uniq
    pending_farmer_ids = target_farmer_ids - completed_farmer_ids
    completed_quantity = completed_farmer_ids.size
    pending_quantity = pending_farmer_ids.size
    total_quantity = target_farmer_ids.size
    progress_percent = total_quantity.positive? ? ((completed_quantity.to_f / total_quantity) * 100).round : 0

    {
      completed_farmers: training_farmers_for_ids(completed_farmer_ids).map { |farmer| farmer.merge(status_label: "Completed", status_class: "green") },
      pending_farmers: training_farmers_for_ids(pending_farmer_ids).map { |farmer| farmer.merge(status_label: "Pending", status_class: "red") },
      completed_quantity: completed_quantity,
      pending_quantity: pending_quantity,
      progress_percent: progress_percent
    }
  end

  def target_farmer_ids(target)
    return [] unless target.respond_to?(:afl_ids)

    @target_farmer_ids_cache ||= {}
    cache_key = target.respond_to?(:id) && target.id.present? ? target.id : target.object_id
    @target_farmer_ids_cache[cache_key] ||= Array(target.afl_ids).map(&:to_s).reject(&:blank?).uniq
  end

  def training_participation_target_farmer_ids(target)
    valid_ids = training_participation_existing_farmer_id_set([target])
    target_farmer_ids(target).select { |farmer_id| valid_ids.include?(farmer_id.to_s) }
  end

  def training_participation_valid_farmer_ids_for_targets(targets)
    targets = Array(targets)
    valid_ids = training_participation_existing_farmer_id_set(targets)
    targets.flat_map { |target| target_farmer_ids(target) }
      .map(&:to_s)
      .select { |farmer_id| valid_ids.include?(farmer_id) }
      .uniq
  end

  def training_participation_valid_farmer_keys_for_targets(targets)
    farmer_ids = training_participation_valid_farmer_ids_for_targets(targets)
    training_farmers_by_id(farmer_ids)
    farmer_ids
      .map { |farmer_id| training_participation_target_farmer_key(farmer_id) }
      .uniq
  end

  def training_participation_existing_farmer_id_set(targets)
    ids = Array(targets).flat_map { |target| target_farmer_ids(target) }.map(&:to_s).reject(&:blank?).uniq
    return Set.new if ids.blank? || !model_ready?(:Afl)

    @training_participation_existing_farmer_ids_cache ||= {}
    missing_ids = ids.reject { |id| @training_participation_existing_farmer_ids_cache.key?(id) }
    if missing_ids.any?
      existing_ids = Afl.where(id: missing_ids).pluck(:id).map(&:to_s).to_set
      missing_ids.each { |id| @training_participation_existing_farmer_ids_cache[id] = existing_ids.include?(id) }
    end

    Set.new(ids.select { |id| @training_participation_existing_farmer_ids_cache[id] })
  end

  # Target Mapping treats every assigned AFL ID as one unique farmer. Dashboard
  # achievement must use those exact IDs and only remove repeated attendance.
  def unique_training_farmer_ids(farmer_ids)
    Array(farmer_ids).map(&:to_s).reject(&:blank?).uniq
  end

  def new_farmer_target_mapping?(target)
    target_farmer_ids(target).blank? && target.target_quantity.to_f.positive?
  end

  def add_farmer_form_mappings
    return @add_farmer_form_mappings if defined?(@add_farmer_form_mappings)
    return [] unless model_ready?(:TargetMapping)

    scope = TargetMapping.includes(:vrp).order(:village_name, :village_id, :id)
      .select { |target| new_farmer_target_mapping?(target) }
    if vrp_login_user?
      vrp = current_vrp_record
      return [] unless vrp

      scope = scope.select { |target| target.vrp_id.to_s == vrp.id.to_s }
    elsif !admin_dashboard_user?
      visible_vrp_ids = add_farmer_visible_vrp_ids
      return [] if visible_vrp_ids.blank?

      scope = scope.select { |target| visible_vrp_ids.include?(target.vrp_id.to_s) }
    end

    @add_farmer_form_mappings = scope.map { |target| add_farmer_mapping_payload(target) }
  end

  def add_farmer_visible_vrp_ids
    ids = module_cluster_visible_vrp_ids.map(&:to_s)
    current_ids = dashboard_current_app_user_ids
    if current_ids.any? && model_ready?(:Vrp)
      scope = Vrp.where(created_by_id: current_ids)
      scope = scope.or(Vrp.where(user_id: current_ids)) if Vrp.column_names.include?("user_id")
      ids.concat(scope.pluck(:id).map(&:to_s))
    end

    ids.reject(&:blank?).uniq
  end

  def add_farmer_mapping_payload(target)
    village_label = target.village_name.presence || target.village_id.to_s
    vrp = target.vrp

    {
      id: target.id.to_s,
      vrp_id: target.vrp_id.to_s,
      jeevika_jankar_name: vrp&.name.presence || vrp&.user_name.presence || "Jeevika Jankar ##{target.vrp_id}",
      contact_number: vrp&.mobile_no.to_s.gsub(/\D/, "").last(10),
      fco_id: target.fco_id.to_s,
      fco_name: target.fco_name.to_s,
      ics_id: target.ics_id.to_s,
      ics_name: target.ics_name.to_s,
      village_id: target.village_id.to_s,
      village_name: target.village_name.to_s,
      label: village_label,
      target_quantity: target.target_quantity.to_i.to_s
    }
  end

  def dashboard_selected_training_month_name
    params[:training_month].presence || params[:dashboard_month].presence
  end

  def default_vrp_dashboard_month(month_options, targets = nil)
    target_months = Array(targets)
      .filter_map { |target| target.respond_to?(:month_name) ? target.month_name.to_s.strip.presence : nil }
      .uniq
    preferred_options = target_months.presence || Array(month_options)
    current_month = Date.current.strftime("%B")
    preferred_options.find { |month| normalize_dashboard_text(month) == normalize_dashboard_text(current_month) } || preferred_options.last
  end

  def dashboard_selected_training_sub_activity_name
    params[:training_sub_activity].presence
  end

  def dashboard_targets_for_filters(targets, month_name, sub_activity_name)
    return [] if month_name.blank? || sub_activity_name.blank?

    month_targets = dashboard_targets_for_month(targets, month_name)
    month_targets.select { |target| normalize_dashboard_text(target.activity_name) == normalize_dashboard_text(sub_activity_name) }
  end

  def dashboard_targets_for_month(targets, month_name)
    targets = Array(targets)
    return targets if month_name.blank?

    targets.select { |target| normalize_dashboard_text(target.month_name) == normalize_dashboard_text(month_name) }
  end

  def dashboard_sub_activity_options_for_targets(targets, month_name)
    return [] if month_name.blank?

    Array(targets)
      .map { |target| target.activity_name.to_s.strip }
      .reject(&:blank?)
      .uniq
      .sort_by { |sub_activity| sub_activity.downcase }
  end

  def dashboard_month_options_for_targets(targets)
    target_months = Array(targets).map { |target| target.month_name.to_s.strip }
    master_months = month_master_month_options

    (target_months + master_months)
      .reject(&:blank?)
      .uniq
      .sort_by { |month| [dashboard_month_index(month), month] }
  end

  def training_record_selected_farmer_ids(record)
    @training_record_farmer_ids_cache ||= {}
    @training_record_farmer_ids_cache[record.id] ||= Array(record.data["selected_farmer_ids"])
      .map(&:to_s).reject(&:blank?).uniq
  end

  def training_record_matches_dashboard_target?(record, target, target_farmer_ids)
    @training_record_target_match_cache ||= {}
    cache_key = [record.id, target.id]
    return @training_record_target_match_cache[cache_key] if @training_record_target_match_cache.key?(cache_key)

    selected_farmer_ids = training_record_selected_farmer_ids(record)
    return @training_record_target_match_cache[cache_key] = false if selected_farmer_ids.blank?
    return @training_record_target_match_cache[cache_key] = false unless training_record_target_assignment_matches?(record, target)
    return @training_record_target_match_cache[cache_key] = false unless training_record_matches_month?(record, target.month_name)
    return @training_record_target_match_cache[cache_key] = false unless training_record_vrp_scope_matches?(record, target.vrp)
    return @training_record_target_match_cache[cache_key] = false unless training_record_target_location_matches?(record, target)

    summary = training_summary(record)
    topics = training_activity_values(record.data["main_activities"].presence || summary[:training_topic])
    subjects = training_activity_values(record.data["sub_activities"].presence || summary[:training_subject])
    target_topic = normalize_dashboard_text(target.main_activity_name)
    target_subject = normalize_dashboard_text(target.activity_name)

    topic_matches = topics.any? { |topic| dashboard_training_activity_text_matches?(topic, target_topic) }
    subject_matches = subjects.any? { |subject| dashboard_training_activity_text_matches?(subject, target_subject) }
    @training_record_target_match_cache[cache_key] = topic_matches && subject_matches
  end

  def training_record_target_assignment_matches?(record, target)
    mapping_ids = Array(record.data["target_mapping_ids"].presence || record.data["target_mapping_id"])
      .map(&:to_s).reject(&:blank?).uniq
    return true if mapping_ids.blank?
    return true if mapping_ids.include?(target.id.to_s)

    mapped_targets = mapping_ids.filter_map { |mapping_id| training_target_mapping_for_dashboard(mapping_id) }
    return true if mapped_targets.blank?

    target_key = dashboard_target_assignment_key(target)
    target_signature = dashboard_target_assignment_signature(target)
    mapped_targets.any? do |mapped_target|
      dashboard_target_assignment_key(mapped_target) == target_key ||
        dashboard_target_assignment_signature(mapped_target) == target_signature
    end || training_record_target_fields_match?(record, target)
  end

  def training_record_target_fields_match?(record, target)
    data = record.data || {}
    record_month = normalize_dashboard_text(data["month"].presence || data["training_month"])
    record_ics = normalize_dashboard_text(data["ics_block"].presence || data["ics"])
    record_village = normalize_dashboard_text(data["gram_name"].presence || data["village"])
    record_topics = training_activity_values(data["main_activities"].presence || data["main_activity"].presence || data["training_topic"])
    record_subjects = training_activity_values(data["sub_activities"].presence || data["sub_activity"].presence || data["training_subject"])

    return false if record_month.present? && record_month != normalize_dashboard_text(target.month_name)

    target_ics_values = [target.ics_id, target.ics_name].map { |value| normalize_dashboard_text(value) }.reject(&:blank?)
    target_village_values = [target.village_id, target.village_name].map { |value| normalize_dashboard_text(value) }.reject(&:blank?)
    return false if record_ics.present? && target_ics_values.present? && !target_ics_values.include?(record_ics)
    return false if record_village.present? && target_village_values.present? && !target_village_values.include?(record_village)

    target_topic = normalize_dashboard_text(target.main_activity_name)
    target_subject = normalize_dashboard_text(target.activity_name)
    topic_matches = record_topics.blank? || record_topics.any? { |topic| dashboard_training_activity_text_matches?(topic, target_topic) }
    subject_matches = record_subjects.blank? || record_subjects.any? { |subject| dashboard_training_activity_text_matches?(subject, target_subject) }
    topic_matches && subject_matches
  end

  # Training forms can reference many target mapping IDs. Looking up each ID
  # individually turned a single dashboard load into hundreds of SQL queries.
  # Dashboard targets are already loaded with their VRP association, so use
  # that request-local index first and only query IDs outside the visible scope.
  def training_target_mapping_for_dashboard(mapping_id)
    mapping_id = mapping_id.to_s
    return nil if mapping_id.blank?

    @training_record_target_mapping_cache ||= {}
    return @training_record_target_mapping_cache[mapping_id] if @training_record_target_mapping_cache.key?(mapping_id)

    # Reuse targets already loaded by the dashboard, but do not load the entire
    # visible target population just to resolve IDs from a few training forms.
    @dashboard_target_mapping_index ||= Array(@dashboard_target_mappings).index_by { |target| target.id.to_s }
    return @training_record_target_mapping_cache[mapping_id] = @dashboard_target_mapping_index[mapping_id] if @dashboard_target_mapping_index.key?(mapping_id)

    @training_record_target_mapping_cache[mapping_id] = TargetMapping.includes(:vrp).find_by(id: mapping_id)
  end

  # Training forms may reference thousands of target mapping IDs. Resolve all
  # of them once per request instead of falling back to one SELECT per ID.
  def preload_training_target_mappings_for_records!(records)
    return unless model_ready?(:TargetMapping)

    mapping_ids = Array(records).flat_map do |record|
      Array(record.data["target_mapping_ids"].presence || record.data["target_mapping_id"])
    end.map(&:to_s).reject(&:blank?).uniq
    return if mapping_ids.blank?

    @training_record_target_mapping_cache ||= {}
    @dashboard_target_mapping_index ||= Array(@dashboard_target_mappings).index_by { |target| target.id.to_s }

    mapping_ids.each do |mapping_id|
      if @dashboard_target_mapping_index.key?(mapping_id)
        @training_record_target_mapping_cache[mapping_id] = @dashboard_target_mapping_index[mapping_id]
      end
    end

    missing_ids = mapping_ids.reject { |mapping_id| @training_record_target_mapping_cache.key?(mapping_id) }
    return if missing_ids.blank?

    missing_ids.each { |mapping_id| @training_record_target_mapping_cache[mapping_id] = nil }
    TargetMapping.includes(:vrp).where(id: missing_ids).find_each do |target|
      @training_record_target_mapping_cache[target.id.to_s] = target
    end
  end

  def training_record_target_location_matches?(record, target)
    record_ics = normalize_dashboard_text(record.data["ics_block"].presence || record.data["ics"])
    record_village = normalize_dashboard_text(record.data["gram_name"].presence || record.data["village"])
    target_ics_values = [target.ics_id, target.ics_name].map { |value| normalize_dashboard_text(value) }.reject(&:blank?)
    target_village_values = [target.village_id, target.village_name].map { |value| normalize_dashboard_text(value) }.reject(&:blank?)

    ics_matches = record_ics.blank? || target_ics_values.blank? || target_ics_values.include?(record_ics)
    village_matches = record_village.blank? || target_village_values.blank? || target_village_values.include?(record_village)
    ics_matches && village_matches
  end

  # A target mapping can contain several configured training modules in one
  # activity label, while each training form saves only the module delivered in
  # that session. Treat the individual module as belonging to that combined
  # target without allowing an unrelated activity to complete it.
  def dashboard_training_activity_text_matches?(record_value, target_value)
    record_value = normalize_training_activity_label(record_value)
    target_value = normalize_training_activity_label(target_value)
    return true if record_value.blank? || target_value.blank?

    record_value == target_value || target_value.include?(record_value) || record_value.include?(target_value)
  end

  def normalize_training_activity_label(value)
    normalize_dashboard_text(value)
      .sub(/\A\d+[\.)]\s*/, "")
      .gsub(/([,\n;])\s*\d+[\.)]\s*/, "\\1 ")
      .squeeze(" ")
      .strip
  end

  def training_record_vrp_scope_matches?(record, vrp)
    return true unless vrp

    record_values = [
      record.data["jeevika_jankar_id"],
      record.data["vrp_id"],
      record.data["select_vrp"],
      record.data["vrp_name"],
      record.data["jeevika_jankar_name"],
      record.data["trainer_contact"],
      record.data["trainer_name"]
    ].map { |value| normalize_dashboard_text(value) }.reject(&:blank?)
    return true if record_values.blank?

    vrp_values = [
      vrp.id,
      vrp.name,
      vrp.user_name,
      vrp.mobile_no,
      [vrp.name, vrp.mobile_no.presence].compact_blank.join(" - ")
    ].map { |value| normalize_dashboard_text(value) }.reject(&:blank?)

    (record_values & vrp_values).any?
  end

  def module_upload_present?(value)
    case value
    when Array then value.any? { |item| module_upload_present?(item) }
    when Hash then value.values.any? { |item| module_upload_present?(item) }
    else value.to_s.strip.present?
    end
  end

  def module_upload_public_url(value)
    module_upload_public_urls(value).first.to_s
  end

  def module_upload_public_urls(value)
    paths = case value
            when Array then value.flat_map { |item| module_upload_paths(item) }
            when Hash then value.values.flat_map { |item| module_upload_paths(item) }
            else module_upload_paths(value)
            end

    paths.compact_blank.reject { |path| path == "-" }.uniq.map do |path|
      next path if path.match?(/\Ahttps?:\/\//i)

      path = "/#{path}" unless path.start_with?("/")
      "#{request.base_url}#{path}"
    end
  end

  def module_upload_paths(value)
    ModuleUploadPaths.call(value)
  end

  def dashboard_filter_export_rows
    rows = []
    rows << ["Dashboard Filter Export"]
    rows << ["Generated At", @dashboard_generated_at&.strftime("%d-%m-%Y %I:%M %p")]
    rows << []
    rows << ["Active Filters"]
    rows << ["Search", params[:search].presence || "All"]
    rows << ["Activity", params[:activity].presence || "All"]
    rows << ["FCO", params[:fcoc].presence || "All"]
    rows << ["Cluster Incharge", params[:cluster_incharge].presence || "All"]
    rows << ["Month", params[:month].presence || "All"]
    rows << ["Post", params[:post].presence || "All"]
    rows << ["VRP", params[:vrp_id].presence || "All"]
    rows << []

    rows << ["Dashboard Cards"]
    rows << ["Title", "Value", "Caption"]
    Array(@dashboard_summary_cards).each do |card|
      rows << [card[:title], card[:value], card[:caption]]
    end
    Array(@dashboard_cards).each do |card|
      title = card.is_a?(Hash) ? card[:title] : card[0]
      value = card.is_a?(Hash) ? card[:value] : card[1]
      caption = card.is_a?(Hash) ? card[:caption] : card[2]
      rows << [title, value, caption]
    end
    rows << []

    Array(@dashboard_reports).each do |report|
      next if report[:clock]
      next if Array(report[:headers]).blank?

      rows << [report[:title].to_s]
      rows << Array(report[:headers])
      Array(report[:rows]).each do |row|
        rows << Array(row).map { |cell| dashboard_detail_cell_text(cell) }
      end
      rows << []
    end

    if Array(@farmer_training_dashboard_rows).any?
      rows << ["Farmer Training Targets"]
      rows << ["Month", "ICS", "Village", "Main Activity", "Sub Activity", "Target", "Completed", "Pending", "Progress %"]
      Array(@farmer_training_dashboard_rows).each do |row|
        rows << [
          row[:month] || "-",
          row[:ics] || "-",
          row[:village] || "-",
          row[:activity] || "-",
          row[:sub_activity] || "-",
          row[:target_quantity] || "-",
          row[:completed_quantity] || "-",
          row[:pending_quantity] || "-",
          row[:progress_percent] || "-"
        ]
      end
      rows << []
    end

    rows
  end

  def dashboard_month_index(month_name)
    Date::MONTHNAMES.index(month_name.to_s.strip.capitalize) || 13
  end

  def training_participation_month_open?(month_name)
    month_index = dashboard_month_index(month_name)
    return false if month_index > 12

    today = Time.zone.today
    month_end = Date.civil(today.year, month_index, -1)
    today <= month_end
  end

  def target_ics_label(target)
    target.ics_name.presence || module_record_label_for_dashboard("ics-master", target.ics_id, "ics_name").presence || target.ics_id.presence || "-"
  end

  def target_village_label(target)
    target.village_name.presence || module_record_label_for_dashboard("village-master", target.village_id, "village_name").presence || target.village_id.presence || "-"
  end

  def user_hierarchy_dashboard_report(summary)
    {
      title: "User Hierarchy",
      dom_id: "user_hierarchy_report",
      headers: ["Name", "Reports To", "Level"],
      rows: summary[:rows].presence || [["No mapped user", "-", "-"]]
    }
  end

  def user_hierarchy_dashboard_summary
    @user_hierarchy_dashboard_summary ||= begin
      rows = user_hierarchy_dashboard_rows
      level_2_rows = rows.select { |row| row[2].to_s == "Level 2" }
      level_3_rows = rows.select { |row| row[2].to_s == "Level 3" }
      {
        level_2_total: level_2_rows.size,
        level_3_total: level_3_rows.size,
        total: rows.size,
        rows: rows
      }
    end
  end

  def user_hierarchy_dashboard_rows
    return [] unless model_ready?(:ModuleRecord)

    current_labels = current_dashboard_user_labels
    return [] if current_labels.blank? && !admin_dashboard_user?

    rows = []
    ModuleRecord
      .where(module_slug: "user-hierarchy-mapping")
      .order(updated_at: :desc)
      .select { |record| active_module_record?(record) }
      .each do |record|
        level_1_user = record.data["level_1_user"].to_s.strip
        hierarchy_mappings_for_dashboard(record).each do |mapping|
          level_2_user = mapping["level_2_user"].to_s.strip
          level_3_users = collapsed_hierarchy_users(mapping["level_3_users"])

          if admin_dashboard_user? || dashboard_user_label_matches?(level_1_user, current_labels)
            rows << [level_2_user, level_1_user, "Level 2"] if level_2_user.present?
            level_3_users.each do |level_3_user|
              rows << [level_3_user, level_2_user.presence || level_1_user, "Level 3"]
            end
          elsif dashboard_user_label_matches?(level_2_user, current_labels)
            level_3_users.each do |level_3_user|
              rows << [level_3_user, level_2_user, "Level 3"]
            end
          end
        end
      end

    rows.reject { |row| row[0].blank? }.uniq
  end

  def hierarchy_mappings_for_dashboard(record)
    raw_mappings = record.data["level_2_mappings"]
    raw_mappings = raw_mappings.values if raw_mappings.is_a?(Hash)
    mappings = Array(raw_mappings).filter_map do |mapping|
      mapping = mapping.to_h if mapping.respond_to?(:to_h)
      next unless mapping.is_a?(Hash)

      level_2_users = collapsed_hierarchy_users(mapping["level_2_user"])
      level_3_users = collapsed_hierarchy_users(mapping["level_3_users"])
      level_2_users.map { |level_2_user| { "level_2_user" => level_2_user, "level_3_users" => level_3_users } }
    end
    mappings.flatten!

    return mappings if mappings.any?

    level_3_users = collapsed_hierarchy_users(record.data["level_3_users"].presence || record.data["level_3_user"])
    collapsed_hierarchy_users(record.data["level_2_users"].presence || record.data["level_2_user"]).map do |level_2_user|
      {
        "level_2_user" => level_2_user,
        "level_3_users" => level_3_users
      }
    end
  end

  def current_dashboard_user_labels
    name = current_app_user&.dig("name").to_s.strip
    username = current_app_user&.dig("username").to_s.strip
    role = current_app_user&.dig("role").presence || current_app_user&.dig("role_name")

    [
      name,
      username,
      role.present? && name.present? ? "#{name} (#{role})" : nil,
      role.present? && username.present? ? "#{username} (#{role})" : nil
    ].compact_blank.uniq
  end

  def dashboard_user_label_matches?(stored_label, current_labels)
    stored_values = dashboard_user_label_match_values(stored_label)
    return false if stored_values.blank?

    current_labels.any? do |label|
      (stored_values & dashboard_user_label_match_values(label)).any?
    end
  end

  def dashboard_user_label_match_values(label)
    @dashboard_user_label_match_values_cache ||= {}
    @dashboard_user_label_match_values_cache[label.to_s] ||= begin
      normalized = normalize_dashboard_user_label(label)
      base = normalize_dashboard_user_label(label.to_s.sub(/\s*\([^)]*\)\s*\z/, ""))

      [normalized, base].compact_blank.reject { |value| value.length < 3 }.uniq
    end
  end

  def normalize_dashboard_user_label(label)
    label.to_s.downcase.gsub(/[^a-z0-9]+/, " ").squish
  end

  def vrp_declaration_acceptance_report
    rows = if model_ready?(:Vrp) && Vrp.column_names.include?("agreement_accepted_at")
      Vrp.where.not(agreement_accepted_at: nil)
        .order(agreement_accepted_at: :desc)
        .select { |vrp| scoped_jeevika_vrp_visible?(vrp) }
        .map do |vrp|
          [
            vrp.name.presence || "-",
            vrp.user_name.presence || "-",
            vrp.mobile_no.presence || "-",
            vrp.email.presence || "-",
            vrp.agreement_accepted_at&.strftime("%d-%m-%Y %I:%M %p")
          ]
        end
    else
      []
    end

    {
      title: "VRP Declaration Accepted",
      headers: ["VRP", "Username", "Mobile", "Email", "Accepted At"],
      rows: rows.presence || [["No accepted declaration", "-", "-", "-", "-"]]
    }
  end

  def vrp_assigned_target_report
    rows = if model_ready?(:TargetMapping)
      targets = TargetMapping.includes(:vrp)
        .order(updated_at: :desc)
        .limit(100)
        .to_a
      dashboard_target_assignment_groups(targets).map do |group|
          target = group.first
          farmer_count = group.flat_map { |row| target_farmer_ids(row) }.uniq.size
          [
            target.vrp&.name.presence || "VRP ##{target.vrp_id}",
            target.month_name.presence || "-",
            target.village_name.presence || target.village_id.presence || "-",
            group.map(&:main_activity_name).compact_blank.uniq.join("\n").presence || "-",
            group.map(&:activity_name).compact_blank.uniq.join("\n").presence || "-",
            farmer_count.positive? ? farmer_count : group.map(&:farmer_count).max,
            dashboard_quantity(farmer_count.positive? ? farmer_count : group.map { |row| row.target_quantity.to_f }.max)
          ]
        end
    else
      []
    end

    {
      title: "VRP Target Assigned",
      headers: ["VRP", "Month", "Village", "Main Activity", "Sub Activity", "Farmers", "Target"],
      rows: rows.presence || [["No target assigned", "-", "-", "-", "-", "-", "-"]]
    }
  end

  def admin_dashboard_user?
    current_app_user&.dig("user_type").to_s.strip.casecmp("admin").zero?
  end

  def dashboard_global_view_user?
    return true if admin_dashboard_user?

    [
      current_app_user&.dig("role"),
      current_app_user&.dig("role_name"),
      current_app_user&.dig("stakeholder_role"),
      current_app_user&.dig("user_management_role"),
      current_app_user&.dig("person_type")
    ].compact_blank.any? do |value|
      normalized = normalize_dashboard_user_label(value)
      normalized == "cfo" || normalized.include?("chief financial officer")
    end
  end

  def dashboard_current_user_title
    current_app_user&.dig("name").presence ||
      current_app_user&.dig("username").presence ||
      current_app_user&.dig("user_name").presence ||
      "Dashboard"
  end

  def dashboard_default_visible_fcoc(options)
    return nil if dashboard_global_view_user?

    values = Array(options).map(&:to_s).map(&:strip).reject(&:blank?).uniq
    values.one? ? values.first : nil
  end

  def dashboard_filter_param(*keys)
    return nil if request.nil? && @_params.nil?

    @dashboard_filter_param_cache ||= {}
    cache_key = keys.map(&:to_s)
    return @dashboard_filter_param_cache[cache_key] if @dashboard_filter_param_cache.key?(cache_key)

    keys.each do |key|
      value = params[key].to_s.strip
      next if dashboard_all_filter_value?(value)

      return @dashboard_filter_param_cache[cache_key] = value if value.present?
    end
    @dashboard_filter_param_cache[cache_key] = nil
  end

  def dashboard_all_filter_value?(value)
    normalized = value.to_s.strip.downcase
    normalized.blank? || normalized == "all" || normalized.start_with?("all ")
  end

  def dashboard_vrps
    return @dashboard_vrps if defined?(@dashboard_vrps)
    return @dashboard_vrps = [] unless model_ready?(:Vrp)
    return @dashboard_vrps = Vrp.all.to_a if current_app_user.blank? || dashboard_global_view_user?

    @dashboard_vrps = Vrp.all.select { |vrp| scoped_jeevika_vrp_visible?(vrp) }
  end

  def dashboard_visible_vrp_ids
    @dashboard_visible_vrp_ids ||= dashboard_vrps.map(&:id)
  end

  def dashboard_ics_filtered_scope(scope)
    ics = dashboard_filter_param(:ics, :ics_name)
    return scope if ics.blank?

    scope.where("LOWER(BTRIM(ics_id)) = :ics OR LOWER(BTRIM(ics_name)) = :ics", ics: normalize_dashboard_text(ics))
  end

  def dashboard_visible_target_scope
    scope = dashboard_global_view_user? ? TargetMapping.all : TargetMapping.where(vrp_id: dashboard_visible_vrp_ids)
    dashboard_ics_filtered_scope(scope)
  end

  def dashboard_visible_farmer_scope
    dashboard_ics_filtered_scope(dashboard_user_visible_farmer_scope)
  end

  def dashboard_user_visible_farmer_scope
    return Afl.all if dashboard_global_view_user?
    if dashboard_source_fcoc_login?
      fco_values = dashboard_vrps.map(&:fcoc).compact_blank.uniq.flat_map { |fcoc| training_fcoc_filter_values(fcoc) }.map(&:downcase).uniq
      return Afl.where("LOWER(BTRIM(fco_id)) IN (:values) OR LOWER(BTRIM(fco)) IN (:values)", values: fco_values)
    end

    # Keep the membership join in PostgreSQL instead of loading every target
    # and a large farmer ID array for every card and export.
    target_sql = dashboard_visible_target_scope.select(:afl_ids).to_sql
    Afl.where("afls.id::text IN (SELECT jsonb_array_elements_text(CASE WHEN jsonb_typeof(visible_targets.afl_ids::jsonb) = 'array' THEN visible_targets.afl_ids::jsonb ELSE '[]'::jsonb END) FROM (#{target_sql}) visible_targets)")
  end

  def dashboard_scoped_training_sql(sql)
    return sql if dashboard_global_view_user? && dashboard_filter_param(:ics, :ics_name).blank?
    sql.gsub("public.target_mappings", "(#{dashboard_visible_target_scope.to_sql})")
      .gsub("public.afls", "(#{dashboard_visible_farmer_scope.to_sql})")
  end

  def dashboard_approved_vrps(vrps)
    Array(vrps).select { |vrp| vrp.status.to_i == 55 || vrp_approval_complete?(vrp) }
  end

  def dashboard_pending_approval_vrps(vrps)
    Array(vrps).select do |vrp|
      next false unless vrp_approval_pending?(vrp)
      next true if admin_dashboard_user?
      next true if dashboard_current_user_current_approver?(vrp)

      dashboard_user_owns_vrp?(vrp)
    end
  end

  def dashboard_user_owns_vrp?(vrp)
    dashboard_own_vrps_list.any? { |own_vrp| own_vrp.id == vrp.id }
  end

  def dashboard_own_vrps_list
    @dashboard_own_vrps_list ||= dashboard_own_vrps.to_a
  end

  def dashboard_target_mappings
    return @dashboard_target_mappings if defined?(@dashboard_target_mappings)
    return @dashboard_target_mappings = [] unless model_ready?(:TargetMapping)

    scope = TargetMapping.includes(:vrp).order(updated_at: :desc)
    return @dashboard_target_mappings = scope.to_a if dashboard_global_view_user?

    @dashboard_target_mappings = scope.where(vrp_id: dashboard_visible_vrp_ids).to_a
  end

  def dashboard_target_summary_rows(targets)
    grouped = dashboard_target_assignment_groups(targets).group_by { |rows| rows.first.month_name.presence || "Not Set" }

    grouped.map do |month, assignments|
      [
        month,
        assignments.size,
        dashboard_quantity(assignments.sum { |rows| rows.map { |target| target_farmer_ids(target).size.nonzero? || target.target_quantity.to_f }.max.to_f })
      ]
    end.presence || [["No data", 0, 0]]
  end

  def dashboard_own_vrps
    ids = dashboard_current_app_user_ids
    emails = dashboard_current_app_user_emails
    return Vrp.none if ids.blank? && emails.blank?

    scope = Vrp.none
    if ids.any?
      scope = scope.or(Vrp.where(created_by_id: ids))
      scope = scope.or(Vrp.where(user_id: ids)) if Vrp.column_names.include?("user_id")
    end

    if emails.any?
      unassigned_scope = Vrp.where(created_by_id: nil).where("LOWER(email) IN (?)", emails)
      unassigned_scope = unassigned_scope.where(user_id: nil) if Vrp.column_names.include?("user_id")
      scope = scope.or(unassigned_scope)
    end

    scope
  end

  def dashboard_hierarchy_vrps
    return [] unless model_ready?(:Vrp)

    labels = dashboard_under_user_labels
    return [] if labels.blank?

    ids = dashboard_user_ids_for_labels(labels)
    legacy_ids = dashboard_legacy_user_ids_for_labels(labels)
    emails = dashboard_user_emails_for_labels(labels)
    scope = Vrp.none

    creator_ids = (ids + legacy_ids).compact_blank.uniq
    if creator_ids.any?
      scope = scope.or(Vrp.where(created_by_id: creator_ids))
      scope = scope.or(Vrp.where(user_id: ids)) if ids.any? && Vrp.column_names.include?("user_id")
    end

    if emails.any?
      email_scope = Vrp.where("LOWER(email) IN (?)", emails)
      scope = scope.or(email_scope)
    end

    cluster_vrps = Vrp.where.not(cluster_incharge: [nil, ""]).select do |vrp|
      labels.any? { |label| cluster_label_matches?(label, vrp.cluster_incharge) }
    end

    (scope.to_a + cluster_vrps).uniq
  end

  def dashboard_office_visible_vrps
    return [] unless model_ready?(:Vrp)

    @dashboard_office_visible_vrps ||= Vrp.all.select { |vrp| jeevika_bill_vrp_office_visible?(vrp) }
  end

  def dashboard_under_user_labels
    @dashboard_under_user_labels ||= user_hierarchy_dashboard_rows.map { |row| row[0] }.compact_blank.uniq
  end

  def dashboard_hierarchy_cluster_scope?
    return false if dashboard_global_view_user?

    dashboard_under_user_labels.any? do |label|
      cluster_incharge_user_label?(label) || user_record_cluster_incharge_label?(label)
    end
  end

  def dashboard_user_ids_for_labels(labels)
    return [] unless model_ready?(:User)

    normalized_labels = Array(labels).map { |label| normalize_dashboard_user_label(label) }.reject(&:blank?).uniq
    return [] if normalized_labels.blank?

    dashboard_user_label_index.values_at(*normalized_labels).compact.flatten.uniq
  end

  def dashboard_legacy_user_ids_for_labels(labels)
    return [] unless model_ready?(:ModuleRecord)

    normalized_labels = Array(labels).map { |label| normalize_dashboard_user_label(label) }.reject(&:blank?).uniq
    return [] if normalized_labels.blank?

    dashboard_legacy_user_label_index.values_at(*normalized_labels).compact.flatten.uniq
  end

  def dashboard_user_emails_for_labels(labels)
    emails = []
    normalized_labels = Array(labels).map { |label| normalize_dashboard_user_label(label) }.reject(&:blank?).uniq
    return emails if normalized_labels.blank?

    if model_ready?(:User)
      emails.concat(dashboard_user_email_label_index.values_at(*normalized_labels).compact.flatten)
    end

    if model_ready?(:ModuleRecord)
      emails.concat(dashboard_legacy_user_email_label_index.values_at(*normalized_labels).compact.flatten)
    end

    emails.compact_blank.map { |email| email.to_s.strip.downcase }.uniq
  end

  def dashboard_user_label_index
    @dashboard_user_label_index ||= begin
      index = Hash.new { |hash, key| hash[key] = [] }
      User.find_each do |user|
        dashboard_labels_for_user(user).each { |label| index[label] << user.id }
      end
      index
    end
  end

  def dashboard_user_email_label_index
    @dashboard_user_email_label_index ||= begin
      index = Hash.new { |hash, key| hash[key] = [] }
      User.find_each do |user|
        next unless user.respond_to?(:email) && user.email.present?

        dashboard_labels_for_user(user).each { |label| index[label] << user.email }
      end
      index
    end
  end

  def dashboard_legacy_user_label_index
    @dashboard_legacy_user_label_index ||= begin
      index = Hash.new { |hash, key| hash[key] = [] }
      active_module_records_scope("new-user").find_each do |record|
        dashboard_labels_for_legacy_user(record).each { |label| index[label] << record.id }
      end
      index
    end
  end

  def dashboard_legacy_user_email_label_index
    @dashboard_legacy_user_email_label_index ||= begin
      index = Hash.new { |hash, key| hash[key] = [] }
      active_module_records_scope("new-user").find_each do |record|
        email = record.data["email"].to_s.strip
        next if email.blank?

        dashboard_labels_for_legacy_user(record).each { |label| index[label] << email }
      end
      index
    end
  end

  def dashboard_labels_for_user(user)
    [
      user.respond_to?(:first_name) || user.respond_to?(:last_name) ? [user.try(:first_name), user.try(:last_name)].compact_blank.join(" ") : nil,
      user.respond_to?(:user_name) ? user.user_name : nil,
      user.respond_to?(:name) ? user.name : nil
    ].compact_blank.map { |label| normalize_dashboard_user_label(label) }.uniq
  end

  def dashboard_labels_for_legacy_user(record)
    full_name = [record.data["first_name"], record.data["last_name"]].compact_blank.join(" ")
    [full_name, record.data["user_name"], record.data["name"]].compact_blank.map { |label| normalize_dashboard_user_label(label) }.uniq
  end

  def dashboard_approval_related_vrps
    return [] unless model_ready?(:Vrp)

    @dashboard_approval_related_vrps ||= begin
      vrps = Vrp.all.to_a
      preload_dashboard_vrp_identity_records!(vrps)
      vrps.select do |vrp|
        vrp_approval_sent?(vrp) && dashboard_current_user_in_approval_channel?(vrp)
      end
    end
  end

  def dashboard_current_user_in_approval_channel?(vrp)
    current_labels = current_dashboard_user_labels
    return false if current_labels.blank?

    dashboard_approval_steps_for_visibility(vrp).any? do |step|
      dashboard_user_label_matches?(step.data["approver_approved_by"], current_labels)
    end ||
      vrp_approval_history_for(vrp).any? do |record|
        dashboard_user_label_matches?(record.data["approver"], current_labels) ||
          dashboard_user_label_matches?(record.data["action_by"], current_labels)
      end
  end

  def dashboard_current_user_current_approver?(vrp)
    current_labels = current_dashboard_user_labels
    return false if current_labels.blank?

    step = dashboard_current_approval_step_for_visibility(vrp)
    return false unless step

    dashboard_user_label_matches?(step.data["approver_approved_by"], current_labels)
  end

  def dashboard_approval_steps_for_visibility(vrp)
    return [] unless model_ready?(:ModuleRecord)

    @dashboard_approval_steps_for_visibility_cache ||= {}
    cache_key = vrp.id
    return @dashboard_approval_steps_for_visibility_cache[cache_key] if @dashboard_approval_steps_for_visibility_cache.key?(cache_key)

    identities = vrp_creator_identities_for_dashboard(vrp)
    return @dashboard_approval_steps_for_visibility_cache[cache_key] = [] if identities.blank?

    @dashboard_approval_visibility_steps ||= ModuleRecord.where(module_slug: "approval-master").order(created_at: :asc).to_a
    @dashboard_approval_steps_for_visibility_cache[cache_key] = @dashboard_approval_visibility_steps
      .select do |record|
        record.data["status"].to_s != "Inactive" &&
          approval_registration_module?(record.data["module_name"]) &&
          dashboard_vrp_name_matches?(record.data["vrp_name"], vrp) &&
          identities.any? do |identity|
            dashboard_value_matches?(record.data["stakeholder_name"], identity[:stakeholder]) &&
              approval_identity_filters_match?(record, identity)
          end
      end
      .group_by { |record| vrp_approval_sequence(record) }
      .values
      .map { |records| records.max_by { |record| approval_record_priority(record) } }
      .sort_by { |record| vrp_approval_sequence(record) }
  end

  def dashboard_current_approval_step_for_visibility(vrp)
    dashboard_approval_steps_for_visibility(vrp).find do |step|
      !vrp_approval_step_closed?(vrp, step)
    end
  end

  def dashboard_current_app_user_ids
    @dashboard_current_app_user_ids ||= ([current_app_user&.dig("id")] + dashboard_legacy_current_app_user_ids).compact.uniq
  end

  def dashboard_legacy_current_app_user_ids
    return [] unless model_ready?(:ModuleRecord)

    @dashboard_legacy_current_app_user_ids ||= begin
      username = current_app_user&.dig("username").to_s
      emails = dashboard_current_app_user_emails
      if username.blank? && emails.blank?
        []
      else
        new_user_module_records.select do |record|
          record.data["user_name"].to_s == username ||
            emails.include?(record.data["email"].to_s.strip.downcase)
        end.map(&:id)
      end
    end
  end

  def dashboard_current_app_user_emails
    @dashboard_current_app_user_emails ||= begin
      emails = [current_app_user&.dig("email")]

      if model_ready?(:User)
        user = cached_user_find_by(user_name: current_app_user&.dig("username")) ||
          cached_user_find_by(id: current_app_user&.dig("id"))
        emails << user&.email
      end

      emails.compact_blank.map { |email| email.to_s.strip.downcase }.uniq
    end
  end

  def module_records_for_dashboard(slug)
    return [] unless model_ready?(:ModuleRecord)

    @module_records_for_dashboard_cache ||= {}
    @module_records_for_dashboard_cache[slug.to_s] ||= ModuleRecord.where(module_slug: slug).order(created_at: :desc).to_a
  end

  def grouped_rows(records, group_key, amount_key, default_key: "Not Set")
    grouped = records.group_by { |record| record.data[group_key].presence || default_key }

    grouped.map do |key, rows|
      amount = rows.sum { |record| dashboard_amount(record, amount_key) }
      [key, rows.size, amount.positive? ? format("%.2f", amount) : "-"]
    end.presence || [["No data", 0, "-"]]
  end

  def grouped_count_rows(records, group_key, count_key, count_value)
    grouped = records.group_by { |record| record.data[group_key].presence || "Not Set" }

    grouped.map do |key, rows|
      [key, rows.size, rows.count { |record| record.data[count_key] == count_value }]
    end.presence || [["No data", 0, 0]]
  end

  def dashboard_amount(record, preferred_key)
    value = record.data[preferred_key].presence || record.data["grand_total"].presence || record.data["bill_amount"]
    value.to_s.gsub(",", "").to_f
  end

  def bill_payment_status(record)
    record.data["payment_status"].to_s.strip.presence || "Pending"
  end

  def bill_approved?(record)
    record.data["status"].to_s.casecmp("Approved").zero? || bill_payment_status(record).casecmp("Paid").zero?
  end

  def vrp_approval_pending?(vrp)
    return false if [55, 99].include?(vrp.status.to_i)
    return false if vrp.status.to_i < 25
    return false if vrp.status.to_i == 25 && !vrp_approval_sent?(vrp)

    !vrp_approval_rejected?(vrp) && !vrp_approval_complete?(vrp)
  end

  def vrp_approval_sent?(vrp)
    vrp_approval_history_for(vrp).any? do |record|
      ["Sent for Approval", "Approved", "Rejected"].include?(record.data["action"].to_s)
    end
  end

  def vrp_approval_rejected?(vrp)
    vrp_approval_history_for(vrp).any? { |record| record.data["action"].to_s == "Rejected" }
  end

  def vrp_approval_complete?(vrp)
    steps = vrp_approval_steps_for(vrp)
    return false if steps.blank?

    steps.all? { |step| vrp_approval_step_closed?(vrp, step) }
  end

  def vrp_approval_step_closed?(vrp, step)
    step_sequence = vrp_approval_sequence(step)
    step_approver = normalize_approval_label(step.data["approver_approved_by"].presence || "Approver")

    vrp_approval_history_for(vrp).any? do |record|
      ["Approved", "Rejected"].include?(record.data["action"].to_s) &&
        (
          approval_sequence_from_level(record.data["approval_level"]) == step_sequence ||
            normalize_approval_label(record.data["approver"]) == step_approver
        )
    end
  end

  def vrp_approval_history_for(vrp)
    return [] unless model_ready?(:ModuleRecord)

    @dashboard_approval_history_by_vrp_id ||= ModuleRecord
      .where(module_slug: "vrp-approval-history")
      .order(created_at: :asc)
      .to_a
      .group_by { |record| record.data["vrp_id"].to_s }
    @dashboard_approval_history_by_vrp_id[vrp.id.to_s] || []
  end

  def vrp_approval_steps_for(vrp)
    return [] unless model_ready?(:ModuleRecord)

    @vrp_approval_steps_for_cache ||= {}
    cache_key = vrp.id
    return @vrp_approval_steps_for_cache[cache_key] if @vrp_approval_steps_for_cache.key?(cache_key)

    identities = vrp_creator_identities_for_dashboard(vrp)
    return @vrp_approval_steps_for_cache[cache_key] = [] if identities.blank?

    @dashboard_approval_steps ||= ModuleRecord.where(module_slug: "approval-master").order(created_at: :asc).to_a
    @vrp_approval_steps_for_cache[cache_key] = @dashboard_approval_steps
      .select do |record|
        record.data["status"].to_s != "Inactive" &&
          approval_registration_module?(record.data["module_name"]) &&
          identities.any? do |identity|
            record_role = record.data["role"].presence || record.data["role_name"]
            record_role_name = record.data["role"].present? ? record.data["role_name"] : nil
            dashboard_value_matches?(record_role, identity[:role]) &&
              dashboard_value_matches?(record_role_name, identity[:role_name]) &&
              dashboard_value_matches?(record.data["stakeholder_name"], identity[:stakeholder]) &&
              dashboard_value_matches?(record.data["stakeholder_role"], identity[:stakeholder_role]) &&
              dashboard_value_matches?(record.data["user_management_role"], identity[:user_management_role]) &&
              dashboard_value_matches?(record.data["person_type"], identity[:person_type]) &&
              dashboard_vrp_name_matches?(record.data["vrp_name"], vrp) &&
              approval_identity_filters_match?(record, identity)
          end
      end
      .group_by { |record| vrp_approval_sequence(record) }
      .values
      .map { |records| records.max_by { |record| approval_record_priority(record) } }
      .sort_by { |record| vrp_approval_sequence(record) }
  end

  def vrp_creator_identities_for_dashboard(vrp)
    return [] unless vrp

    @vrp_creator_identities_for_dashboard_cache ||= {}
    cache_key = vrp.id
    return @vrp_creator_identities_for_dashboard_cache[cache_key] if @vrp_creator_identities_for_dashboard_cache.key?(cache_key)

    identities = []

    if vrp.created_by_id.present? && model_ready?(:User)
      user = cached_user_find_by(id: vrp.created_by_id)
      identities << user_dashboard_identity(user) if user
    end

    if model_ready?(:User)
      matched_users = []
      matched_users << cached_user_find_by(email: vrp.email) if vrp.email.present?
      matched_users << cached_user_find_by(mobile_no: vrp.mobile_no) if vrp.mobile_no.present?
      matched_users.compact.uniq.each do |user|
        identities << user_dashboard_identity(user)
      end
    end

    if vrp.created_by_id.present? && model_ready?(:ModuleRecord)
      record = cached_module_record_find_by_id(vrp.created_by_id)
      identities << record_dashboard_identity(record) if record
    end

    if model_ready?(:ModuleRecord)
      matched_records = []
      matched_records.concat(Array(new_user_module_records_by_email[vrp.email.to_s.strip.downcase])) if vrp.email.present?
      matched_records.concat(Array(new_user_module_records_by_mobile[vrp.mobile_no.to_s.strip])) if vrp.mobile_no.present?
      matched_records.uniq!(&:id)
      matched_records.each do |record|
        identities << record_dashboard_identity(record)
      end
    end

    identities << {
      role: current_app_user&.dig("role"),
      role_name: current_app_user&.dig("role_name"),
      stakeholder: current_app_user&.dig("stakeholder"),
      stakeholder_role: current_app_user&.dig("stakeholder_role"),
      user_management_role: current_app_user&.dig("user_management_role"),
      person_type: current_app_user&.dig("person_type"),
      office: current_app_user&.dig("sub_office_name").presence || current_app_user&.dig("office"),
      office_category: current_app_user&.dig("office_category").presence || current_app_user&.dig("office_name"),
      user_name: current_app_user&.dig("username").presence || current_app_user&.dig("user_name"),
      user_names: [current_app_user&.dig("username"), current_app_user&.dig("user_name"), current_app_user&.dig("name")]
    } if vrp.created_by_id.blank?

    @vrp_creator_identities_for_dashboard_cache[cache_key] = identities
      .select { |identity| identity[:stakeholder].present? && (identity[:role].present? || identity_user_name_values(identity).present?) }
      .uniq
  end

  def new_user_module_records
    return [] unless model_ready?(:ModuleRecord)

    @new_user_module_records ||= ModuleRecord.where(module_slug: "new-user").to_a
  end

  def new_user_module_records_by_email
    @new_user_module_records_by_email ||= new_user_module_records
      .select { |record| record.data["email"].present? }
      .group_by { |record| record.data["email"].to_s.strip.downcase }
  end

  def new_user_module_records_by_mobile
    @new_user_module_records_by_mobile ||= new_user_module_records
      .select { |record| record.data["mobile_no"].present? }
      .group_by { |record| record.data["mobile_no"].to_s.strip }
  end

  def cached_module_record_find_by_id(id)
    return if id.blank? || !model_ready?(:ModuleRecord)

    @cached_module_record_find_by_id ||= {}
    key = id.to_s
    return @cached_module_record_find_by_id[key] if @cached_module_record_find_by_id.key?(key)

    @cached_module_record_find_by_id[key] = ModuleRecord.find_by(id: id)
  end

  def preload_dashboard_vrp_identity_records!(vrps)
    vrps = Array(vrps)
    return if vrps.blank?

    creator_ids = vrps.filter_map { |vrp| vrp.created_by_id.to_s.presence }.uniq

    if model_ready?(:User)
      @cached_user_find_by ||= {}
      users = []
      creator_ids.each { |id| @cached_user_find_by["id=#{id}"] = nil }
      users.concat(User.where(id: creator_ids).to_a) if creator_ids.any?

      emails = vrps.filter_map { |vrp| vrp.email.to_s.strip.presence }.uniq
      emails.each { |email| @cached_user_find_by["email=#{email}"] = nil }
      users.concat(User.where(email: emails).to_a) if emails.any? && User.column_names.include?("email")

      mobile_numbers = vrps.filter_map { |vrp| vrp.mobile_no.to_s.strip.presence }.uniq
      mobile_numbers.each { |mobile_no| @cached_user_find_by["mobile_no=#{mobile_no}"] = nil }
      users.concat(User.where(mobile_no: mobile_numbers).to_a) if mobile_numbers.any? && User.column_names.include?("mobile_no")

      users.uniq(&:id).each do |user|
        @cached_user_find_by["id=#{user.id}"] = user
        @cached_user_find_by["email=#{user.email}"] = user if user.respond_to?(:email) && user.email.present?
        @cached_user_find_by["mobile_no=#{user.mobile_no}"] = user if user.respond_to?(:mobile_no) && user.mobile_no.present?
      end
    end

    return unless creator_ids.any? && model_ready?(:ModuleRecord)

    @cached_module_record_find_by_id ||= {}
    creator_ids.each { |id| @cached_module_record_find_by_id[id] = nil }
    ModuleRecord.where(id: creator_ids).find_each do |record|
      @cached_module_record_find_by_id[record.id.to_s] = record
    end
  end

  def cached_user_find_by(**attrs)
    return unless model_ready?(:User)

    @cached_user_find_by ||= {}
    cache_key = attrs.map { |key, value| "#{key}=#{value}" }.join("&")
    return @cached_user_find_by[cache_key] if @cached_user_find_by.key?(cache_key)

    @cached_user_find_by[cache_key] = User.find_by(attrs)
  end

  def cached_vrps_by_id
    return {} unless model_ready?(:Vrp)

    @cached_vrps_by_id ||= Vrp.includes(:vrp_bank_master, :vrp_profile, photo_attachment: :blob).index_by { |vrp| vrp.id.to_s }
  end

  def module_cluster_visible_vrp_id_strings
    @module_cluster_visible_vrp_id_strings ||= module_cluster_visible_vrp_ids.map(&:to_s)
  end

  def cached_vrp_lookup(vrp_id)
    return if vrp_id.blank? || !model_ready?(:Vrp)

    key = vrp_id.to_s
    @cached_vrp_lookup ||= {}
    return @cached_vrp_lookup[key] if @cached_vrp_lookup.key?(key)

    vrp = cached_vrps_by_id[key]
    unless vrp
      normalized_vrp = normalize_dashboard_text(vrp_id)
      vrp = cached_vrps_by_id.values.find do |candidate|
        candidate.name.to_s == vrp_id.to_s ||
          candidate.user_name.to_s == vrp_id.to_s ||
          candidate.mobile_no.to_s == vrp_id.to_s ||
          candidate.name.to_s.downcase == normalized_vrp.downcase
      end
    end

    @cached_vrp_lookup[key] = vrp
  end

  def user_dashboard_identity(user)
    {
      role: user.role,
      stakeholder: user.stakeholder,
      stakeholder_role: user.stakeholder_role,
      user_management_role: user.user_management_role,
      person_type: user.respond_to?(:person_type) ? user.person_type : nil,
      office: user.respond_to?(:sub_office_name) ? user.sub_office_name.presence || user.office : user.office,
      office_category: (user.respond_to?(:office_category) ? user.office_category : nil).presence || (user.respond_to?(:office_name) ? user.office_name : nil),
      user_name: user.user_name,
      user_names: [user.user_name, user.full_name]
    }
  end

  def record_dashboard_identity(record)
    full_name = [record.data["first_name"], record.data["last_name"]].compact_blank.join(" ")

    {
      role: record.data["role"],
      stakeholder: record.data["stakeholder"],
      stakeholder_role: record.data["stakeholder_role"],
      user_management_role: record.data["user_management_role"],
      person_type: record.data["person_type"],
      office: record.data["sub_office_name"].presence || record.data["office"],
      office_category: record.data["office_category"].presence || record.data["office_name"],
      user_name: record.data["user_name"],
      user_names: [record.data["user_name"], full_name, record.data["name"]]
    }
  end

  def vrp_approval_sequence(record)
    approval_sequence_from_level(record.data["approval_level"])
  end

  def approval_sequence_from_level(level)
    approval_level_sequence_from_text(level).presence || 1
  end

  def approval_level_sequence_from_text(value)
    normalized = value.to_s.downcase.gsub(/\s+/, " ").strip
    return if normalized.blank?

    approval_ordinals.each do |label, sequence|
      return sequence if normalized.include?(label)
    end

    normalized[/\b(?:approval|level|lvl|l)\s*[-#:]?\s*(\d+)\b/, 1]&.to_i.presence ||
      normalized[/\A\s*(\d+)(?:st|nd|rd|th)?\s*(?:approval)?\s*\z/, 1]&.to_i.presence ||
      normalized[/\b(\d+)(?:st|nd|rd|th)?\s+approval\b/, 1]&.to_i.presence
  end

  def approval_ordinals
    {
      "first" => 1,
      "1st" => 1,
      "frist" => 1,
      "second" => 2,
      "2nd" => 2,
      "secound" => 2,
      "seconed" => 2,
      "third" => 3,
      "3rd" => 3,
      "thrid" => 3,
      "fourth" => 4,
      "4th" => 4,
      "forth" => 4,
      "fifth" => 5,
      "5th" => 5,
      "sixth" => 6,
      "6th" => 6,
      "seventh" => 7,
      "7th" => 7,
      "eighth" => 8,
      "8th" => 8,
      "ninth" => 9,
      "9th" => 9,
      "tenth" => 10,
      "10th" => 10
    }
  end

  def normalize_approval_label(label)
    label.to_s.sub(/\s*\([^)]*\)\s*\z/, "").strip.downcase
  end

  def dashboard_value_matches?(expected, actual)
    return true if expected.blank?

    expected.to_s.strip.casecmp(actual.to_s.strip).zero?
  end

  def approval_registration_module?(module_name)
    module_name.blank? || APPROVAL_REGISTRATION_MODULES.any? { |name| dashboard_value_matches?(module_name, name) }
  end

  def approval_identity_filters_match?(record, identity)
    approval_value_matches?(approval_record_office(record), identity[:office]) &&
      approval_value_matches?(record.data["office_category"], identity[:office_category]) &&
      approval_user_name_matches?(record.data["user_name"], identity_user_name_values(identity))
  end

  def approval_value_matches?(expected, actual)
    expected.blank? || actual.blank? || dashboard_value_matches?(expected, actual)
  end

  def approval_user_name_matches?(expected, actual)
    return true if expected.blank?

    Array(actual).compact_blank.any? do |value|
      dashboard_value_matches?(expected, value) ||
        dashboard_user_label_matches?(expected, [value])
    end
  end

  def identity_user_name_values(identity)
    (Array(identity[:user_names]) + [identity[:user_name]]).compact_blank.uniq
  end

  def approval_record_office(record)
    record.data["sub_office_name"].presence || record.data["office"]
  end

  def percentage(value, total)
    return "0%" if total.to_i.zero?

    "#{((value.to_f / total) * 100).round}%"
  end

  def authorize_farmer_target_access
    return if admin_dashboard_user?
    slug = current_slug.to_s
    sources = %w[training-form other-target seed-distribution-target papl360-target add-farmer-form]
    source = RECORD_SOURCE_SLUGS.fetch(slug, slug)
    if %w[access-control access-control-list].include?(slug)
      return head :forbidden
    end
    report = action_name == "farmer_participation_report"
    return unless sources.include?(source) || report

    return head :forbidden if %w[destroy toggle_status set_status import].include?(action_name)
    keys = view_context.allowed_sidebar_keys || []
    requested = report ? "farmer-participation-report" : slug
    # The dynamic farmer endpoint is called by the Training Form edit page.
    # CC users with Training Form List access must be able to load the saved
    # selected farmers before they submit the approval request.
    requested = "#{source}-list" if %w[edit update selected_farmers training_target_farmers].include?(action_name)
    head :forbidden unless keys.include?(requested)
  end

  def load_module!
    @slug = current_slug
    @module = MODULES[@slug]
    redirect_to dashboard_path, alert: "Module not found." and return unless @module
  end

  def current_slug
    params[:slug] || params[:module_slug]
  end

  def module_records
    return [] unless ModuleRecord.table_exists?

    records = bill_list_records_scope.to_a
    if record_source_slug == "jeevika-jankar-bill-process"
      records = if ["jeevika-jankar-payment-list", "jeevika-jankar-payment-list-detail"].include?(@slug) && jeevika_jankar_payment_module_access?(@slug)
        records.select { |record| jeevika_bill_final_approved?(record) }
      else
        records.select { |record| jeevika_jankar_bill_record_visible?(record) }
      end
      @jeevika_bill_visible_record_ids = records.map { |record| record.id.to_s }
    end
    records = records.select { |record| target_record_visible?(record) } if target_record_source?
    if @slug == "training-form-list"
      return records.sort_by { |record| [record.created_at || Time.at(0), record.id.to_i] }.reverse
    end
    return records.sort_by { |record| jeevika_bill_list_sort_value(record) } if @slug == "jeevika-jankar-bill-list"

    records.sort_by { |record| module_record_sort_value(record) }
  end

  # The Jeevika Jankar Bill List renders a per-bill summary (activity names, totals)
  # but never reads the farmer_details nested inside each bill_item — and that array
  # is ~97% of a bill's JSON (77 KB avg). Strip it in SQL for the list so we don't
  # parse megabytes of JSON per page load. Every displayed value stays identical;
  # the detail/print view loads the full record separately, so it is unaffected.
  def bill_list_records_scope
    base = ModuleRecord.where(module_slug: record_source_slug)
    return base unless @slug == "jeevika-jankar-bill-list"

    base.select(<<~SQL.squish)
      module_records.id, module_records.module_slug,
      module_records.created_at, module_records.updated_at,
      CASE
        WHEN jsonb_typeof(module_records.data::jsonb -> 'bill_items') = 'array'
        THEN jsonb_set(
               module_records.data::jsonb, '{bill_items}',
               COALESCE((
                 SELECT jsonb_agg(elem - 'farmer_details' ORDER BY ord)
                 FROM jsonb_array_elements(module_records.data::jsonb -> 'bill_items')
                   WITH ORDINALITY AS t(elem, ord)
               ), '[]'::jsonb)
             )::text
        ELSE module_records.data
      END AS data
    SQL
  end

  def training_edit_revision_for(record)
    return unless record&.module_slug == "training-form"

    @training_edit_revisions_by_record ||= ModuleRecord.where(module_slug: TrainingEditApproval::SLUG)
      .order(id: :desc).to_a.each_with_object({}) do |revision, index|
        index[revision.data["record_id"].to_s] ||= revision
      end
    revision = @training_edit_revisions_by_record[record.id.to_s]
    revision = TrainingEditApproval.assign_configured_channel!(revision) if revision
    revision
  end

  def screen_limited_module_records?
    request.format.html? &&
      params[:all].blank? &&
      @record.blank? &&
      @slug == "training-form-list"
  end

  def module_records_required_for_show?
    return true if @record.present?
    return true if @slug.to_s.end_with?("-list")
    return true if %w[
      stakeholder-master stakeholder-role role-name
      parent-office-add office-category-add office-mapping-add
      month-master
      state-master district-master block-master gram-panchayat-master village-master
    ].include?(@slug)
    return true if @slug == "lg-directory-list"
    return true if @slug == "jeevika-jankar-payment-list-detail"
    return true if @slug == "jeevika-jankar-completed-payment-list"

    false
  end

  def preserve_training_uploads(previous_data, next_data)
    %w[training_register_upload training_photo_upload_with_geo_tag].each do |key|
      next if next_data[key].blank?

      next_data[key] = (Array(previous_data[key]) + Array(next_data[key])).compact_blank.uniq
    end
    next_data
  end

  def active_module_records_scope(module_slug)
    ModuleRecord
      .where(module_slug: module_slug)
      .merge(active_module_records_scope_for_all_modules)
  end

  def active_module_records_scope_for_all_modules
    ModuleRecord
      .where.not("COALESCE(LOWER(BTRIM(data::jsonb ->> 'deleted')), '') IN (?)", %w[1 true yes deleted])
      .where.not("COALESCE(LOWER(BTRIM(data::jsonb ->> 'is_deleted')), '') IN (?)", %w[1 true yes deleted])
      .where.not("COALESCE(LOWER(BTRIM(data::jsonb ->> 'discarded')), '') IN (?)", %w[1 true yes deleted])
      .where("COALESCE(BTRIM(data::jsonb ->> 'status'), '') = '' OR LOWER(BTRIM(data::jsonb ->> 'status')) = 'active'")
  end

  def other_target_record_source?
    OTHER_TARGET_MODULE_SLUGS.include?(record_source_slug)
  end

  def target_record_source?
    TARGET_RECORD_MODULE_SLUGS.include?(record_source_slug)
  end

  def target_record_visible?(record)
    return true if admin_dashboard_user?

    if vrp_login_user?
      return false unless current_vrp_record.present?

      return target_record_matches_vrp?(record, current_vrp_record)
    end

    if module_cluster_incharge_login?
      vrp = target_record_vrp_for_visibility(record)
      return vrp.present? && module_cluster_visible_vrp_id_strings.include?(vrp.id.to_s)
    end

    return true if target_record_created_by_current_user?(record)

    vrp = target_record_vrp_for_visibility(record)
    if vrp
      return true if jeevika_bill_vrp_registered_by_current_user?(vrp)
      return true if jeevika_bill_vrp_office_visible?(vrp)
      return true if module_cluster_visible_vrp_id_strings.include?(vrp.id.to_s)
    end

    return false unless module_mapped_vrp_scope_active?

    module_cluster_visible_vrps.any? { |visible_vrp| target_record_matches_vrp?(record, visible_vrp) }
  end

  def target_record_vrp_for_visibility(record)
    return unless model_ready?(:Vrp)

    vrp_id = record.data["jeevika_jankar_id"].presence || record.data["vrp_id"].presence || record.data["select_vrp"].presence
    return cached_vrp_lookup(vrp_id) if vrp_id.present?

    cached_vrps_by_id.values.find { |vrp| target_record_matches_vrp?(record, vrp) }
  end

  def target_record_matches_vrp?(record, vrp)
    values = [
      record.data["jeevika_jankar_id"],
      record.data["vrp_id"],
      record.data["jeevika_jankar_name"],
      record.data["vrp_name"],
      record.data["select_vrp"],
      record.data["trainer_contact"],
      record.data["trainer_name"],
      record.data["contact_number"],
      record.data["jeevika_jankar_contact"]
    ].map { |value| normalize_dashboard_text(value) }.reject(&:blank?)
    return false if values.blank?

    labels = [
      vrp.id,
      vrp.name,
      vrp.user_name,
      vrp.mobile_no,
      [vrp.name, vrp.mobile_no.presence].compact_blank.join(" - ")
    ].map { |value| normalize_dashboard_text(value) }.reject(&:blank?)

    (values & labels).any?
  end

  def target_record_created_by_current_user?(record)
    data = record.data
    current_ids = dashboard_current_app_user_ids.map(&:to_s)
    return true if data["created_by_id"].present? && current_ids.include?(data["created_by_id"].to_s)

    current_values = normalized_visibility_values(
      current_app_user&.dig("username"),
      current_app_user&.dig("user_name"),
      current_app_user&.dig("name"),
      current_app_user&.dig("email"),
      current_app_user&.dig("mobile_no")
    )
    record_values = normalized_visibility_values(
      data["created_by_username"],
      data["created_by_name"],
      data["created_by_email"],
      data["trainer_name"],
      data["trainer_contact"]
    )

    (current_values & record_values).any?
  end

  def prepare_lg_directory_data
    @lg_directory_filter = params[:table].presence_in(lg_directory_filter_fields) || "State Name"
    @lg_directory_query = params[:q].to_s.strip
    @lg_directory_rows = filtered_lg_directory_rows(lg_directory_rows)
  end

  def filtered_lg_directory_rows(rows)
    return rows if @lg_directory_query.blank?

    key = lg_directory_filter_key(@lg_directory_filter)
    rows.select { |row| row[key].to_s.downcase.include?(@lg_directory_query.downcase) }
  end

  def lg_directory_rows
    return [] unless model_ready?(:ModuleRecord)

    rows = []
    rows.concat(lg_rows_from_records("village-master", village: "village_name"))
    rows.concat(lg_rows_from_records("gram-panchayat-master", gram_panchayat: "gram_panchayat_name"))
    rows.concat(lg_rows_from_records("block-master", block: "block_name"))
    rows.concat(lg_rows_from_records("district-master", district: "district_name"))
    rows.concat(lg_rows_from_records("state-master", state: "state_name"))
    rows.concat(lg_rows_from_records("lg-directory-list",
      state: "state_name",
      district: "district_name",
      sub_district: "sub_district_name",
      block: "cd_block_name",
      block_code: "cd_block_code",
      village: "village_name"))
    state_codes = lg_directory_code_lookup(rows, :state, :state_code)
    district_codes = lg_directory_code_lookup(rows, :district, :district_code)
    block_codes = lg_directory_code_lookup(rows, :block, :block_code)
    gp_codes = lg_directory_code_lookup(rows, :gram_panchayat, :gp_code)

    compact_lg_directory_rows(rows)
      .map do |row|
        row.merge(
          state_code: row[:state_code].presence || state_codes[row[:state].to_s.strip.downcase],
          district_code: row[:district_code].presence || district_codes[row[:district].to_s.strip.downcase],
          block_code: row[:block_code].presence || block_codes[row[:block].to_s.strip.downcase],
          gp_code: row[:gp_code].presence || gp_codes[row[:gram_panchayat].to_s.strip.downcase]
        )
      end
      .uniq { |row| lg_directory_row_key(row) }
      .sort_by { |row| [row[:state], row[:district], row[:sub_district], row[:block], row[:gram_panchayat], row[:village]].map(&:to_s) }
  end

  def lg_rows_from_records(module_slug, aliases)
    ModuleRecord
      .where(module_slug: module_slug)
      .order(created_at: :desc)
      .map { |record| lg_directory_row_from_record(record, aliases) }
  end

  def lg_directory_row_from_record(record, aliases = {})
    normalize_lg_gram_fields(
      record_id: record.id,
      source_slug: record.module_slug,
      state: record.data["state"].presence || record.data[aliases[:state].to_s].presence,
      state_code: record.data["state_code"].presence || record.data[aliases[:state_code].to_s].presence,
      district: record.data["district"].presence || record.data[aliases[:district].to_s].presence,
      district_code: record.data["district_code"].presence || record.data[aliases[:district_code].to_s].presence,
      sub_district: record.data["sub_district"].presence || record.data[aliases[:sub_district].to_s].presence,
      sub_district_code: record.data["sub_district_code"].presence || record.data[aliases[:sub_district_code].to_s].presence,
      block: record.data["block"].presence || record.data[aliases[:block].to_s].presence,
      block_code: record.data["block_code"].presence || record.data[aliases[:block_code].to_s].presence,
      gram_panchayat: record.data["gram_panchayat"].presence || record.data[aliases[:gram_panchayat].to_s].presence,
      gp_code: record.data["gp_code"].presence || record.data[aliases[:gp_code].to_s].presence,
      village: record.data["village"].presence || record.data[aliases[:village].to_s].presence,
      village_code: record.data["village_code"].presence || record.data[aliases[:village_code].to_s].presence,
      status: record.data["status"].presence || "Active"
    )
  end

  def normalize_lg_gram_fields(row)
    gram_name = row[:gram_panchayat].to_s.strip
    gram_code = row[:gp_code].to_s.strip
    if code_like_location_value?(gram_name) && gram_code.present? && !code_like_location_value?(gram_code)
      row.merge(gram_panchayat: gram_code, gp_code: gram_name)
    else
      row
    end
  end

  def lg_directory_aliases_for_slug(module_slug)
    {
      "lg-directory-list" => {
        state: "state_name",
        district: "district_name",
        sub_district: "sub_district_name",
        block: "cd_block_name",
        block_code: "cd_block_code",
        village: "village_name"
      },
      "village-master" => { village: "village_name" },
      "gram-panchayat-master" => { gram_panchayat: "gram_panchayat_name" },
      "block-master" => { block: "block_name" },
      "district-master" => { district: "district_name" },
      "state-master" => { state: "state_name" }
    }.fetch(module_slug, {})
  end

  def lg_directory_matching_records(records)
    row_keys = records.map do |record|
      lg_directory_row_key(lg_directory_row_from_record(record, lg_directory_aliases_for_slug(record.module_slug)))
    end.uniq

    ModuleRecord
      .where(module_slug: lg_directory_allowed_slugs)
      .select do |record|
        row_keys.include?(lg_directory_row_key(lg_directory_row_from_record(record, lg_directory_aliases_for_slug(record.module_slug))))
      end
  end

  def lg_directory_edit_record(record)
    records = lg_directory_matching_records([record])
    preferred_slugs = ["village-master", "gram-panchayat-master", "block-master", "district-master", "state-master"]

    records
      .select { |candidate| preferred_slugs.include?(candidate.module_slug) }
      .min_by { |candidate| preferred_slugs.index(candidate.module_slug) }
  end

  def lg_directory_code_lookup(rows, name_key, code_key)
    rows.each_with_object({}) do |row, codes|
      next if row[name_key].blank? || row[code_key].blank?

      codes[row[name_key].to_s.strip.downcase] ||= row[code_key]
    end
  end

  def compact_lg_directory_rows(rows)
    rows.reject { |row| lg_directory_prefix_covered?(row, rows) }
  end

  def lg_directory_prefix_covered?(row, rows)
    levels = [:state, :district, :sub_district, :block, :gram_panchayat, :village]
    last_present_index = levels.rindex { |key| row[key].present? }
    return false unless last_present_index
    return false if last_present_index == levels.size - 1

    prefix = levels.first(last_present_index + 1)
    rows.any? do |candidate|
      next false if candidate.equal?(row)

      prefix.all? { |key| candidate[key].to_s.strip.casecmp(row[key].to_s.strip).zero? } &&
        levels[(last_present_index + 1)..].any? { |key| candidate[key].present? }
    end
  end

  def lg_directory_row_key(row)
    [:state_code, :state, :district_code, :district, :sub_district_code, :sub_district, :block_code, :block, :gp_code, :gram_panchayat, :village_code, :village]
      .map { |key| row[key].to_s.strip.downcase }
      .join("|")
  end

  def lg_directory_filter_fields
    ["State Name", "State Code", "District Name", "District Code", "Block Name", "Block Code", "Gram Name", "Gram Code", "Village Name", "Village Code"]
  end

  def lg_directory_filter_key(field)
    {
      "State Name" => :state,
      "State Code" => :state_code,
      "District Name" => :district,
      "District Code" => :district_code,
      "Block Name" => :block,
      "Block Code" => :block_code,
      "Gram Name" => :gram_panchayat,
      "Gram Code" => :gp_code,
      "Village Name" => :village,
      "Village Code" => :village_code
    }.fetch(field, :state)
  end

  def lg_directory_import_notice_counts(counts)
    {
      "lg-directory-list" => "All List",
      "state-master" => "State",
      "district-master" => "District",
      "block-master" => "Block",
      "gram-panchayat-master" => "GP",
      "village-master" => "Village"
    }.filter_map do |slug, label|
      count = counts[slug].to_i
      "#{label}: #{count}" if count.positive?
    end.join(", ")
  end

  def lg_directory_selected_records
    Array(params[:row_tokens]).filter_map do |token|
      slug, id = token.to_s.split(":", 2)
      next unless lg_directory_allowed_slugs.include?(slug) && id.present?

      ModuleRecord.where(module_slug: slug).find_by(id: id)
    end.uniq
  end

  def lg_directory_allowed_slugs
    [
      "lg-directory-list",
      "state-master",
      "district-master",
      "block-master",
      "gram-panchayat-master",
      "village-master"
    ]
  end

  def lg_directory_csv(rows)
    CSV.generate(headers: true) do |csv|
      csv << ["State Name", "State Code", "District Name", "District Code", "Block Name", "Block Code", "Gram Name", "Gram Code", "Village Name", "Village Code"]
      rows.each do |row|
        csv << [
          row[:state],
          row[:state_code],
          row[:district],
          row[:district_code],
          row[:block],
          row[:block_code],
          row[:gram_panchayat],
          row[:gp_code],
          row[:village],
          row[:village_code]
        ]
      end
    end
  end

  def module_records_csv(records)
    fields = @module[:fields]
    field_keys = fields.map { |field| field.parameterize(separator: "_") }

    CSV.generate(headers: true) do |csv|
      csv << fields
      records.each do |record|
        csv << fields.zip(field_keys).map do |field, key|
          value = record.data[key].to_s
          if field == "Training Register Upload" || field == "Training Photo Upload with Geo Tag" || field.downcase.include?("upload") || field.downcase.include?("file")
            module_upload_public_url(value)
          else
            value
          end
        end
      end
    end
  end

  def module_records_attachments_zip(records)
    files = Array(records).flat_map do |record|
      module_record_attachment_files(record)
    end

    used_names = Hash.new(0)
    Zip::OutputStream.write_buffer do |zip|
      files.each do |file|
        base_name = file[:name].presence || "attachment"
        used_names[base_name] += 1
        entry_name = if used_names[base_name] > 1
          extension = File.extname(base_name)
          stem = File.basename(base_name, extension)
          "#{stem}-#{used_names[base_name]}#{extension}"
        else
          base_name
        end

        zip.put_next_entry(entry_name)
        zip.write(file[:content])
      end
    end.string
  end

  def module_record_attachment_files(record)
    fields = %w[training_register_upload training_photo_upload_with_geo_tag]

    fields.flat_map do |field|
      module_upload_public_urls(record.data[field]).filter_map do |url|
        module_upload_attachment_file(url)
      end
    end
  end

  def selected_farmer_rows_for(record)
    selected_ids = Array(record.data["selected_farmer_ids"]).map(&:to_s).reject(&:blank?).uniq
    return [] if selected_ids.blank?

    farmers_by_id = if model_ready?(:Afl)
      Afl.where(id: selected_ids).index_by { |farmer| farmer.id.to_s }
    else
      {}
    end
    names_by_id = Array(record.data["selected_farmer_names"]).map(&:to_s)

    selected_ids.map.with_index do |id, index|
      farmer = farmers_by_id[id]
      {
        id: id,
        farmer_name: farmer&.farmer_name.presence || names_by_id[index].presence || "Farmer ##{id}",
        father_name: farmer&.father_name.presence || "-",
        tracenet_no: farmer&.tracenet_no.presence || "-",
        mobile_no: farmer&.mobile_no.presence || "-",
        khasara_no: farmer&.khasara_no.presence || "-"
      }
    end
  end

  def import_module_records(file)
    raise ArgumentError, "Please choose an Excel or CSV file." unless file.present?
    raise ArgumentError, "Import is not available for this module." unless @module.present?

    rows = LgDirectoryImporter.rows_from_upload(file).map { |row| Array(row).map { |cell| cell.to_s.strip } }
    rows.reject! { |row| row.all?(&:blank?) }
    raise ArgumentError, "No rows found in uploaded file." if rows.blank?

    headers = rows.shift
    header_keys = headers.map { |header| module_import_header_key(header) }
    raise ArgumentError, "No matching headers found. Use: #{@module[:fields].join(", ")}." if header_keys.compact.blank?

    imported = 0
    rows.each do |row|
      data = {}
      header_keys.each_with_index do |key, index|
        next if key.blank?

        data[key] = row[index].to_s.strip
      end
      data.compact_blank!
      next if data.blank?

      data["status"] = "Active" if @module[:fields].include?("Status") && data["status"].blank?
      ModuleRecord.create!(module_slug: @slug, data: data)
      imported += 1
    end

    raise ArgumentError, "No valid records found in uploaded file." if imported.zero?

    { imported: imported }
  end

  def module_import_header_key(header)
    normalized_header = normalized_import_header(header)
    field = @module[:fields].find do |candidate|
      normalized_import_header(candidate) == normalized_header ||
        normalized_import_header(helpers.resource_person_label(candidate)) == normalized_header
    end
    field&.parameterize(separator: "_")
  end

  def normalized_import_header(value)
    value.to_s.downcase.gsub(/[^a-z0-9]+/, "")
  end

  def prepare_vrp_bill_data
    @approved_vrp_options = approved_vrp_options
    month_master_rows = active_month_master_rows
    @bill_financial_year_options = month_master_financial_year_options(month_master_rows)
    @bill_month_options = month_master_month_options(month_master_rows)
    @bill_project_options = module_record_values("ics-master", "ics_name", "name", "ics", "select_ics") +
      module_record_values("add-vrp-activity", "ics", "select_ics", "ics_name")
    @bill_project_options = @bill_project_options.compact_blank.uniq

    @bill_activity_group_options = module_record_values("add-activity-group", "main_activity_name", "activity_group_name", "activity_group", "group_name", "name") +
      module_record_values("add-vrp-activity", "activity_group", "activity_group_name", "group_name")
    @bill_activity_group_options = @bill_activity_group_options.compact_blank.uniq
    @bill_village_options = module_field_options("Village")
    @bill_activity_map = bill_activity_map
    @bill_tci_map = bill_tci_map
  end

  def prepare_jeevika_jankar_bill_data
    month_master_rows = active_month_master_rows
    @jeevika_jankar_vrp_options = approved_vrp_id_options
    @jeevika_jankar_month_options = month_master_month_options(month_master_rows)
    @jeevika_jankar_financial_year_options = month_master_financial_year_options(month_master_rows)
    @jeevika_jankar_invoice_no = @record&.data&.[]("invoice_no").presence || generated_jeevika_jankar_invoice_no
    @jeevika_jankar_invoice_date = @record&.data&.[]("invoice_date").presence || Date.current.to_s
    @jeevika_jankar_bill_rows = if @record.present?
      jeevika_jankar_bill_rows(
        vrp_id: @record.data["select_vrp"].presence,
        month_name: @record.data["bill_month"].presence
      )
    else
      []
    end
    @jeevika_jankar_achievement_summary = jeevika_jankar_achievement_summary(@jeevika_jankar_bill_rows)
    @jeevika_jankar_target_summary ||= jeevika_jankar_target_summary_from_rows(@jeevika_jankar_bill_rows)
    @jeevika_jankar_saved_items = jeevika_jankar_saved_items
    @jeevika_jankar_existing_bills = jeevika_jankar_existing_bill_keys
  end

  def prepare_jeevika_jankar_bill_list
    @bill_list_master_months = month_master_month_options
    return if params[:view_id].blank?

    record = ModuleRecord.find_by(id: params[:view_id])
    if record.present? && jeevika_jankar_bill_record_visible?(record)
      @bill_detail_record = record
    else
      flash.now[:alert] = "You are not allowed to view this bill."
    end
  end

  def jeevika_bill_rows(records)
    preload_dashboard_vrp_identity_records!(Array(records).filter_map { |record| jeevika_bill_vrp(record) }.uniq(&:id))
    preload_jeevika_bill_process_totals(records)
    Array(records).map do |record|
      data = record.data
      summary = jeevika_bill_summary(record)
      approval_history = jeevika_bill_approval_history(record)
      {
        id: record.id,
        edit_path: edit_module_record_path("jeevika-jankar-bill-process", record),
        view_path: module_path("jeevika-jankar-bill-list", view_id: record.id),
        download_path: download_bill_module_record_path("jeevika-jankar-bill-list", record),
        send_path: send_for_approval_module_record_path("jeevika-jankar-bill-list", record),
        approve_path: approve_bill_module_record_path("jeevika-jankar-bill-list", record),
        reject_path: reject_bill_module_record_path("jeevika-jankar-bill-list", record),
        active_path: set_bill_state_module_record_path("jeevika-jankar-bill-list", record, state: "Active"),
        inactive_path: set_bill_state_module_record_path("jeevika-jankar-bill-list", record, state: "Inactive"),
        delete_path: module_record_path("jeevika-jankar-bill-list", record),
        status: jeevika_bill_status_label(record),
        status_class: jeevika_bill_status_class(record),
        current_approver: jeevika_bill_current_approver?(record),
        created_by_name: data["created_by_name"].presence || data["created_by_username"].presence || "-",
        created_by_current_user: jeevika_bill_created_by_current_user?(record),
        approver_visible: jeevika_bill_approver_visible?(record),
        approval_remarks: bill_approval_remarks_text(approval_history),
        remarks: data["remarks"].presence || "-",
        record_state: data["record_state"].presence || "Active",
        bill_id: record.id,
        vrp_id: data["select_vrp"],
        name: jeevika_jankar_display_name(data["select_vrp_name"].presence || jeevika_jankar_vrp_label(data["select_vrp"])),
        financial_year: data["financial_year"].presence || jeevika_month_financial_year(data["bill_month"]).presence || "-",
        bill_month: data["bill_month"].presence || "-",
        activity_groups: summary[:activity_groups].presence || "-",
        activity_names: summary[:activity_names].presence || "-",
        target: jeevika_jankar_bill_total_target(record),
        achievement: jeevika_jankar_bill_total_achievement(record),
        amount: jeevika_jankar_bill_total_payment(record)
      }
    end
  end

  def jeevika_bill_payment_month_options(records)
    record_months = Array(records)
      .select { |record| jeevika_bill_final_approved?(record) }
      .filter_map { |record| record.data["bill_month"].to_s.strip.presence }

    (month_master_month_options + record_months)
      .uniq { |month| normalize_dashboard_text(month) }
      .sort_by { |month| [Date::MONTHNAMES.find_index { |name| name.to_s.casecmp(month).zero? }.presence || 99, month] }
  end

  def jeevika_bill_payment_rows(records, selected_month)
    filtered_records = Array(records).select do |record|
      jeevika_bill_final_approved?(record) &&
        (selected_month.blank? || record.data["bill_month"].to_s.strip.casecmp(selected_month.to_s.strip).zero?)
    end

    filtered_by_id = filtered_records.index_by(&:id)
    jeevika_bill_rows(filtered_records).map do |row|
      record = filtered_by_id[row[:id]]
      vrp = jeevika_bill_vrp(record)
      bank_row = jeevika_bill_bank_rows(record).first || {}

      row.merge(
        bank_name: bank_row[:bank_name].presence || "-",
        ifsc_code: bank_row[:ifsc_code].presence || "-",
        account_number: bank_row[:account_number].presence || "-",
        passbook_attachment: vrp&.bank_passbook_upload
      )
    end
  end

  def jeevika_payment_transaction_types
    JEEVIKA_PAYMENT_TRANSACTION_TYPES
  end

  def jeevika_payment_bill_date_options(records)
    Array(records)
      .select { |record| jeevika_bill_final_approved?(record) }
      .reject { |record| jeevika_paid_bill_ids.include?(record.id.to_s) }
      .filter_map { |record| jeevika_bill_final_approval_date(record).presence }
      .uniq
      .sort
      .reverse
  end

  # Older bills never stored financial_year. Each month maps to a single financial year
  # in Month Master, so fall back to that so the payment lists always show it.
  def jeevika_month_financial_year(month_name)
    return nil if month_name.blank?

    @jeevika_month_financial_year ||= active_month_master_rows.each_with_object({}) do |record, map|
      month = normalize_dashboard_text(record.data["month_name"])
      year = record.data["financial_year"].presence
      map[month] ||= year if month.present? && year
    end
    @jeevika_month_financial_year[normalize_dashboard_text(month_name)]
  end

  def jeevika_bill_financial_year(record)
    data = record.respond_to?(:data) ? record.data : record
    data["financial_year"].presence || jeevika_month_financial_year(data["bill_month"]).presence || "-"
  end

  def jeevika_payment_selectable_rows(records)
    preload_dashboard_vrp_identity_records!(Array(records).filter_map { |record| jeevika_bill_vrp(record) }.uniq(&:id))
    paid_ids = jeevika_paid_bill_ids
    Array(records)
      .select { |record| jeevika_bill_final_approved?(record) }
      .reject { |record| paid_ids.include?(record.id.to_s) }
      .map do |record|
        vrp = jeevika_bill_vrp(record)
        {
          id: record.id,
          approval_date: jeevika_bill_final_approval_date(record),
          approval_date_label: bill_display_date(jeevika_bill_final_approval_date(record)),
          vrp_id: record.data["select_vrp"].presence || "-",
          name: jeevika_jankar_display_name(record.data["select_vrp_name"].presence || jeevika_jankar_vrp_label(record.data["select_vrp"])).presence || "-",
          mobile_no: vrp&.mobile_no.presence || "-",
          bill_month: record.data["bill_month"].presence || "-",
          financial_year: jeevika_bill_financial_year(record),
          amount: format("%.2f", jeevika_jankar_bill_total_payment(record).to_f)
        }
      end
  end

  def jeevika_payment_detail_rows
    jeevika_payment_detail_records.map do |record|
      items = Array(record.data["payment_items"])
      {
        id: record.id,
        approval_date: record.data["approval_date"].presence || record.data["payment_bill_date"].presence || "-",
        transaction_date: record.data["transaction_date"].presence || "-",
        transaction_type: record.data["transaction_type"].presence || "-",
        transaction_id: record.data["transaction_id"].presence || "-",
        selected_count: record.data["selected_count"].presence || items.size,
        amount: record.data["jeevika_jankar_payment_amount"].presence || "0.00",
        transaction_file: record.data["transaction_file"].presence,
        excel_file: record.data["excel_file"].presence
      }
    end
  end

  def jeevika_completed_payment_rows
    jeevika_payment_detail_records.flat_map do |record|
      Array(record.data["payment_items"]).map do |item|
        next unless item.respond_to?(:[])
        next unless jeevika_completed_payment_item_visible?(item)

        vrp = cached_vrp_lookup(item["jeevika_jankar_id"]) if item["jeevika_jankar_id"].present?
        {
          jeevika_jankar_id: item["jeevika_jankar_id"].presence || "-",
          name: item["jeevika_jankar_name"].presence || vrp&.name.presence || "-",
          mobile_no: vrp&.mobile_no.presence || "-",
          financial_year: item["financial_year"].presence || jeevika_month_financial_year(item["bill_month"]).presence || "-",
          bill_month: item["bill_month"].presence || "-",
          approval_date: item["approval_date"].presence || record.data["approval_date"].presence || "-",
          amount: item["amount"].presence || format("%.2f", JEEVIKA_JANKAR_BILL_FIXED_TOTAL),
          transaction_id: record.data["transaction_id"].presence || "-",
          transaction_type: record.data["transaction_type"].presence || "-",
          transaction_date: record.data["transaction_date"].presence || "-",
          transaction_file: record.data["transaction_file"].presence,
          excel_file: record.data["excel_file"].presence
        }
      end.compact
    end
  end

  def jeevika_completed_payment_month_options(rows = nil)
    row_months = Array(rows || jeevika_completed_payment_rows)
      .filter_map { |row| row[:bill_month].to_s.strip.presence }
      .reject { |month| month == "-" }

    (month_master_month_options + row_months)
      .uniq { |month| normalize_dashboard_text(month) }
      .sort_by { |month| [Date::MONTHNAMES.find_index { |name| name.to_s.casecmp(month).zero? }.presence || 99, month] }
  end

  def jeevika_completed_payment_date_options(rows = nil, selected_month = nil)
    filtered_rows = Array(rows || jeevika_completed_payment_rows)
    if selected_month.present?
      filtered_rows = filtered_rows.select do |row|
        row[:bill_month].to_s.strip.casecmp(selected_month.to_s.strip).zero?
      end
    end

    filtered_rows
      .filter_map { |row| row[:approval_date].to_s.strip.presence }
      .reject { |date| date == "-" }
      .uniq
      .sort
      .reverse
  end

  def jeevika_completed_payment_item_visible?(item)
    return true if admin_dashboard_user?

    vrp_id = item["jeevika_jankar_id"].presence
    if vrp_id.blank?
      bill_record = jeevika_payment_bill_record_for_item(item)
      vrp_id = bill_record&.data&.[]("select_vrp")
    end
    scoped_jeevika_vrp_visible?(cached_vrp_lookup(vrp_id))

  end

  def jeevika_payment_bill_record_for_item(item)
    bill_id = item["bill_id"].to_s.strip
    return nil if bill_id.blank?

    jeevika_payment_bill_record_cache[bill_id]
  end

  def jeevika_payment_bill_record_cache
    @jeevika_payment_bill_record_cache ||= begin
      bill_ids = jeevika_payment_detail_records.flat_map do |record|
        Array(record.data["selected_bill_ids"]) +
          Array(record.data["payment_items"]).filter_map { |item| item["bill_id"] if item.respond_to?(:[]) }
      end.map(&:to_s).reject(&:blank?).uniq

      ModuleRecord
        .where(module_slug: "jeevika-jankar-bill-process", id: bill_ids)
        .index_by { |record| record.id.to_s }
    end
  end

  def jeevika_paid_bill_ids
    @jeevika_paid_bill_ids ||= jeevika_payment_details_by_bill_id.keys
  end

  def jeevika_payment_details_by_bill_id
    @jeevika_payment_details_by_bill_id ||= begin
      rows = {}
      jeevika_payment_detail_records.each do |record|
        Array(record.data["selected_bill_ids"]).each { |bill_id| rows[bill_id.to_s] ||= record }
        Array(record.data["payment_items"]).each do |item|
          rows[item["bill_id"].to_s] ||= record if item.respond_to?(:[])
        end
      end
      rows
    end
  end

  def jeevika_payment_detail_records
    return [] unless model_ready?(:ModuleRecord)

    @jeevika_payment_detail_records ||= ModuleRecord
      .where(module_slug: JEEVIKA_JANKAR_PAYMENT_DETAIL_SLUG)
      .order(created_at: :desc, id: :desc)
      .to_a
  end

  def jeevika_bill_final_approved?(record)
    record.data["status"].to_s.downcase.include?("final approved")
  end

  def jeevika_bill_detail_rows(record)
    raw_items = record&.data&.[]("bill_items")
    raw_items = raw_items.values if raw_items.is_a?(Hash)
    Array(raw_items).select { |item| item.respond_to?(:[]) }
  end

  def jeevika_bill_summary(record)
    @jeevika_bill_summary_cache ||= {}
    key = [record&.id || record&.object_id, record&.data&.hash]
    return @jeevika_bill_summary_cache[key] if @jeevika_bill_summary_cache.key?(key)

    @jeevika_bill_summary_cache[key] = compute_jeevika_bill_summary(record)
  end

  def compute_jeevika_bill_summary(record)
    data = record&.data || {}
    items = jeevika_bill_detail_rows(record)
    amount = jeevika_jankar_bill_total_payment(record)
    deduction = data["deduction_amount"].presence || data["deduction"].presence
    payable = amount.to_f - deduction.to_f

    {
      to: first_present_data(data, "to", "to_name", "to_office").presence || first_present_from_items(items, "to", "to_name", "to_office"),
      fco: first_present_data(data, "fco", "fco_name").presence || first_present_from_items(items, "fco", "fco_name"),
      projects: first_present_data(data, "projects", "project", "select_project").presence || first_present_from_items(items, "project", "projects"),
      activity_groups: items.filter_map { |item| item["main_activity"].presence }.uniq.join(", "),
      activity_names: items.filter_map { |item| item["activity"].presence }.uniq.join(", "),
      total_amount: amount,
      deduction_amount: deduction,
      total_payable: payable
    }
  end

  def jeevika_jankar_bill_total_payment(record = nil)
    fixed_total = format("%.2f", JEEVIKA_JANKAR_BILL_FIXED_TOTAL)
    return fixed_total if record.blank?

    amount = record.data["grand_total"]
    amount.presence && amount.to_f.positive? ? amount : fixed_total
  end

  def jeevika_bill_attachment_rows(record)
    vrp = jeevika_bill_vrp(record)
    [
      ["VRP Photo", vrp&.photo],
      ["VRP Aadhaar Card", vrp&.aadhar_upload],
      ["VRP Bank Passbook", vrp&.bank_passbook_upload]
    ]
  end

  def jeevika_bill_time_slot_rows(record)
    jeevika_bill_detail_rows(record).flat_map do |item|
      dates = item["timesheet_dates"].to_s.split(",").map(&:strip).reject(&:blank?)
      dates = Array(item["farmer_details"]).filter_map { |farmer| farmer["training_date"].presence }.uniq if dates.blank?
      dates = ["-"] if dates.blank?

      dates.map do |date|
        {
          working_date: bill_display_date(date),
          village: item["village"].presence || "-",
          activity: item["main_activity"].presence || "-",
          tci: item["activity"].presence || "-",
          number: item["achievement_count"].presence || item["assigned_count"].presence || "0"
        }
      end
    end
  end

  def jeevika_bill_description_rows(record)
    jeevika_bill_detail_rows(record)
      .group_by { |item| item["main_activity"].presence || item["activity"].presence || "Activity" }
      .map.with_index do |(description, rows), index|
        {
          index: index + 1,
          description: description,
          rate: rows.find { |item| item["rate"].present? }&.[]("rate").presence || "0.00",
          number: dashboard_quantity(rows.sum { |item| item["achievement_count"].to_f }),
          total: rows.sum { |item| item["amount"].to_f }
        }
      end
  end

  def jeevika_bill_bank_rows(record)
    vrp = jeevika_bill_vrp(record)
    return [] unless vrp

    [
      {
        bank_name: vrp.bank_name.presence || (vrp.vrp_bank_master&.name).presence || "-",
        account_number: vrp.account_no.presence || "-",
        ifsc_code: vrp.ifsc_code.presence || "-",
        address: vrp.address.presence || vrp.branch.presence || "-"
      }
    ]
  end

  def jeevika_bill_prepared_by(record)
    sent_history = jeevika_bill_approval_history(record).find { |history| history.data["action"].to_s == "Sent for Approval" }
    {
      name: jeevika_bill_prepared_by_name(sent_history&.data&.[]("action_by")),
      at: bill_display_datetime(sent_history&.data&.[]("action_at").presence || record.created_at)
    }
  end

  # History only stores the plain name, so pull the role off the user to match the
  # "Name (Role)" form used for approvers.
  def jeevika_bill_prepared_by_name(action_by)
    return "-" if action_by.blank?

    role = bill_submitter_user(action_by)&.role.presence
    jeevika_bill_approver_display_name(role ? "#{action_by.squish} (#{role})" : action_by, nil)
  end

  def jeevika_bill_approver_display_name(approver, action_by)
    label = approver.to_s.squish.presence || action_by.to_s.squish.presence || "-"
    name = label.split("(", 2).first.to_s.strip
    return jeevika_bill_role_display(label) if name.blank?

    # Older history can contain Name (Name (Role)), nested more than once.
    loop do
      match = label.match(/\A#{Regexp.escape(name)}\s*\(\s*(#{Regexp.escape(name)}(?:\s*\(.*\))?)\s*\)\z/i)
      break unless match

      label = match[1].strip
    end
    jeevika_bill_role_display(label)
  end

  # Roles are captured free-text, so drop the company suffix and normalise the FCO
  # prefix and casing to keep the printed headings consistent.
  def jeevika_bill_role_display(label)
    label
      .to_s
      .gsub(/,\s*PAPL\b/i, "")
      .gsub(/\bFCO-C\s+/i, "FCO-")
      # Title-case the role inside the parentheses (e.g. "agricultural specialist"
      # -> "Agricultural Specialist"); already-capitalised words/acronyms stay as is.
      .gsub(/\([^)]*\)/) { |paren| paren.gsub(/\b[a-z]/, &:upcase) }
  end

  # Driven by the Jeevika Jankar Approval List so every bill on a channel prints the
  # same steps. Approvals recorded outside the channel are kept so nothing is lost.
  def jeevika_bill_approved_by_rows(record)
    approvals = jeevika_bill_approval_history(record).select { |history| history.data["action"].to_s == "Approved" }
    matched = []

    rows = jeevika_bill_display_steps(record).map do |step|
      approver = step.data["approver_approved_by"]
      # Consume every approval for this approver, so a re-approval cannot also surface below.
      entries = approvals.select { |history| dashboard_user_label_matches?(history.data["approver"], [approver]) }
      matched.concat(entries)
      [approval_sequence_from_level(step.data["approval_level"]), approver, latest_bill_approval_entry(entries)]
    end

    (approvals - matched).group_by { |history| approval_sequence_from_level(history.data["approval_level"]) }.each do |sequence, entries|
      history = latest_bill_approval_entry(entries)
      rows << [sequence, history.data["approver"], history]
    end

    rows = rows.sort_by { |sequence, _approver, _history| sequence }
    last_sequence = rows.map(&:first).max

    rows.map do |sequence, approver, history|
      approval_label = if jeevika_bill_final_approved?(record) && sequence == last_sequence
        "Finance Approval"
      else
        approval_level_label_for_sequence(sequence)
      end
      [
        approval_label,
        jeevika_bill_approver_display_name(approver, history&.data&.[]("action_by")),
        history ? bill_display_datetime(history.data["action_at"]) : nil,
        history&.data&.[]("action_by").presence
      ]
    end
  end

  def latest_bill_approval_entry(entries)
    entries.max_by { |history| [parse_bill_datetime(history.data["action_at"]) || history.created_at || Time.at(0), history.id.to_i] }
  end

  def jeevika_bill_status_label(record)
    status = record.data["status"].presence || "Submitted (Not sent for approval)"
    return status if status.to_s.downcase.match?(/rejected|returned/)

    history_actions = jeevika_bill_approval_history(record).map { |history| history.data["action"].to_s }
    approval_started = status.to_s.downcase.include?("pending") ||
      history_actions.any? { |action| ["Sent for Approval", "Approved"].include?(action) }

    if approval_started && history_actions.exclude?("Rejected")
      steps = jeevika_bill_approval_steps(record)
      return status if steps.blank?

      step = jeevika_bill_current_approval_step(record)
      return "Pending at #{step.data["approver_approved_by"]}" if step
      return "Final Approved"
    end

    status
  end

  def jeevika_bill_status_class(record)
    status = jeevika_bill_status_label(record).downcase
    return "approved" if status.include?("final approved")
    return "returned" if status.include?("returned")
    return "rejected" if status.include?("rejected")
    return "pending" if status.include?("pending")

    "submitted"
  end

  def bill_approval_remarks_text(history)
    Array(history)
      .reject { |record| record.data["remarks"].to_s.strip.blank? }
      .map do |record|
        [
          record.data["approval_level"].presence || "Approval",
          record.data["action"].presence,
          record.data["action_by"].presence || record.data["approver"].presence,
          record.data["remarks"].presence
        ].compact.join(" - ")
      end
      .join(" | ")
      .presence || "-"
  end

  def jeevika_bill_approval_steps(record)
    return [] unless model_ready?(:ModuleRecord)

    @jeevika_bill_approval_steps_cache ||= {}
    cache_key = record.id
    return @jeevika_bill_approval_steps_cache[cache_key] if @jeevika_bill_approval_steps_cache.key?(cache_key)

    steps = jeevika_bill_approval_master_steps

    matching_channel_keys = steps
      .select { |step| jeevika_bill_approval_step_matches_bill?(step, record) }
      .map { |step| approval_channel_key(step) }
      .uniq

    matching_channels = steps
      .select { |step| matching_channel_keys.include?(approval_channel_key(step)) }
      .group_by { |step| approval_channel_key(step) }
      .values
      .map { |records| ordered_approval_channel_steps(records) }
      .reject(&:blank?)

    @jeevika_bill_approval_steps_cache[cache_key] = matching_channels.max_by { |records| approval_channel_priority(records) } || []
  end

  # For the printed invoice only (routing is untouched): show the channel of whoever
  # PREPARED the bill, not the VRP registrant. A bill registered by an approver would
  # otherwise borrow that approver's shorter chain and drop a step from the invoice.
  # Falls back to the best-fitting channel when the preparer has none configured.
  def jeevika_bill_display_steps(record)
    preparer_channel = jeevika_bill_preparer_channel(record)
    return preparer_channel if preparer_channel.present?

    steps = jeevika_bill_approval_steps(record)
    return steps if steps.present?

    channels = jeevika_bill_all_channels
    return [] if channels.blank?

    approvers = jeevika_bill_approval_history(record)
      .select { |history| history.data["action"].to_s == "Approved" }
      .filter_map { |history| history.data["approver"].presence }

    channels.max_by do |channel|
      overlap = channel.count do |step|
        approvers.any? { |approver| dashboard_user_label_matches?(approver, [step.data["approver_approved_by"]]) }
      end
      [overlap, channel.size]
    end
  end

  # The channel keyed to the bill's preparer (the "Sent for Approval" actor). The channel's
  # user_name may hold the full name or the login, so match against both forms.
  def jeevika_bill_preparer_channel(record)
    preparer = jeevika_bill_approval_history(record)
      .find { |history| history.data["action"].to_s == "Sent for Approval" }
      &.data&.[]("action_by")
    return if preparer.blank?

    candidates = [preparer]
    user = bill_submitter_user(preparer)
    candidates += [user.user_name, user.full_name] if user
    candidates = candidates.compact_blank.uniq
    return if candidates.blank?

    jeevika_bill_all_channels.find do |channel|
      channel.any? { |step| dashboard_user_label_matches?(step.data["user_name"], candidates) }
    end
  end

  def jeevika_bill_all_channels
    @jeevika_bill_all_channels ||= jeevika_bill_approval_master_steps
      .group_by { |step| approval_channel_key(step) }
      .values
      .map { |records| ordered_approval_channel_steps(records) }
      .reject(&:blank?)
  end

  def jeevika_bill_approval_master_steps
    @jeevika_bill_approval_master_steps ||= ModuleRecord
      .where(module_slug: "approval-master")
      .order(created_at: :asc)
      .select { |step| active_module_record?(step) }
      .select { |step| ["Jeevika Jankar Bill", "VRP Bill"].any? { |name| dashboard_value_matches?(step.data["module_name"], name) } }
      .sort_by { |step| [approval_sequence_from_level(step.data["approval_level"]), step.created_at&.to_i || 0, step.id || 0] }
  end

  def ordered_approval_channel_steps(records)
    records
      .group_by { |step| approval_sequence_from_level(step.data["approval_level"]) }
      .values
      .map { |grouped_records| grouped_records.max_by { |step| approval_record_priority(step) } }
      .sort_by { |step| approval_sequence_from_level(step.data["approval_level"]) }
  end

  def approval_channel_key(step)
    [
      step.data["module_name"],
      step.data["stakeholder_name"],
      step.data["user_name"]
    ].map { |value| normalize_dashboard_text(value) }
  end

  def approval_channel_priority(records)
    first_record = records.first
    [
      approval_channel_specificity(first_record),
      records.size,
      records.filter_map(&:updated_at).map(&:to_i).max || 0,
      records.filter_map(&:id).max || 0
    ]
  end

  def approval_channel_specificity(record)
    [
      record&.data&.[]("user_name"),
      approval_record_office(record),
      record&.data&.[]("office_category")
    ].count(&:present?)
  end

  def jeevika_bill_approval_step_matches_bill?(step, record)
    identities = jeevika_bill_approval_identities(record)
    return false if identities.blank?

    identities.any? do |identity|
      dashboard_value_matches?(step.data["stakeholder_name"], identity[:stakeholder]) &&
        approval_identity_filters_match?(step, identity)
    end
  end

  def jeevika_bill_approval_identities(record)
    @jeevika_bill_approval_identities_cache ||= {}
    cache_key = record.id
    return @jeevika_bill_approval_identities_cache[cache_key] if @jeevika_bill_approval_identities_cache.key?(cache_key)

    identities = []
    vrp = jeevika_bill_vrp(record)
    identities.concat(vrp_creator_identities_for_dashboard(vrp)) if vrp
    identities << current_bill_creator_identity(record)
    @jeevika_bill_approval_identities_cache[cache_key] = identities.compact.uniq
  end

  def bill_submitter_user(label)
    return unless model_ready?(:User)

    @bill_submitter_users ||= User.all.to_a
    @bill_submitter_users.find do |user|
      dashboard_user_label_matches?(label, [user.full_name, user.user_name])
    end
  end

  def current_bill_creator_identity(record)
    data = record.data
    return if data["created_by_id"].blank? && data["created_by_username"].blank? && data["created_by_name"].blank?

    user = bill_creator_user(data)
    return user_dashboard_identity(user) if user

    legacy_record = bill_creator_module_record(data)
    return record_dashboard_identity(legacy_record) if legacy_record

    {
      role: nil,
      stakeholder: nil,
      stakeholder_role: nil,
      user_management_role: nil,
      person_type: nil,
      office: nil,
      office_category: nil,
      user_name: data["created_by_username"],
      user_names: [data["created_by_username"], data["created_by_name"]]
    }
  end

  def bill_creator_user(data)
    return unless model_ready?(:User)

    cached_user_find_by(id: data["created_by_id"]) ||
      cached_user_find_by(user_name: data["created_by_username"]) ||
      cached_user_find_by(email: data["created_by_email"])
  end

  def bill_creator_module_record(data)
    return unless model_ready?(:ModuleRecord)

    (data["created_by_id"].present? && new_user_module_records.find { |record| record.id.to_s == data["created_by_id"].to_s }) ||
      new_user_module_records.detect do |record|
        record.data["user_name"].to_s == data["created_by_username"].to_s ||
          record.data["email"].to_s.casecmp(data["created_by_email"].to_s).zero?
      end
  end

  def jeevika_bill_approval_history(record)
    return [] unless model_ready?(:ModuleRecord)

    jeevika_bill_approval_history_by_bill_id[record.id.to_s] || []
  end

  def jeevika_bill_approval_history_by_bill_id
    @jeevika_bill_approval_history_by_bill_id ||= begin
      scope = ModuleRecord
      .where(module_slug: "jeevika-jankar-bill-approval-history")
      .order(created_at: :asc)
      bill_ids = Array(@jeevika_bill_visible_record_ids).map(&:to_s).reject(&:blank?)
      scope = scope.where("data::jsonb ->> 'bill_id' IN (?)", bill_ids) if bill_ids.any?
      scope.group_by { |history| history.data["bill_id"].to_s }
    end
  end

  def jeevika_bill_current_approval_step(record)
    @jeevika_bill_current_approval_step_cache ||= {}
    cache_key = record.id
    return @jeevika_bill_current_approval_step_cache[cache_key] if @jeevika_bill_current_approval_step_cache.key?(cache_key)

    steps = jeevika_bill_approval_steps(record)
    @jeevika_bill_current_approval_step_cache[cache_key] = steps.find do |step|
      !jeevika_bill_approval_step_closed?(record, step)
    end
  end

  def jeevika_bill_approval_step_closed?(record, step)
    step_sequence = approval_sequence_from_level(step.data["approval_level"])
    step_approver = step.data["approver_approved_by"]

    jeevika_bill_approval_history(record).any? do |history|
      next false unless ["Approved", "Rejected"].include?(history.data["action"].to_s)

      approval_sequence_from_level(history.data["approval_level"]) == step_sequence ||
        dashboard_user_label_matches?(history.data["approver"], [step_approver])
    end
  end

  def jeevika_bill_approved_sequences(record)
    jeevika_bill_approval_history(record)
      .select { |history| history.data["action"].to_s == "Approved" }
      .map { |history| approval_sequence_from_level(history.data["approval_level"]) }
      .uniq
  end

  def jeevika_bill_current_approver?(record)
    step = jeevika_bill_current_approval_step(record)
    return false unless step

    current_labels = [
      current_app_user&.dig("username"),
      current_app_user&.dig("user_name"),
      current_app_user&.dig("name")
    ].compact_blank
    dashboard_user_label_matches?(step.data["approver_approved_by"], current_labels)
  end

  def update_bill_approval(action)
    load_module!
    record = ModuleRecord.find(params[:id])
    redirect_to module_path("jeevika-jankar-bill-list"), alert: "You are not allowed to update this bill." and return unless jeevika_jankar_bill_record_visible?(record)
    step = jeevika_bill_current_approval_step(record)
    redirect_to module_path("jeevika-jankar-bill-list", view_id: record.id), alert: "Approval channel not found." and return unless step
    redirect_to module_path("jeevika-jankar-bill-list", view_id: record.id), alert: "This bill is not pending for your approval." and return unless jeevika_bill_current_approver?(record)
    redirect_to module_path("jeevika-jankar-bill-list", view_id: record.id), alert: "Please enter remarks." and return if params[:remarks].to_s.strip.blank?

    if ["Rejected", "Returned"].include?(action)
      create_bill_approval_history(record, action, step)
      update_bill_status!(record, action, current_sequence: approval_sequence_from_level(step.data["approval_level"]))
      respond_bill_approval_success(record, "Bill #{action.downcase}.")
      return
    end

    create_bill_approval_history(record, action, step)
    next_step = jeevika_bill_approval_steps(record).find { |candidate| approval_sequence_from_level(candidate.data["approval_level"]) > approval_sequence_from_level(step.data["approval_level"]) }

    if next_step
      update_bill_status!(record, "Pending at #{next_step.data["approver_approved_by"]}", current_sequence: approval_sequence_from_level(next_step.data["approval_level"]))
    else
      update_bill_status!(record, "Final Approved", current_sequence: approval_sequence_from_level(step.data["approval_level"]))
    end

    respond_bill_approval_success(record, "Bill approved.")
  end

  def respond_bill_approval_success(record, message)
    respond_to do |format|
      format.html { redirect_to module_path("jeevika-jankar-bill-list", view_id: record.id), notice: message }
      format.json do
        render json: {
          ok: true,
          message: message,
          status: jeevika_bill_status_label(record),
          status_class: jeevika_bill_status_class(record)
        }
      end
    end
  end

  def update_bill_status!(record, status, current_sequence:)
    record.update!(data: record.data.merge("status" => status, "approval_current_sequence" => current_sequence.to_s))
  end

  def create_bill_approval_history(record, action, step)
    ModuleRecord.create!(
      module_slug: "jeevika-jankar-bill-approval-history",
      data: {
        "bill_id" => record.id.to_s,
        "action" => action,
        "approval_level" => step.data["approval_level"],
        "approver" => step.data["approver_approved_by"],
        "remarks" => params[:remarks].to_s,
        "action_by" => current_app_user&.dig("name").presence || current_app_user&.dig("username").to_s,
        "action_at" => Time.current.iso8601
      }
    )
    @jeevika_bill_approval_history_by_bill_id = nil
    @jeevika_bill_current_approval_step_cache&.delete(record.id)
  end

  def approved_vrp_id_options
    return [] unless model_ready?(:Vrp)

    scope = Vrp.where(status: 55)
    scope = scope.where(is_active: true) if Vrp.column_names.include?("is_active")
    scope = scope.where(id: current_vrp_record.id) if vrp_login_user? && current_vrp_record.present?
    scope = scope.where(id: module_cluster_visible_vrp_ids) if module_mapped_vrp_scope_active?

    vrps = scope.order(:name).to_a

    vrps.map do |vrp|
      label = vrp.name.presence || vrp.user_name.presence
      [label.presence || "VRP ##{vrp.id}", vrp.id.to_s]
    end
  end

  def module_cluster_incharge_login?
    return @module_cluster_incharge_login if defined?(@module_cluster_incharge_login)

    @module_cluster_incharge_login = compute_module_cluster_incharge_login
  end

  def compute_module_cluster_incharge_login
    return false if admin_dashboard_user? || vrp_login_user?

    roles = %w[role role_name stakeholder_role user_management_role person_type designation].filter_map do |key|
      current_app_user&.dig(key).presence
    end
    return true if roles.any? { |role| role.to_s.match?(/cluster|\bcc\b/i) }

    hierarchy_cluster_incharge_labels.any? do |mapped_label|
      current_cluster_incharge_labels.any? { |current_label| cluster_label_matches?(mapped_label, current_label) }
    end
  end

  def module_cluster_vrp_visible?(vrp)
    labels = current_cluster_incharge_labels.compact_blank.uniq
    return false if labels.blank?

    labels.any? { |label| cluster_label_matches?(label, vrp.cluster_incharge) }
  end

  def module_mapped_vrp_scope_active?
    return false if vrp_login_user?

    module_cluster_incharge_login? || module_cluster_visible_vrps.any?
  end

  def module_cluster_visible_vrp_ids
    module_cluster_visible_vrps.map(&:id)
  end

  def module_cluster_visible_vrps
    return [] unless model_ready?(:Vrp)
    return @module_cluster_visible_vrps if defined?(@module_cluster_visible_vrps)

    return @module_cluster_visible_vrps = [] if current_cluster_incharge_labels.blank?

    directly_mapped_vrps = Vrp
      .where.not(cluster_incharge: [nil, ""])
      .order(:name, :id)
      .select { |vrp| module_cluster_vrp_visible?(vrp) }

    visible_vrps = directly_mapped_vrps

    @module_cluster_visible_vrps = visible_vrps.uniq(&:id).sort_by do |vrp|
      [vrp.name.to_s, vrp.id]
    end
  end

  def current_cluster_incharge_labels
    return @current_cluster_incharge_labels if defined?(@current_cluster_incharge_labels)

    @current_cluster_incharge_labels = compute_current_cluster_incharge_labels
  end

  def compute_current_cluster_incharge_labels
    labels = [
      current_app_user&.dig("name"),
      current_app_user&.dig("username"),
      current_app_user&.dig("user_name")
    ]

    labels.concat(user_model_cluster_labels)
    labels.concat(legacy_user_cluster_labels)
    labels.compact_blank.uniq
  end

  def user_model_cluster_labels
    return [] unless model_ready?(:User)

    user = cached_user_find_by(user_name: current_app_user&.dig("username")) ||
      cached_user_find_by(id: current_app_user&.dig("id"))
    return [] unless user

    full_name = user.respond_to?(:full_name) ? user.full_name : nil
    user_name = user.respond_to?(:user_name) ? user.user_name : nil
    [full_name, user_name]
  end

  def legacy_user_cluster_labels
    return [] unless model_ready?(:ModuleRecord)

    username = current_app_user&.dig("username").to_s
    return [] if username.blank?

    record = legacy_user_record_by_username(username)
    return [] unless record

    full_name = [record.data["first_name"], record.data["last_name"]].compact_blank.join(" ").presence
    [full_name, record.data["user_name"], record.data["name"]]
  end

  def cluster_label_matches?(expected, actual)
    expected_values = cluster_label_match_values(expected)
    actual_values = cluster_label_match_values(actual)
    return false if expected_values.blank? || actual_values.blank?
    return true if (expected_values & actual_values).any?

    expected_values.any? do |expected_value|
      actual_values.any? { |actual_value| similar_person_label?(expected_value, actual_value) }
    end
  end

  def cluster_label_match_values(label)
    base = label.to_s.sub(/\s*\([^)]*\)\s*\z/, "")
    [label, base].map { |value| normalize_dashboard_user_label(value) }.reject { |value| value.blank? || value.length < 3 }.uniq
  end

  def similar_person_label?(left, right)
    left_words = left.split
    right_words = right.split
    return false unless left_words.size == right_words.size
    return false if left_words.size < 2
    return false unless left_words.last == right_words.last

    left_words.zip(right_words).all? { |left_word, right_word| left_word == right_word || one_edit_apart?(left_word, right_word) }
  end

  def one_edit_apart?(left, right)
    return false if left.blank? || right.blank?
    return false if (left.length - right.length).abs > 1

    longer, shorter = [left, right].sort_by(&:length).reverse
    edits = 0
    longer_index = 0
    shorter_index = 0

    while longer_index < longer.length && shorter_index < shorter.length
      if longer[longer_index] == shorter[shorter_index]
        longer_index += 1
        shorter_index += 1
      else
        edits += 1
        return false if edits > 1

        longer_index += 1
        shorter_index += 1 if longer.length == shorter.length
      end
    end

    edits + (longer.length - longer_index) <= 1
  end

  def generated_jeevika_jankar_invoice_no
    "JJB-#{Time.current.strftime("%Y%m%d%H%M")}"
  end

  def jeevika_jankar_achievement_summary(rows)
    Array(rows).each_with_object({}) do |row, summary|
      vrp_id = row[:vrp_id].to_s
      month_key = normalize_dashboard_text(row[:month_name])
      next if vrp_id.blank?

      summary[vrp_id] ||= {}
      summary[vrp_id]["__all"] = summary[vrp_id].fetch("__all", 0) + row[:achievement_count].to_i
      summary[vrp_id][month_key] = summary[vrp_id].fetch(month_key, 0) + row[:achievement_count].to_i if month_key.present?
    end
  end

  def jeevika_jankar_dashboard_target_summary
    return {} unless model_ready?(:TargetMapping)

    targets = TargetMapping.includes(:vrp)
    targets = targets.where(vrp_id: current_vrp_record.id) if vrp_login_user? && current_vrp_record.present?
    targets = targets.where(vrp_id: module_cluster_visible_vrp_ids) if module_mapped_vrp_scope_active?
    rows = vrp_dashboard_target_progress_rows(targets.to_a, [])

    rows.each_with_object({}) do |row, summary|
      vrp_id = row[:target_record]&.vrp_id.to_s
      month_key = normalize_dashboard_text(row[:month])
      next if vrp_id.blank? || month_key.blank?

      summary[vrp_id] ||= {}
      summary[vrp_id][month_key] ||= { target: 0.0, achievement: 0.0, pending: 0.0 }
      summary[vrp_id][month_key][:target] += row[:target].to_f
      summary[vrp_id][month_key][:achievement] += row[:completed].to_f
      summary[vrp_id][month_key][:pending] += row[:pending].to_f
    end.transform_values do |months|
      months.transform_values do |totals|
        assigned = totals[:target].to_f
        achieved = [totals[:achievement].to_f, assigned].min
        {
          target: dashboard_quantity(assigned),
          achievement: dashboard_quantity(achieved),
          pending: dashboard_quantity([assigned - achieved, 0].max)
        }
      end
    end
  end

  def jeevika_jankar_target_summary_from_rows(rows)
    grouped_rows = Array(rows).group_by { |row| row[:target_mapping_id].to_s.presence || row[:training_session_key].to_s }

    grouped_rows.values.each_with_object({}) do |target_rows, summary|
      row = target_rows.first
      vrp_id = row[:vrp_id].to_s
      month_key = normalize_dashboard_text(row[:month_name])
      next if vrp_id.blank? || month_key.blank?

      target = target_rows.map { |item| bill_row_target_total(item) }.max.to_f
      achievement = [target_rows.sum { |item| item[:achievement_count].to_f }, target].min
      summary[vrp_id] ||= {}
      summary[vrp_id][month_key] ||= { target: 0.0, achievement: 0.0 }
      summary[vrp_id][month_key][:target] += target
      summary[vrp_id][month_key][:achievement] += achievement
    end.transform_values do |months|
      months.transform_values do |totals|
        assigned = totals[:target].to_f
        achieved = [totals[:achievement].to_f, assigned].min
        {
          target: dashboard_quantity(assigned),
          achievement: dashboard_quantity(achieved),
          pending: dashboard_quantity([assigned - achieved, 0].max)
        }
      end
    end
  end

  def bill_row_target_total(row)
    if normalize_dashboard_text(row[:main_activity_type]) == "other"
      row[:target_quantity].to_f
    else
      assigned = row[:assigned_count].to_f
      assigned.positive? ? assigned : row[:target_quantity].to_f
    end
  end

  def jeevika_jankar_saved_items
    raw_items = @record&.data&.[]("bill_items")
    raw_items = raw_items.values if raw_items.is_a?(Hash)
    Array(raw_items).select { |item| item.respond_to?(:[]) }
  end

  def jeevika_jankar_existing_bill_keys
    return [] unless model_ready?(:ModuleRecord)

    ModuleRecord
      .where(module_slug: "jeevika-jankar-bill-process")
      .order(created_at: :desc)
      .select { |record| jeevika_jankar_bill_blocks_duplicate?(record) }
      .map do |record|
        {
          id: record.id.to_s,
          vrp_id: record.data["select_vrp"].to_s,
          month: record.data["bill_month"].to_s
        }
      end
      .reject { |item| item[:vrp_id].blank? || item[:month].blank? }
  end

  def jeevika_jankar_bill_blocks_duplicate?(record)
    return false if record.id.to_s == params[:id].to_s
    return false if truthy_module_flag?(record.data["deleted"]) ||
      truthy_module_flag?(record.data["is_deleted"]) ||
      truthy_module_flag?(record.data["discarded"])

    record.data["record_state"].to_s.casecmp("Inactive") != 0
  end

  def approved_other_target_achievement_index
    return {} unless model_ready?(:ModuleRecord)

    records = ModuleRecord.where(module_slug: OTHER_TARGET_MODULE_SLUGS)
    candidate_months = other_target_candidate_targets.map { |target| normalize_dashboard_text(target.month_name) }.reject(&:blank?).uniq
    records = records.where("LOWER(BTRIM(data::jsonb ->> 'month')) IN (?)", candidate_months) if candidate_months.present?

    records
      .order(updated_at: :desc)
      .select { |record| approved_other_target_record?(record) }
      .each_with_object({}) do |record, index|
        target_mapping_ids = other_target_record_target_mapping_ids(record)
        next if target_mapping_ids.blank?

        achievement = decimal_value(record.data["achievement"])
        next if achievement.nil?

        target_mapping_ids.each do |target_mapping_id|
          entry = index[target_mapping_id] ||= {
            achievement: 0.0,
            source_modules: [],
            source_record_ids: [],
            achieved_dates: []
          }
          entry[:achievement] += achievement.to_f
          entry[:source_modules] |= [record.module_slug]
          entry[:source_record_ids] |= [record.id.to_s]
          entry[:achieved_dates] |= [(parse_module_date(record.data["achievement_date"]) || record.updated_at.to_date).to_s]
        end
      end.transform_values do |entry|
        {
          achievement: entry[:achievement],
          source_module: entry[:source_modules].join(", "),
          source_record_id: entry[:source_record_ids].join(", "),
          achieved_at: entry[:achieved_dates].join(", ")
        }
      end
  end

  def other_target_record_target_mapping_ids(record)
    saved_id = record.data["target_mapping_id"].to_s.strip
    target_by_id = other_target_candidate_targets_by_id
    direct_ids = saved_id.present? && (target_by_id.blank? || target_by_id.key?(saved_id)) ? [saved_id] : []
    return direct_ids if direct_ids.present? && !model_ready?(:TargetMapping)
    return [] unless model_ready?(:TargetMapping)

    data = record.data || {}
    selected_vrp = normalize_dashboard_text(data["jeevika_jankar_id"].presence || data["jeevika_jankar_name"].presence || data["select_vrp"])
    selected_month = normalize_dashboard_text(data["month"])
    selected_ics = normalize_dashboard_text(data["ics"])
    selected_village = normalize_dashboard_text(data["village"])
    selected_topic = normalize_dashboard_text(data["training_topic"].presence || data["main_activity"])
    selected_subject = normalize_dashboard_text(data["training_subject"].presence || data["sub_activity"])
    return direct_ids if [selected_vrp, selected_month, selected_ics, selected_village, selected_topic, selected_subject].any?(&:blank?)

    matched_ids = other_target_candidates_for_match(selected_vrp, selected_month).select do |target|
      other_target_record_matches_target?(target, selected_vrp, selected_month, selected_ics, selected_village, selected_topic, selected_subject)
    end.map { |target| target.id.to_s }

    (direct_ids + matched_ids).uniq
  end

  def other_target_candidates_for_match(selected_vrp, selected_month)
    targets = other_target_candidate_targets
    unless @other_target_match_source.equal?(targets)
      @other_target_match_source = targets
      @other_target_match_index = Hash.new { |hash, key| hash[key] = [] }
      targets.each do |target|
        month = normalize_dashboard_text(target.month_name)
        [target.vrp_id, target.vrp&.name, target.vrp&.user_name]
          .map { |value| normalize_dashboard_text(value) }.reject(&:blank?).uniq.each do |identity|
          @other_target_match_index[[identity, month]] << target
        end
      end
    end
    @other_target_match_index.fetch([selected_vrp, selected_month], [])
  end

  def other_target_candidate_targets
    @other_target_candidate_targets ||= begin
      targets = if defined?(@filtered_targets) && @filtered_targets.present?
        @filtered_targets
      elsif defined?(@vrp_target_rows) && @vrp_target_rows.present?
        @vrp_target_rows.filter_map { |row| row[:target_record] }
      elsif defined?(@jeevika_jankar_bill_rows) && @jeevika_jankar_bill_rows.present?
        ids = @jeevika_jankar_bill_rows.flat_map { |row| Array(row[:target_mapping_ids].presence || row[:target_mapping_id]) }.map(&:to_s).reject(&:blank?).uniq
        ids.present? && model_ready?(:TargetMapping) ? TargetMapping.includes(:vrp).where(id: ids).to_a : []
      elsif model_ready?(:TargetMapping)
        TargetMapping.includes(:vrp).to_a
      else
        []
      end

      Array(targets).compact.uniq { |target| target.id.to_s }
    end
  end

  def other_target_candidate_targets_by_id
    @other_target_candidate_targets_by_id ||= other_target_candidate_targets.index_by { |target| target.id.to_s }
  end

  def other_target_record_matches_target?(target, selected_vrp, selected_month, selected_ics, selected_village, selected_topic, selected_subject)
    vrp_values = [
      target.vrp_id,
      target.vrp&.name,
      target.vrp&.user_name
    ].map { |value| normalize_dashboard_text(value) }.reject(&:blank?)

    vrp_values.include?(selected_vrp) &&
      normalize_dashboard_text(target.month_name) == selected_month &&
      [target.ics_id, target.ics_name].map { |value| normalize_dashboard_text(value) }.reject(&:blank?).include?(selected_ics) &&
      [target.village_id, target.village_name].map { |value| normalize_dashboard_text(value) }.reject(&:blank?).include?(selected_village) &&
      dashboard_training_activity_text_matches?(selected_topic, target.main_activity_name) &&
      dashboard_training_activity_text_matches?(selected_subject, target.activity_name)
  end

  def approved_other_target_record?(record)
    return false if truthy_module_flag?(record.data["deleted"]) ||
      truthy_module_flag?(record.data["is_deleted"]) ||
      truthy_module_flag?(record.data["discarded"])

    status = record.data["approval_status"].presence || record.data["approval_state"].presence || record.data["status"].presence
    return true if status.blank?

    normalized_status = normalize_dashboard_text(status)
    return false if normalized_status.include?("reject") ||
      normalized_status.include?("return") ||
      normalized_status.include?("pending") ||
      normalized_status == "inactive"

    normalized_status == "active" || normalized_status.include?("approved")
  end

  def jeevika_jankar_bill_rows(vrp_id: nil, month_name: nil, totals_only: false)
    return [] unless model_ready?(:TargetMapping)

    selected_vrp_ids = jeevika_jankar_bill_selected_vrp_ids(vrp_id)
    targets = TargetMapping.includes(:vrp)
    targets = targets.where(vrp_id: current_vrp_record.id) if vrp_login_user? && current_vrp_record.present?
    targets = targets.where(vrp_id: module_cluster_visible_vrp_ids) if module_mapped_vrp_scope_active?
    targets = targets.where(vrp_id: selected_vrp_ids) if selected_vrp_ids.present?
    targets = targets.none if vrp_id.present? && selected_vrp_ids.blank?
    targets = targets.where("LOWER(BTRIM(month_name)) = ?", month_name.to_s.strip.downcase) if month_name.present?
    if vrp_id.present? && targets.none?
      targets = TargetMapping.includes(:vrp)
      targets = selected_vrp_ids.present? ? targets.where(vrp_id: selected_vrp_ids) : targets.none
      targets = targets.where("LOWER(BTRIM(month_name)) = ?", month_name.to_s.strip.downcase) if month_name.present?
    end
    if month_name.present? && targets.none? && selected_vrp_ids.present?
      month_numbers = month_number_candidates(month_name)
      targets = TargetMapping.includes(:vrp).where(vrp_id: selected_vrp_ids)
      if month_numbers.any?
        target_ids = targets.select { |target| month_numbers.include?(month_number_value(target.month_name)) }.map(&:id)
        targets = TargetMapping.includes(:vrp).where(id: target_ids)
      end
    end
    targets = targets.order(:month_name, :vrp_id, :village_name, :main_activity_name, :activity_name, :id).to_a
    @other_target_candidate_targets = targets
    @other_target_candidate_targets_by_id = targets.index_by { |target| target.id.to_s }
    if totals_only
      # Bill lists need the same assignment totals, but not farmer profiles,
      # training evidence or per-farmer display hashes for the Bill Process form.
      rows = vrp_dashboard_target_progress_rows(targets, []).map do |progress|
        target = progress[:target_record]
        {
          target_mapping_id: progress[:target_mapping_id],
          vrp_id: target.vrp_id.to_s,
          month_name: progress[:month],
          target_quantity: progress[:target],
          assigned_count: progress[:target],
          achievement_count: progress[:completed]
        }
      end
      @jeevika_jankar_target_summary = jeevika_jankar_target_summary_from_rows(rows)
      return rows
    end

    farmers_by_id = jeevika_jankar_farmers_by_id(targets)
    training_index = if @bill_list_batch_totals
      targets.group_by(&:vrp_id).each_value.each_with_object({}) do |vrp_targets, index|
        index.merge!(jeevika_jankar_training_index(vrp_targets))
      end
    else
      jeevika_jankar_training_index(targets)
    end
    activity_settings = jeevika_jankar_main_activity_settings
    sub_activity_settings = jeevika_jankar_sub_activity_settings(activity_settings)
    other_target_achievement_index = approved_other_target_achievement_index

    # Use the dashboard's assignment grouping and completion calculation for both
    # the bill totals and its detail rows. Training sessions are evidence, not targets.
    rows = vrp_dashboard_target_progress_rows(targets, []).map do |progress|
      target = progress[:target_record]
      activity_setting = jeevika_jankar_activity_setting_for(target, activity_settings, sub_activity_settings)
      main_activity_type = activity_setting&.dig(:main_activity_type).presence || "Training"
      completed_ids = Array(progress[:completed_farmer_ids]).map(&:to_s).to_set
      farmer_rows = Array(progress[:assigned_farmer_ids]).map do |farmer_id|
        farmer = farmers_by_id[farmer_id.to_s]
        training_rows = Array(training_index[[target.vrp_id.to_s, target.month_name.to_s, farmer_id.to_s]])
        training = best_training_for_target(target, training_rows)
        {
          id: farmer_id.to_s,
          name: farmer&.farmer_name.presence || "Farmer ##{farmer_id}",
          father_name: farmer&.father_name,
          mobile_no: farmer&.mobile_no,
          tracenet_no: farmer&.tracenet_no,
          department: training&.dig(:department),
          training_topic: training&.dig(:training_topic),
          training_subject: training&.dig(:training_subject),
          training_date: training&.dig(:training_date),
          status: completed_ids.include?(farmer_id.to_s) ? "Completed in Target" : "Pending"
        }
      end
      other_achievement = other_target_achievement_index[target.id.to_s]
      {
        target_mapping_id: progress[:target_mapping_id],
        target_mapping_ids: progress[:target_mapping_ids],
        vrp_id: target.vrp_id.to_s,
        vrp_name: target.vrp&.name.presence || "VRP ##{target.vrp_id}",
        month_name: progress[:month],
        fco: progress[:fco],
        ics: progress[:ics],
        village: progress[:village],
        main_activity: progress[:main_activity],
        main_activity_type: main_activity_type,
        activity: progress[:activity],
        target_quantity: progress[:target],
        assigned_count: progress[:target],
        achievement_count: progress[:completed],
        achievement_entry_mode: "Auto Fill",
        same_activity_count: completed_ids.size,
        other_activity_count: progress[:completed],
        pending_count: progress[:pending],
        timesheet_dates: other_achievement&.dig(:achieved_at).presence || farmer_rows.filter_map { |row| row[:training_date].presence if row[:status] != "Pending" }.uniq.join(", "),
        farmer_details: farmer_rows
      }
    end

    @jeevika_jankar_target_summary = jeevika_jankar_target_summary_from_rows(rows)
    rows
  end

  def jeevika_jankar_bill_selected_vrp_ids(value)
    raw_value = value.to_s.strip
    return [] if raw_value.blank?

    direct_ids = raw_value.split(",").map(&:strip).select { |item| item.match?(/\A\d+\z/) }
    return direct_ids.uniq if direct_ids.any?
    return [] unless model_ready?(:Vrp)

    normalized_value = normalize_dashboard_text(raw_value)
    Vrp.unscoped
      .where(
        "LOWER(BTRIM(name)) = :value OR LOWER(BTRIM(user_name)) = :value",
        value: normalized_value
      )
      .pluck(:id)
      .map(&:to_s)
      .uniq
  end

  def month_number_candidates(value)
    month_number = month_number_value(value)
    month_number ? [month_number] : []
  end

  def month_number_value(value)
    text = value.to_s.strip
    return nil if text.blank?

    Date::MONTHNAMES.each_with_index do |name, index|
      next if index.zero?

      normalized_name = normalize_dashboard_text(name)
      normalized_abbr = normalize_dashboard_text(name[0, 3])
      normalized_text = normalize_dashboard_text(text)
      return index if [normalized_name, normalized_abbr, index.to_s, format("%02d", index)].include?(normalized_text)
    end

    nil
  end

  def group_jeevika_jankar_training_bill_rows(rows)
    Array(rows).group_by do |row|
      farmer_ids = Array(row[:farmer_details]).map { |farmer| farmer[:id].to_s }.reject(&:blank?).uniq.sort
      if farmer_ids.any?
        [
          "farmers",
          row[:vrp_id].to_s,
          normalize_dashboard_text(row[:month_name]),
          normalize_dashboard_text(row[:ics]),
          normalize_dashboard_text(row[:village]),
          farmer_ids
        ]
      else
        ["target", row[:target_mapping_id].to_s]
      end
    end.values.flat_map do |group|
      if group.one?
        sessions = jeevika_jankar_bill_training_sessions(group, group.first)
        next sessions.presence || [group.first]
      end

      primary = group.first
      main_activities = group.map { |row| row[:main_activity].to_s.strip }.reject(&:blank?).uniq
      activities = group.map { |row| row[:activity].to_s.strip }.reject(&:blank?).uniq
      farmer_groups = group.flat_map { |row| Array(row[:farmer_details]) }.group_by { |farmer| farmer[:id].to_s }
      farmers = farmer_groups.values.map do |entries|
        entries.min_by do |farmer|
          { "Trained in Same Activity" => 0, "Completed in Target" => 1, "Trained in Other Activity" => 2, "Pending" => 3 }.fetch(farmer[:status], 4)
        end
      end
      trained = farmers.reject { |farmer| farmer[:status] == "Pending" }
      same_count = farmers.count { |farmer| farmer[:status] == "Trained in Same Activity" }
      other_count = farmers.count { |farmer| farmer[:status] == "Trained in Other Activity" || farmer[:status] == "Completed in Target" }
      assigned_count = farmers.size
      achievement_count = [group.map { |row| row[:achievement_count].to_f }.max.to_f, trained.size.to_f].max
      achievement_count = [achievement_count, assigned_count].min if assigned_count.positive?

      combined = primary.merge(
        target_mapping_ids: group.map { |row| row[:target_mapping_id].to_s }.reject(&:blank?).uniq,
        main_activity: main_activities.join(" • "),
        main_activity_type: group.any? { |row| training_main_activity_type?(row[:main_activity_type]) } ? "Training" : primary[:main_activity_type],
        achievement_entry_mode: group.any? { |row| training_main_activity_type?(row[:main_activity_type]) } ? "Auto Fill" : primary[:achievement_entry_mode],
        activity: activities.join(" • "),
        target_quantity: assigned_count.positive? ? assigned_count : group.map { |row| row[:target_quantity].to_f }.max,
        assigned_count: assigned_count,
        achievement_count: achievement_count,
        same_activity_count: same_count,
        other_activity_count: other_count,
        pending_count: [assigned_count - achievement_count, 0].max,
        timesheet_dates: group.flat_map { |row| row[:timesheet_dates].to_s.split(",") }.map(&:strip).reject(&:blank?).uniq.join(", "),
        farmer_details: farmers
      )

      sessions = jeevika_jankar_bill_training_sessions(group, combined)
      sessions.presence || [combined]
    end
  end

  def jeevika_jankar_bill_training_sessions(group, combined_row)
    farmer_ids = Array(combined_row[:farmer_details]).map { |farmer| farmer[:id].to_s }.reject(&:blank?).uniq
    return [] if farmer_ids.blank?

    vrp_id = combined_row[:vrp_id].presence || group.first[:vrp_id]
    vrp = cached_vrp_lookup(vrp_id)
    return [] if vrp.blank?

    records = dashboard_training_completion_records.select do |record|
      training_record_matches_month?(record, combined_row[:month_name]) &&
        training_record_matches_vrp?(record, vrp) &&
        (training_record_selected_farmer_ids(record) & farmer_ids).any?
    end
    return [] if records.blank?

    records.group_by do |record|
      data = record.data
      selected_ids = training_record_selected_farmer_ids(record).sort
      [
        training_summary(record)[:training_date].to_s,
        normalize_dashboard_text(data["training_location"]),
        normalize_dashboard_text(data["training_method"]),
        selected_ids
      ]
    end.values.map do |session_records|
      session_ids = session_records.flat_map { |record| training_record_selected_farmer_ids(record) }.uniq & farmer_ids
      session_main_activities = session_records.flat_map do |record|
        Array(record.data["main_activities"].presence || record.data["main_activity"].presence || record.data["training_topic"])
      end.map(&:to_s).map(&:strip).reject(&:blank?).uniq
      session_sub_activities = session_records.flat_map do |record|
        raw = record.data["sub_activities"].presence || record.data["sub_activity"].presence || record.data["training_subject"]
        raw.is_a?(Array) ? raw : raw.to_s.split(/,\s*(?=\d+\.\s*)/)
      end.map(&:to_s).map(&:strip).reject(&:blank?).uniq
      primary_record = session_records.max_by { |record| [record.created_at || Time.at(0), record.id.to_i] }
      summary = training_summary(primary_record)
      session_key = [
        vrp_id,
        normalize_dashboard_text(combined_row[:month_name]),
        summary[:training_date].to_s,
        normalize_dashboard_text(primary_record.data["training_location"]),
        normalize_dashboard_text(primary_record.data["training_method"]),
        session_ids.sort.join("-")
      ].join("|")
      farmers = Array(combined_row[:farmer_details]).select { |farmer| session_ids.include?(farmer[:id].to_s) }.map do |farmer|
        farmer.merge(
          training_topic: session_main_activities.join(", "),
          training_subject: session_sub_activities.join(", "),
          training_date: summary[:training_date],
          status: "Trained in Same Activity"
        )
      end

      combined_row.merge(
        main_activity: session_main_activities.presence&.join(" • ") || combined_row[:main_activity],
        activity: session_sub_activities.presence&.join(" • ") || combined_row[:activity],
        target_quantity: session_ids.size,
        assigned_count: session_ids.size,
        achievement_count: session_ids.size,
        same_activity_count: session_ids.size,
        other_activity_count: 0,
        pending_count: 0,
        timesheet_dates: summary[:training_date].to_s,
        farmer_details: farmers,
        training_session_key: session_key
      )
    end
  end

  def jeevika_jankar_main_activity_settings
    return @jeevika_jankar_main_activity_settings if defined?(@jeevika_jankar_main_activity_settings)
    return @jeevika_jankar_main_activity_settings = {} unless model_ready?(:ModuleRecord)

    @jeevika_jankar_main_activity_settings = active_module_records_scope("add-activity-group")
      .order(created_at: :desc)
      .each_with_object({}) do |record, settings|
        name = normalize_dashboard_text(record.data["main_activity_name"].presence || record.data["activity_group_name"])
        next if name.blank? || settings.key?(name)

        settings[name] = {
          main_activity_name: record.data["main_activity_name"].presence || record.data["activity_group_name"],
          main_activity_type: record.data["main_activity_type"].presence || "Training",
          achievement_entry_mode: record.data["achievement_fill"].presence || record.data["achievement_entry_mode"].presence || "Auto Fill"
        }
      end
  end

  def training_setup_sub_activities_by_main
    return @training_setup_sub_activities_by_main if defined?(@training_setup_sub_activities_by_main)
    return @training_setup_sub_activities_by_main = {} unless model_ready?(:ModuleRecord)

    @training_setup_sub_activities_by_main = active_module_records_scope("add-vrp-activity")
      .order(created_at: :desc)
      .each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |record, result|
        main_activity = first_present_data(record, "main_activity", "activity_group", "activity_group_name", "group_name").to_s.strip
        sub_activity = first_present_data(record, "sub_activity_name", "activity_name", "vrp_activity_name", "activity").to_s.strip
        next if main_activity.blank? || sub_activity.blank?

        result[normalize_dashboard_text(main_activity)] |= [sub_activity]
      end
  end

  def jeevika_jankar_sub_activity_settings(activity_settings)
    return @jeevika_jankar_sub_activity_settings if defined?(@jeevika_jankar_sub_activity_settings)
    return @jeevika_jankar_sub_activity_settings = {} unless model_ready?(:ModuleRecord)

    @jeevika_jankar_sub_activity_settings = active_module_records_scope("add-vrp-activity")
      .order(created_at: :desc)
      .each_with_object({}) do |record, settings|
        main_activity_key = normalize_dashboard_text(first_present_data(record, "main_activity", "activity_group", "activity_group_name", "group_name"))
        sub_activity_key = normalize_dashboard_text(first_present_data(record, "sub_activity_name", "activity_name", "vrp_activity_name", "activity"))
        next if main_activity_key.blank? || sub_activity_key.blank? || settings.key?(sub_activity_key)

        main_setting = activity_settings[main_activity_key]
        settings[sub_activity_key] = main_setting if main_setting.present?
      end
  end

  def jeevika_jankar_activity_setting_for(target, activity_settings, sub_activity_settings)
    main_key = normalize_dashboard_text(target.main_activity_name)
    sub_key = normalize_dashboard_text(target.activity_name)

    activity_settings[main_key] ||
      activity_settings[sub_key] ||
      sub_activity_settings[sub_key] ||
      sub_activity_settings[main_key]
  end

  def jeevika_jankar_farmers_by_id(targets)
    return {} unless model_ready?(:Afl)

    farmer_ids = targets.flat_map { |target| Array(target.afl_ids).map(&:to_s) }.reject(&:blank?).uniq
    return {} if farmer_ids.blank?

    Afl.where(id: farmer_ids).index_by { |farmer| farmer.id.to_s }
  end

  def jeevika_jankar_training_index(targets)
    return {} unless model_ready?(:ModuleRecord)

    vrps = targets.map(&:vrp).compact.uniq(&:id)
    target_farmer_ids = targets.flat_map { |target| Array(target.afl_ids).map(&:to_s) }.reject(&:blank?).uniq
    target_farmer_ids_by_vrp = targets.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |target, result|
      result[target.vrp_id.to_s] |= Array(target.afl_ids).map(&:to_s).reject(&:blank?)
    end
    target_months = targets.map { |target| target.month_name.to_s }.reject(&:blank?).uniq
    records = active_module_records_scope("training-form").order(created_at: :desc)
    if target_months.present?
      normalized_months = target_months.map { |month| normalize_dashboard_text(month) }.uniq
      records = records.where("LOWER(BTRIM(data::jsonb ->> 'month')) IN (?)", normalized_months)
    end
    if @bill_list_batch_totals
      @bill_list_training_records_by_month ||= {}
      records = @bill_list_training_records_by_month[target_months.sort] ||= records.to_a
    end
    records.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |record, index|
      next unless training_record_countable?(record)

      farmer_ids = Array(record.data["selected_farmer_ids"]).map(&:to_s).reject(&:blank?) & target_farmer_ids
      next if farmer_ids.blank?

      matching_vrps = vrps.select { |vrp| training_record_matches_vrp?(record, vrp) }
      if matching_vrps.blank?
        matching_vrps = vrps.select { |vrp| (target_farmer_ids_by_vrp[vrp.id.to_s] & farmer_ids).any? }
      end
      next if matching_vrps.blank?

      target_months.each do |month_name|
        next unless training_record_matches_month?(record, month_name)

        matching_vrps.each do |vrp|
          vrp_farmer_ids = farmer_ids & target_farmer_ids_by_vrp[vrp.id.to_s]
          vrp_farmer_ids.each do |farmer_id|
            index[[vrp.id.to_s, month_name.to_s, farmer_id]] << training_summary(record)
          end
        end
      end
    end
  end

  def training_record_matches_vrp?(record, vrp)
    values = [
      record.data["jeevika_jankar_id"],
      record.data["vrp_id"],
      record.data["trainer_contact"],
      record.data["trainer_name"],
      record.data["jeevika_jankar_name"],
      record.data["select_vrp"],
      record.data["vrp_name"]
    ].map { |value| normalize_dashboard_text(value) }.reject(&:blank?)

    labels = [
      vrp.id,
      vrp.name,
      vrp.mobile_no,
      vrp.user_name,
      [vrp.name, vrp.mobile_no.presence].compact_blank.join(" - ")
    ].map { |value| normalize_dashboard_text(value) }.reject(&:blank?)

    (values & labels).any?
  end

  def training_record_matches_month?(record, month_name)
    return true if month_name.blank?

    record_month = record.data["month"].presence
    return normalize_dashboard_text(record_month) == normalize_dashboard_text(month_name) if record_month.present?

    training_date = parse_module_date(record.data["training_date"])
    return true if training_date.blank?

    normalize_dashboard_text(training_date.strftime("%B")) == normalize_dashboard_text(month_name)
  end

  def parse_module_date(value)
    Date.parse(value.to_s)
  rescue ArgumentError
    nil
  end

  def training_summary(record)
    @training_summary_cache ||= {}
    @training_summary_cache[record.id] ||= {
      department: record.data["department"].presence || record.data["trainee_department"],
      month: record.data["month"].presence || parse_module_date(record.data["training_date"])&.strftime("%B"),
      training_topics: Array(record.data["main_activities"].presence || record.data["main_activity"].presence || record.data["training_topic"]).map(&:to_s).map(&:strip).reject(&:blank?),
      training_topic: Array(record.data["main_activities"].presence || record.data["main_activity"].presence || record.data["training_topic"]).map(&:to_s).map(&:strip).reject(&:blank?).join(", "),
      training_subject: training_activity_values(record.data["sub_activities"].presence || record.data["sub_activity"].presence || record.data["training_subject"], normalize: false).join(", "),
      training_date: record.data["training_date"]
    }
  end

  def training_record_month_name(record)
    training_summary(record)[:month]
  end

  def training_activity_values(value, normalize: true)
    values = if value.is_a?(Array)
      value
    else
      value.to_s.split(/,\s*(?=\d+\.\s*)|(?<=\))\s+(?=\d+\.\s*)/)
    end
    values = values.map(&:to_s).map(&:strip).reject(&:blank?).uniq
    normalize ? values.map { |item| normalize_dashboard_text(item) } : values
  end

  def best_training_for_target(target, training_rows)
    Array(training_rows).find { |row| training_matches_target_activity?(target, row) } || Array(training_rows).first
  end

  def training_matches_target_activity?(target, training_row)
    return false if training_row.blank?

    topic_matches = Array(training_row[:training_topics].presence || training_row[:training_topic])
      .map { |topic| normalize_dashboard_text(topic) }
      .any? { |topic| dashboard_training_activity_text_matches?(topic, normalize_dashboard_text(target.main_activity_name)) }
    subject_matches = dashboard_training_activity_text_matches?(training_row[:training_subject], normalize_dashboard_text(target.activity_name))
    topic_matches && subject_matches
  end

  def approved_vrp_options
    return [] unless model_ready?(:Vrp)

    scope = Vrp.where(status: 55)
    scope = scope.where(is_active: true) if Vrp.column_names.include?("is_active")

    scope.order(:name).map do |vrp|
      label = [vrp.name, vrp.mobile_no.presence].compact_blank.join(" - ")
      [label.presence || "VRP ##{vrp.id}", label.presence || vrp.id.to_s]
    end
  end

  def active_month_master_rows
    return @active_month_master_rows if defined?(@active_month_master_rows)
    return @active_month_master_rows = [] unless model_ready?(:ModuleRecord)

    @active_month_master_rows = ModuleRecord
      .where(module_slug: "month-master")
      .merge(active_module_records_scope_for_all_modules)
      .order(created_at: :desc)
  end

  def month_master_month_options(records = active_month_master_rows)
    Array(records)
      .filter_map { |record| first_present_data(record, "month_name", "month", "name", "select_bill_month") }
      .map(&:to_s)
      .map(&:strip)
      .reject(&:blank?)
      .uniq
      .sort_by { |month| [dashboard_month_index(month), month] }
  end

  def month_master_financial_year_options(records = active_month_master_rows)
    Array(records)
      .filter_map { |record| first_present_data(record, "financial_year", "year", "fy") }
      .map(&:to_s)
      .map(&:strip)
      .reject(&:blank?)
      .uniq
      .sort
  end

  def bill_activity_map
    return {} unless model_ready?(:ModuleRecord)

    ModuleRecord
      .where(module_slug: "add-vrp-activity")
      .select { |record| active_module_record?(record) }
      .group_by { |record| first_present_data(record, "main_activity", "activity_group", "activity_group_name", "group_name").to_s }
      .transform_values do |records|
        records.map do |record|
          {
            activity: first_present_data(record, "sub_activity_name", "activity_name", "vrp_activity_name", "activity").to_s,
            unit: record.data["unit"].to_s
          }
        end.reject { |row| row[:activity].blank? }
      end
  end

  def bill_tci_map
    return {} unless model_ready?(:ModuleRecord)

    grouped = ModuleRecord
      .where(module_slug: "task-completion-indicator")
      .select { |record| active_module_record?(record) }
      .group_by { |record| first_present_data(record, "select_activity", "activity", "activity_name").to_s }
      .transform_values do |records|
        records.map do |record|
          {
            indicator: first_present_data(record, "tci_name", "task_completion_indicator", "indicator").to_s,
            mandatory: first_present_data(record, "select_mandatory", "mandatory").presence || "No"
          }
        end.reject { |row| row[:indicator].blank? }
      end

    grouped.merge("__all" => grouped.values.flatten.uniq { |row| row[:indicator] })
  end

  def module_record_values(module_slug, *keys)
    return [] unless model_ready?(:ModuleRecord)

    @module_record_values_cache ||= {}
    cache_key = [module_slug.to_s, keys.map(&:to_s)]
    return @module_record_values_cache[cache_key] if @module_record_values_cache.key?(cache_key)

    @module_value_records ||= {}
    records = @module_value_records[module_slug.to_s] ||= active_module_records_scope(module_slug).order(created_at: :desc).to_a
    @module_record_values_cache[cache_key] = records
      .flat_map do |record|
        keys.filter_map { |key| record.data[key].presence }
      end
      .flat_map { |value| value.is_a?(Array) ? value : value.to_s.split(",") }
      .map(&:to_s)
      .map(&:strip)
      .reject(&:blank?)
  end

  def first_present_data(record, *keys)
    data = record.respond_to?(:data) ? record.data : record
    data ||= {}
    keys.each do |key|
      value = data[key].presence
      return value if value
    end
    nil
  end

  def record_source_slug
    slug = @slug || current_slug
    RECORD_SOURCE_SLUGS.fetch(slug, slug)
  end

  def module_redirect_slug
    {
      "training-form" => "training-form-list",
      "vrp-bill-add" => "vrp-bill-list",
      "jeevika-jankar-bill-process" => "jeevika-jankar-bill-list",
      "seed-distribution-target" => "seed-distribution-target-list",
      "papl360-target" => "papl360-target-list",
      "other-target" => "other-target-list"
    }.fetch(record_source_slug, @slug)
  end

  def module_record_sort_value(record)
    visible_fields = @module&.dig(:fields) || []
    sort_field = visible_fields.reject { |field| field == "Status" }.first
    sort_key = sort_field&.parameterize(separator: "_")

    module_record_field_value(record, sort_field).presence ||
      record.data[sort_key].presence ||
      record.data.values.find(&:present?).to_s
  end

  def jeevika_bill_list_sort_value(record)
    status = record.data["status"].to_s.downcase
    status_priority = if status.include?("pending") || status.include?("submitted (not sent for approval)")
      0
    elsif status.include?("final approved")
      2
    else
      1
    end

    bill_date = jeevika_bill_month_date(record)
    current_month = Date.current.beginning_of_month
    month_priority = if bill_date == current_month
      [0, 0]
    elsif bill_date && bill_date < current_month
      [1, -bill_date.jd]
    elsif bill_date
      [2, bill_date.jd]
    else
      [3, 0]
    end

    [status_priority, *month_priority, -(record.id || 0)]
  end

  def jeevika_bill_month_date(record)
    month_number = Date::MONTHNAMES.index do |month_name|
      month_name.to_s.casecmp(record.data["bill_month"].to_s.strip).zero?
    end
    financial_year_start = record.data["financial_year"].to_s[/\b(\d{4})\b/, 1]&.to_i
    return if month_number.blank? || financial_year_start.blank?

    year = month_number >= 4 ? financial_year_start : financial_year_start + 1
    Date.new(year, month_number, 1)
  rescue Date::Error
    nil
  end

  def module_record_field_value(record, field)
    return nil if field.blank?
    return village_master_gram_panchayat_name(record) if record.module_slug == "village-master" && field == "Gram Panchayat"

    @module_field_keys ||= {}
    keys = @module_field_keys[field] ||= [
      field.parameterize(separator: "_"),
      *module_field_aliases(field)
    ].compact.uniq
    value = first_present_data(record, *keys)
    return approval_level_display_label(value) if field == "Approval Level"

    value
  end

  def village_master_gram_panchayat_name(record)
    direct_name = first_non_code_data(record, "gram_panchayat_name", "gp_name", "gram_name", "gram_panchayat")
    return direct_name if direct_name.present? && !code_like_location_value?(direct_name)

    code = first_present_data(record, "gp_code", "gram_code", "gram_panchayat_code", "gram_panchayat_id", "gram_panchayat", "gram_panchayat_name", "gp_name", "gram_name")
    return direct_name.presence || code if code.blank?

    gram_panchayat_name_lookup[code.to_s.strip.downcase].presence ||
      gram_panchayat_name_by_location(record, code).presence ||
      (direct_name.present? && !code_like_location_value?(direct_name) ? direct_name : nil) ||
      (code_like_location_value?(code) ? "-" : code)
  end

  def gram_panchayat_name_lookup
    @gram_panchayat_name_lookup ||= ModuleRecord
      .where(module_slug: ["gram-panchayat-master", "lg-directory-list", "village-master"])
      .select { |record| active_module_record?(record) }
      .each_with_object({}) do |record, lookup|
        label = gram_panchayat_name_from_record(record)
        next if label.blank? || code_like_location_value?(label)

        %w[gp_code gram_code gram_panchayat_code gram_panchayat_id gram_panchayat gram_panchayat_name gp_name gram_name name].each do |key|
          value = record.data[key].to_s.strip
          lookup[value.downcase] = label if value.present? && code_like_location_value?(value)
        end
      end
  end

  def gram_panchayat_name_by_location(record, code)
    normalized_code = normalize_dashboard_text(code)
    return "" if normalized_code.blank?

    state = normalize_dashboard_text(first_present_data(record, "state", "state_name"))
    district = normalize_dashboard_text(first_present_data(record, "district", "district_name"))
    block = normalize_dashboard_text(first_present_data(record, "block", "block_name", "cd_block_name"))
    return "" if state.blank? || district.blank? || block.blank?

    gram_panchayat_location_records.find do |candidate|
        code_matches = %w[gp_code gram_code gram_panchayat_code gram_panchayat_id gram_panchayat gram_panchayat_name gp_name gram_name name].any? do |key|
          normalize_dashboard_text(candidate.data[key]) == normalized_code
        end

        code_matches &&
        normalize_dashboard_text(first_present_data(candidate, "state", "state_name")) == state &&
          normalize_dashboard_text(first_present_data(candidate, "district", "district_name")) == district &&
          normalize_dashboard_text(first_present_data(candidate, "block", "block_name", "cd_block_name")) == block &&
          !code_like_location_value?(gram_panchayat_name_from_record(candidate))
      end
      &.then { |candidate| gram_panchayat_name_from_record(candidate) }
  end

  def module_field_aliases(field)
    {
      "GP Code" => ["gp_code", "gram_code"],
      "Gram Code" => ["gp_code", "gram_code"],
      "Gram Panchayat Name" => ["gram_panchayat_name", "gram_panchayat", "gram_name"],
      "Gram Panchayat" => ["gram_panchayat", "gram_panchayat_name", "gram_name"],
      "Completion Date" => ["completion_date", "date"],
      "Date" => ["completion_date", "date"],
      "Village Name" => ["village_name", "village", "name"],
      "Village Code" => ["village_code"],
      "Block Name" => ["block_name", "block", "cd_block_name"],
      "Block Code" => ["block_code", "cd_block_code"],
      "District Name" => ["district_name", "district"],
      "District Code" => ["district_code"],
      "Jeevika Jankar Type" => ["jeevika_jankar_type", "vrp_type", "select_vrp_type"],
      "Jeevika Jankar Type Name" => ["jeevika_jankar_type_name", "vrp_type_name", "position_type_name"],
      "FCO Name" => ["fco_name", "trainee_department", "department", "fcoc_name"],
      "Cluster Coordinator Name" => ["cluster_coordinator_name", "internal_trainer_name_1"],
      "Agronomist Name" => ["agronomist_name", "internal_trainer_name_2"],
      "Main Activity" => ["main_activity", "training_topic", "activity_group", "activity_group_name"],
      "Sub Activity" => ["sub_activity", "training_subject", "activity_name", "vrp_activity_name"],
      "State Name" => ["state_name", "state"],
      "State Code" => ["state_code"]
    }.fetch(field.to_s, [])
  end

  def module_record_params
    params.require(:module_record).permit!
  end

  def normalized_module_data(base_data: nil)
    submitted = module_record_params.to_h.transform_values { |value| normalize_module_param_value(value) }
    data = base_data ? base_data.deep_dup.merge(submitted) : submitted

    if record_source_slug == "access-control"
      data["module_names"] ||= []
      data["sub_module_names"] ||= []
      # Clear legacy fields during edits so deselected menus cannot reappear.
      data["sub_module_name"] = ""
      data["module_name"] = ""
      data["stakeholder"] = data["stakeholder_name"] if data["stakeholder_name"].present?
      data["vrp_type"] = data["jeevika_jankar_type"] if data["jeevika_jankar_type"].present?
      data["jeevika_jankar_type"] = data["vrp_type"].presence || data["select_vrp_type"] if data["jeevika_jankar_type"].blank?
    end

    if record_source_slug == "user-hierarchy-mapping"
      level_2_mappings = normalize_user_hierarchy_mappings(data)
      level_2_users = level_2_mappings.filter_map { |mapping| mapping["level_2_user"].presence }.uniq

      data["level_2_mappings"] = level_2_mappings
      data["level_2_users"] = level_2_users
      data["level_2_user"] = level_2_users.join(", ")
      data["level_3_users"] = []
      data["level_3_user"] = ""
      data["status"] = data["status"].presence || "Active"
    end

    if record_source_slug == "parent-office-add"
      data["parent_office_type"] = data["parent_office_type"].presence || (data["parent_office"].present? ? "Sub Parent Office" : "Parent Office")
      data["parent_office"] = "" if data["parent_office_type"] == "Parent Office"
    end

    data = normalize_training_form_data(data) if record_source_slug == "training-form"
    data = normalize_add_farmer_form_data(data) if record_source_slug == "add-farmer-form"
    data = normalize_seed_distribution_target_data(data) if other_target_record_source?
    data = normalize_jeevika_jankar_bill_data(data) if record_source_slug == "jeevika-jankar-bill-process"

    data
  end

  def normalize_module_param_value(value)
    case value
    when Array
      value.map { |item| normalize_module_param_value(item) }.compact_blank
    when Hash, ActionController::Parameters
      value.to_h.transform_values { |item| normalize_module_param_value(item) }
    else
      value.respond_to?(:original_filename) ? store_uploaded_module_file(value) : value
    end
  end

  def normalize_jeevika_jankar_bill_data(data)
    stamp_jeevika_jankar_bill_creator!(data)

    bill_items = data["bill_items"]
    bill_items = bill_items.values if bill_items.is_a?(Hash)
    bill_items = Array(bill_items).filter_map do |item|
      next unless item.respond_to?(:to_h)

      item = item.to_h
      item["farmer_details"] = parse_bill_farmer_details(item["farmer_details"])
      item["achievement_count"] = numeric_string(item["achievement_count"])
      item["target_quantity"] = numeric_string(item["target_quantity"])
      item["assigned_count"] = numeric_string(item["assigned_count"])
      item["same_activity_count"] = numeric_string(item["same_activity_count"])
      item["other_activity_count"] = numeric_string(item["other_activity_count"])
      item["main_activity_type"] = item["main_activity_type"].presence || data["main_activity_type"].presence || "Training"
      item["achievement_entry_mode"] = item["achievement_entry_mode"].presence || data["achievement_entry_mode"].presence || "Auto Fill"
      item["pending_count"] = dashboard_quantity([item["assigned_count"].to_f - item["achievement_count"].to_f, 0].max)
      item["rate"] = decimal_string(item["rate"])
      item["amount"] = decimal_string(item["achievement_count"].to_f * item["rate"].to_f)
      item
    end

    bill_totals = jeevika_jankar_bill_item_totals(bill_items)

    data["invoice_no"] = data["invoice_no"].presence || generated_jeevika_jankar_invoice_no
    data["invoice_date"] = data["invoice_date"].presence || Date.current.to_s
    data["select_vrp_name"] = jeevika_jankar_vrp_label(data["select_vrp"])
    data["main_activity_type"] = data["main_activity_type"].presence || "Training"
    data["achievement_entry_mode"] = data["achievement_entry_mode"].presence || "Auto Fill"
    data["bill_items"] = bill_items
    data["total_target"] = dashboard_quantity(bill_totals[:target])
    data["total_achievement"] = dashboard_quantity(bill_totals[:achievement])
    payment = decimal_value(data["grand_total"])
    data["grand_total"] = payment ? format("%.2f", payment) : data["grand_total"].to_s
    data["status"] = data["status"].presence || "Submitted (Not sent for approval)"
    data["record_state"] = data["record_state"].presence || "Active"
    data
  end

  def preload_jeevika_bill_process_totals(records)
    @jeevika_bill_process_totals ||= {}
    Array(records).group_by { |record| normalize_dashboard_text(record.data["bill_month"]) }.each_value do |bills|
      month = bills.first.data["bill_month"]
      ids = bills.filter_map { |bill| bill.data["select_vrp"].presence }.uniq
      next if month.blank? || ids.blank?

      previous_summary = @jeevika_jankar_target_summary
      previous_batch_mode = @bill_list_batch_totals
      begin
        @bill_list_batch_totals = true
        remove_instance_variable(:@approved_other_target_completed_farmer_ids_by_target) if instance_variable_defined?(:@approved_other_target_completed_farmer_ids_by_target)
        jeevika_jankar_bill_rows(vrp_id: ids.join(","), month_name: month, totals_only: true)
        bills.each do |bill|
          id = bill.data["select_vrp"].to_s
          month_key = normalize_dashboard_text(month)
          @jeevika_bill_process_totals[[id, month_key]] = @jeevika_jankar_target_summary&.dig(id, month_key)
        end
      ensure
        @bill_list_batch_totals = previous_batch_mode
        @jeevika_jankar_target_summary = previous_summary
      end
    end
  end

  # Use the same dashboard assignment summary as the Bill Process form.
  def jeevika_jankar_bill_process_totals(record)
    vrp_id = record.data["select_vrp"].to_s
    month = record.data["bill_month"].to_s
    return if vrp_id.blank? || month.blank?

    @jeevika_bill_process_totals ||= {}
    key = [vrp_id, normalize_dashboard_text(month)]
    return @jeevika_bill_process_totals[key] if @jeevika_bill_process_totals.key?(key)

    previous_summary = @jeevika_jankar_target_summary
    begin
      jeevika_jankar_bill_rows(vrp_id: vrp_id, month_name: month, totals_only: true)
      ids = jeevika_jankar_bill_selected_vrp_ids(vrp_id)
      @jeevika_bill_process_totals[key] = @jeevika_jankar_target_summary&.dig(ids.first, key.last)
    ensure
      @jeevika_jankar_target_summary = previous_summary
    end
  end

  def jeevika_jankar_bill_total_target(record)
    summary = jeevika_jankar_bill_process_totals(record)
    return summary[:target] if summary

    totals = jeevika_jankar_bill_item_totals(record.data["bill_items"])
    return dashboard_quantity(totals[:target]) if totals[:has_items]

    record.data["total_target"].presence || "0"
  end

  def jeevika_jankar_bill_total_achievement(record)
    summary = jeevika_jankar_bill_process_totals(record)
    return summary[:achievement] if summary

    totals = jeevika_jankar_bill_item_totals(record.data["bill_items"])
    return dashboard_quantity(totals[:achievement]) if totals[:has_items]

    record.data["total_achievement"].presence || "0"
  end

  def jeevika_jankar_bill_item_totals(items)
    rows = items.is_a?(Hash) ? items.values : Array(items)
    rows = rows.select { |item| item.respond_to?(:to_h) }.map(&:to_h)
    grouped_totals = {}

    totals = rows.each_with_object({ target: 0.0, achievement: 0.0, has_items: rows.any? }) do |item, result|
      target_quantity = dashboard_numeric(item["target_quantity"])
      assigned_count = dashboard_numeric(item["assigned_count"])
      target = if normalize_dashboard_text(item["main_activity_type"]) == "other"
        target_quantity
      else
        assigned_count.positive? ? assigned_count : target_quantity
      end
      achievement = dashboard_numeric(item["achievement_count"])
      target_key = item["target_mapping_id"].to_s.presence

      if target_key.present?
        grouped_totals[target_key] ||= { target: 0.0, achievement: 0.0 }
        grouped_totals[target_key][:target] = [grouped_totals[target_key][:target], target].max
        grouped_totals[target_key][:achievement] += achievement
      else
        result[:target] += target
        result[:achievement] += [achievement, target].min
      end
    end

    grouped_totals.each_value do |grouped_total|
      totals[:target] += grouped_total[:target]
      totals[:achievement] += [grouped_total[:achievement], grouped_total[:target]].min
    end

    totals
  end

  def jeevika_payment_detail_error_messages(raw_data, selected_bill_ids, selected_records)
    errors = missing_required_data_errors(
      raw_data,
      "approval_date" => "Approval Date",
      "transaction_id" => "Transaction ID",
      "transaction_type" => "Transaction Type",
      "transaction_date" => "Transaction Date"
    )

    errors << "Kam se kam ek Jeevika Jankar select karein." if selected_bill_ids.blank?
    errors << "Selected Jeevika Jankar final approved ya unpaid nahi hai." if selected_bill_ids.any? && selected_records.blank?
    if selected_records.any? && selected_records.size != selected_bill_ids.size
      errors << "Kuch selected Jeevika Jankar final approved ya unpaid nahi hain."
    end

    transaction_type = raw_data["transaction_type"].to_s.strip.upcase
    if raw_data["transaction_type"].present? && !JEEVIKA_PAYMENT_TRANSACTION_TYPES.include?(transaction_type)
      errors << "Transaction Type NEFT, RTGS ya IMPS me se select karein."
    end

    selected_dates = selected_records.map { |record| jeevika_bill_final_approval_date(record) }.uniq
    if raw_data["approval_date"].present? && selected_dates.any? && selected_dates != [raw_data["approval_date"].to_s]
      errors << "Selected Jeevika Jankar chosen approval date ke hone chahiye."
    end

    errors
  end

  def normalized_jeevika_payment_detail_data(raw_data, selected_records)
    stamp_jeevika_jankar_bill_creator!(raw_data)

    payment_items = selected_records.map do |record|
      {
        "bill_id" => record.id.to_s,
        "jeevika_jankar_id" => record.data["select_vrp"].to_s,
        "jeevika_jankar_name" => jeevika_jankar_display_name(record.data["select_vrp_name"].presence || jeevika_jankar_vrp_label(record.data["select_vrp"])),
        "financial_year" => record.data["financial_year"].to_s,
        "bill_month" => record.data["bill_month"].to_s,
        "approval_date" => jeevika_bill_final_approval_date(record),
        "amount" => format("%.2f", jeevika_jankar_bill_total_payment(record).to_f)
      }
    end

    data = raw_data.except("selected_bill_ids", "transaction_file", "excel_file")
    data["selected_bill_ids"] = selected_records.map { |record| record.id.to_s }
    data["payment_items"] = payment_items
    data["selected_count"] = selected_records.size.to_s
    data["transaction_type"] = raw_data["transaction_type"].to_s.strip.upcase
    total_payment = selected_records.sum { |record| jeevika_jankar_bill_total_payment(record).to_f }
    data["jeevika_jankar_payment_amount"] = format("%.2f", total_payment)
    data["status"] = "Paid"
    data["transaction_file"] = store_uploaded_module_file(raw_data["transaction_file"]) if raw_data["transaction_file"].respond_to?(:original_filename)
    data["excel_file"] = store_uploaded_module_file(raw_data["excel_file"]) if raw_data["excel_file"].respond_to?(:original_filename)
    data
  end

  def send_jeevika_payment_advice_sms(raw_data, selected_records)
    reference_number = raw_data["transaction_id"].to_s.strip
    transaction_date = raw_data["transaction_date"]
    sent = 0
    failed = 0
    skipped = 0

    selected_records.each do |record|
      vrp = jeevika_bill_vrp(record)
      mobile = vrp&.mobile_no.to_s.strip
      beneficiary_name = jeevika_jankar_display_name(
        record.data["select_vrp_name"].presence || jeevika_jankar_vrp_label(record.data["select_vrp"]) || vrp&.name
      ).presence || vrp&.name.to_s

      if mobile.blank? || beneficiary_name.blank?
        skipped += 1
        Rails.logger.warn("[Payment SMS] Skipped bill ##{record.id}: missing mobile or beneficiary name.")
        next
      end

      result = PaymentAdviceSmsSender.new(
        mobile,
        reference_number: reference_number,
        amount: jeevika_jankar_bill_total_payment(record).to_f,
        beneficiary_name: beneficiary_name,
        transaction_date: transaction_date
      ).deliver

      if result.success?
        sent += 1
      else
        failed += 1
        Rails.logger.warn("[Payment SMS] Failed for #{mobile}: #{result.message}")
      end
    end

    parts = []
    parts << "SMS sent: #{sent}." if sent.positive?
    parts << "SMS failed: #{failed}." if failed.positive?
    parts << "SMS skipped: #{skipped}." if skipped.positive?
    parts.join(" ")
  end

  def jeevika_bill_final_approval_date(record)
    approval_history = jeevika_bill_approval_history(record)
      .select { |history| history.data["action"].to_s == "Approved" }
      .sort_by { |history| parse_bill_datetime(history.data["action_at"]) || history.created_at }

    value = approval_history.last&.data&.[]("action_at").presence || record&.data&.[]("final_approved_at").presence || record&.updated_at&.to_date || record&.created_at&.to_date
    parse_bill_datetime(value)&.to_date&.to_s || parse_module_date(value)&.to_s || value.to_s
  rescue ArgumentError, TypeError
    record&.updated_at&.to_date&.to_s || record&.created_at&.to_date&.to_s
  end

  def stamp_jeevika_jankar_bill_creator!(data)
    user = current_app_user || {}
    data["created_by_record_type"] = data["created_by_record_type"].presence || user["record_type"].to_s
    data["created_by_id"] = data["created_by_id"].presence || user["id"].to_s
    data["created_by_username"] = data["created_by_username"].presence || user["username"].presence || user["user_name"].to_s
    data["created_by_name"] = data["created_by_name"].presence || user["name"].to_s
    data["created_by_email"] = data["created_by_email"].presence || user["email"].to_s
  end

  def jeevika_jankar_vrp_label(vrp_id)
    return "" if vrp_id.blank? || !model_ready?(:Vrp)

    vrp = cached_vrp_lookup(vrp_id)
    return "" unless vrp

    vrp&.name.presence || vrp&.user_name.presence || "Jeevika Jankar ##{vrp.id}"
  end

  def jeevika_jankar_display_name(value)
    value.to_s.strip.sub(/\s*-\s*\d{6,}\z/, "")
  end

  def bill_display_date(value)
    parse_module_date(value)&.strftime("%d/%m/%Y") || value.to_s.presence || "-"
  end

  def bill_display_datetime(value)
    parse_bill_datetime(value)&.in_time_zone(Time.zone)&.strftime("%d-%b-%Y %I:%M %p") || "-"
  rescue ArgumentError, TypeError
    "-"
  end

  def parse_bill_datetime(value)
    case value
    when ActiveSupport::TimeWithZone, Time, DateTime
      value
    else
      Time.zone.parse(value.to_s)
    end
  end

  def jeevika_bill_vrp(record)
    return nil unless model_ready?(:Vrp)

    data = record&.data || {}
    cached_vrp_lookup(data["select_vrp"].presence || data["vrp_id"].presence || data["jeevika_jankar_id"].presence)
  end

  def first_present_from_items(items, *keys)
    items.each do |item|
      keys.each do |key|
        value = item[key].presence
        return value if value.present?
      end
    end

    nil
  end

  def jeevika_jankar_bill_record_visible?(record)
    return true if admin_dashboard_user?
    return false unless record&.data.present?
    if module_cluster_incharge_login? && !dashboard_agronomics_login? && !dashboard_source_fcoc_login? && !vrp_login_user?
      return jeevika_bill_created_by_current_user?(record)
    end
    vrp = jeevika_bill_vrp_for_visibility(record)
    return false unless vrp
    return scoped_jeevika_vrp_visible?(vrp) if jeevika_assignment_scope_required?

    scoped_jeevika_vrp_visible?(vrp) || jeevika_bill_created_by_current_user?(record) || jeevika_bill_approver_visible?(record)
  end

  def jeevika_assignment_scope_required?
    vrp_login_user? || dashboard_agronomics_login? || dashboard_source_fcoc_login? || module_cluster_incharge_login?
  end

  def scoped_jeevika_vrp_visible?(vrp)
    return true if admin_dashboard_user?
    return false unless vrp
    return vrp.id.to_s == current_vrp_record&.id.to_s if vrp_login_user?
    return jeevika_bill_vrp_registered_by_current_user?(vrp) if dashboard_agronomics_login?
    return jeevika_bill_vrp_fco_visible?(vrp) if dashboard_source_fcoc_login?
    return module_cluster_vrp_visible?(vrp) if module_cluster_incharge_login?

    jeevika_bill_vrp_registered_by_current_user?(vrp)
  end

  def jeevika_jankar_payment_module_access?(slug)
    return true if admin_dashboard_user?

    keys = helpers.allowed_sidebar_keys
    return false if keys.blank?

    keys.include?(slug.to_s)
  end

  def jeevika_jankar_payment_list_user?
    jeevika_jankar_payment_module_access?("jeevika-jankar-payment-list")
  end

  def jeevika_jankar_bill_downloadable?(record)
    return true if jeevika_jankar_bill_record_visible?(record)
    return true if jeevika_bill_final_approved?(record) && jeevika_jankar_payment_list_user?

    false
  end

  def module_record_visible_for_current_context?(record)
    return false unless record && record.module_slug == record_source_slug
    return jeevika_jankar_bill_record_visible?(record) if record&.module_slug == "jeevika-jankar-bill-process" || record_source_slug == "jeevika-jankar-bill-process"
    return target_record_visible?(record) if TARGET_RECORD_MODULE_SLUGS.include?(record&.module_slug) || target_record_source?

    true
  end

  def jeevika_bill_vrp_for_visibility(record)
    vrp_id = record.data["select_vrp"].presence || record.data["vrp_id"].presence || record.data["jeevika_jankar_id"].presence
    return if vrp_id.blank? || !model_ready?(:Vrp)

    cached_vrp_lookup(vrp_id)
  end

  def jeevika_bill_created_by_current_user?(record)
    data = record.data
    if data["created_by_id"].present? && data["created_by_record_type"].present? &&
        data["created_by_record_type"].to_s.casecmp(current_app_user&.dig("record_type").to_s).zero?
      return data["created_by_id"].to_s == current_app_user&.dig("id").to_s
    end
    current_user_values = normalized_visibility_values(
      current_app_user&.dig("username"),
      current_app_user&.dig("user_name"),
      current_app_user&.dig("name"),
      current_app_user&.dig("email")
    )
    creator_values = normalized_visibility_values(
      data["created_by_username"],
      data["created_by_name"],
      data["created_by_email"]
    )
    return (current_user_values & creator_values).any? if creator_values.any?

    creator_record_type = data["created_by_record_type"].to_s
    current_record_type = current_app_user&.dig("record_type").to_s
    return false if creator_record_type.blank? || current_record_type.blank?
    return false unless creator_record_type.casecmp(current_record_type).zero?

    data["created_by_id"].present? && data["created_by_id"].to_s == current_app_user&.dig("id").to_s
  end

  def jeevika_bill_pending_for_current_approver?(record)
    status = jeevika_bill_status_label(record).to_s
    return false unless status.downcase.include?("pending")

    jeevika_bill_current_approver?(record) ||
      dashboard_user_label_matches?(status.sub(/\Apending\s+at\s+/i, ""), current_dashboard_user_labels)
  end

  # An approver must retain access after acting on a bill so that both pending
  # and previously approved/rejected bills remain available in their list.
  def jeevika_bill_approver_visible?(record)
    return true if jeevika_bill_pending_for_current_approver?(record)

    labels = current_dashboard_user_labels
    return false if labels.blank?

    jeevika_bill_approval_history(record).any? do |history|
      dashboard_user_label_matches?(history.data["approver"], labels) ||
        dashboard_user_label_matches?(history.data["action_by"], labels)
    end
  end

  def jeevika_bill_vrp_registered_by_current_user?(vrp)
    current_ids = dashboard_current_app_user_ids.map(&:to_s)
    return true if vrp.created_by_id.present? && current_ids.include?(vrp.created_by_id.to_s)
    return true if vrp.respond_to?(:user_id) && vrp.user_id.present? && current_ids.include?(vrp.user_id.to_s)

    false
  end

  def jeevika_bill_vrp_fco_visible?(vrp)
    user = current_app_user || {}
    values = [user["fcoc"], user["fcoc_name"], user["office_name"], user["parent_office"], user["office_category"], user["office"]].compact_blank
    fco_values = values.select { |value| value.to_s.match?(/fco/i) }
    fco_values = [user["fcoc"], user["fcoc_name"], user["office_name"]].compact_blank if fco_values.empty?
    vrp_fco = normalized_bill_fco(vrp.fcoc)
    vrp_fco.present? && fco_values.any? { |value| normalized_bill_fco(value) == vrp_fco }
  end

  def normalized_bill_fco(value)
    normalize_dashboard_user_label(value.to_s.sub(/\A\s*fco(?:\s*[- ]?\s*c)?\s*[-:]?\s*/i, ""))
  end

  def jeevika_bill_vrp_office_visible?(vrp)
    vrp_fcoc_values = normalized_visibility_values(vrp.fcoc)
    vrp_to_values = normalized_visibility_values(vrp.to_name)
    current_fcoc_values = normalized_visibility_values(
      current_app_user&.dig("fcoc"),
      current_app_user&.dig("fcoc_name"),
      current_app_user&.dig("office_category"),
      current_app_user&.dig("parent_office")
    )
    current_to_values = normalized_visibility_values(
      current_app_user&.dig("to"),
      current_app_user&.dig("to_name"),
      current_app_user&.dig("sub_office_name"),
      current_app_user&.dig("office"),
      current_app_user&.dig("office_name")
    )

    current_office_values = (current_fcoc_values + current_to_values).uniq
    fcoc_matches = vrp_fcoc_values.any? && (vrp_fcoc_values & current_office_values).any?
    to_matches = vrp_to_values.any? && (vrp_to_values & current_office_values).any?

    return to_matches if current_to_values.any? && vrp_to_values.any?
    return fcoc_matches if vrp_fcoc_values.any? && vrp_to_values.any?
    return fcoc_matches if vrp_fcoc_values.any?
    return to_matches if vrp_to_values.any?

    false
  end

  def normalized_visibility_values(*values)
    Array(values)
      .flatten
      .compact_blank
      .map { |value| normalize_dashboard_user_label(value) }
      .reject(&:blank?)
      .uniq
  end

  def parse_bill_farmer_details(value)
    return value if value.is_a?(Array)

    JSON.parse(value.to_s)
  rescue JSON::ParserError
    []
  end

  def numeric_string(value)
    number = value.to_s.gsub(",", "").to_f
    number == number.to_i ? number.to_i.to_s : number.to_s
  end

  def decimal_string(value)
    format("%.2f", value.to_s.gsub(",", "").to_f)
  end

  def normalize_training_form_data(data)
    stamp_target_record_creator!(data)
    trainer_name, trainer_contact = training_trainer_defaults
    data["trainer_name"] = trainer_name if data["trainer_name"].blank? && trainer_name.present?
    data["trainer_contact"] = trainer_contact if data["trainer_contact"].blank? && trainer_contact.present?
    data["fco_name"] = data["fco_name"].presence || data["trainee_department"].presence || training_trainee_department_default
    data["trainee_department"] = data["fco_name"] if data["trainee_department"].blank?
    data["cluster_coordinator_name"] = data["cluster_coordinator_name"].presence || data["internal_trainer_name_1"].presence
    data["agronomist_name"] = data["agronomist_name"].presence || data["internal_trainer_name_2"].presence
    data["main_activity_type"] = data["main_activity_type"].presence || "Training"
    raw_main_activities = data["main_activity"].presence || data["training_topic"].presence
    main_activities = Array(raw_main_activities).map(&:to_s).map(&:strip).reject(&:blank?).uniq
    data["main_activities"] = main_activities
    data["main_activity"] = main_activities.one? ? main_activities.first : main_activities
    raw_sub_activities = data["sub_activity"].presence || data["training_subject"].presence
    sub_activities = if raw_sub_activities.is_a?(Array)
      raw_sub_activities
    else
      raw_sub_activities.to_s.split(/,\s*(?=\d+\.\s*)/)
    end
    sub_activities = sub_activities.map(&:to_s).map(&:strip).reject(&:blank?).uniq
    data["sub_activities"] = sub_activities
    data["sub_activity"] = sub_activities.one? ? sub_activities.first : sub_activities
    data["training_topic"] = main_activities.join(", ") if main_activities.present?
    data["training_subject"] = sub_activities.join(", ") if sub_activities.present?

    matching_mappings = training_target_matches(data)
    if (mapping = matching_mappings.first)
      data["target_mapping_id"] = mapping[:target_mapping_id]
      data["target_mapping_ids"] = matching_mappings.map { |row| row[:target_mapping_id].to_s }.reject(&:blank?).uniq
      data["jeevika_jankar_id"] = mapping[:vrp_id]
      data["jeevika_jankar_name"] = mapping[:jeevika_jankar_name]
      data["jeevika_jankar_contact"] = mapping[:contact_number]
    end

    selected_farmer_ids = Array(data["selected_farmer_ids"]).map(&:to_s).reject(&:blank?).uniq
    data["selected_farmer_ids"] = selected_farmer_ids
    data["selected_farmer_names"] = training_farmer_names(selected_farmer_ids)
    data["farmer_count"] = selected_farmer_ids.size.to_s
    data["total_farmer_count"] = training_total_farmer_count(data).to_s if training_total_farmer_count(data)
    data.delete("status")
    data
  end

  def normalize_seed_distribution_target_data(data)
    stamp_target_record_creator!(data)
    data["main_activity_type"] = "Other"
    data["training_topic"] = data["training_topic"].presence || data["main_activity"].presence
    data["training_subject"] = data["training_subject"].presence || data["sub_activity"].presence
    data["completion_date"] = data["completion_date"].presence || data["date"].presence || Date.current.to_s
    data["date"] = data["completion_date"]

    if (mapping = seed_distribution_target_match(data))
      data["target_mapping_id"] = mapping[:target_mapping_id]
      data["jeevika_jankar_id"] = mapping[:vrp_id]
      data["jeevika_jankar_name"] = mapping[:jeevika_jankar_name]
      data["contact_number"] = mapping[:contact_number]
      data["jeevika_jankar_contact"] = mapping[:contact_number]
      data["department"] = mapping[:department]
      data["fcoc_name"] = mapping[:department]
      data["target"] = mapping[:target].to_s if data["target"].blank?
      data["main_activity"] = mapping[:training_topic]
      data["sub_activity"] = mapping[:training_subject]
    end

    selected_farmer_ids = Array(data["selected_farmer_ids"]).map(&:to_s).reject(&:blank?).uniq
    if record_source_slug != "other-target" && data["target_mapping_id"].present?
      pending_farmer_ids = pending_other_target_farmer_ids_for(data["target_mapping_id"])
      selected_farmer_ids &= pending_farmer_ids unless pending_farmer_ids.nil?
    end
    data["selected_farmer_ids"] = selected_farmer_ids
    data["selected_farmer_names"] = training_farmer_names(selected_farmer_ids)
    data["farmer_count"] = selected_farmer_ids.size.to_s if selected_farmer_ids.any?

    data["achievement"] = numeric_string(data["achievement"]) if data["achievement"].present?
    data["target"] = numeric_string(data["target"]) if data["target"].present?
    data.delete("status")
    data
  end

  def stamp_target_record_creator!(data)
    user = current_app_user || {}
    data["created_by_record_type"] = data["created_by_record_type"].presence || user["record_type"].to_s
    data["created_by_id"] = data["created_by_id"].presence || user["id"].to_s
    data["created_by_username"] = data["created_by_username"].presence || user["username"].presence || user["user_name"].to_s
    data["created_by_name"] = data["created_by_name"].presence || user["name"].to_s
    data["created_by_email"] = data["created_by_email"].presence || user["email"].to_s
  end

  def normalize_add_farmer_form_data(data)
    stamp_target_record_creator!(data)

    mapping = add_farmer_form_mapping_for(data["target_mapping_id"])
    if mapping
      data["vrp_id"] = mapping[:vrp_id]
      data["jeevika_jankar_id"] = mapping[:vrp_id]
      data["jeevika_jankar_name"] = mapping[:jeevika_jankar_name]
      data["contact_number"] = mapping[:contact_number]
      data["fco_id"] = mapping[:fco_id]
      data["fco_name"] = mapping[:fco_name]
      data["ics_id"] = mapping[:ics_id]
      data["ics_name"] = mapping[:ics_name]
      data["village_id"] = mapping[:village_id]
      data["village_name"] = mapping[:village_name]
      data["mapped_village"] = mapping[:label]
      data["new_farmer_target"] = mapping[:target_quantity]
    end

    data.delete("selected_farmer_ids")
    data["no_farmer"] = whole_number_value(data["no_farmer"]).to_s if whole_number_value(data["no_farmer"])
    data
  end

  def add_farmer_form_mapping_for(mapping_id)
    add_farmer_form_mappings.find { |mapping| mapping[:id].to_s == mapping_id.to_s }
  end

  def add_farmer_form_error_messages(data)
    errors = []
    mapping = add_farmer_form_mapping_for(data["target_mapping_id"])

    errors << "Mapped Village required hai." if mapping.blank?
    errors << "New Farmer Target required hai." if mapping.present? && data["new_farmer_target"].to_i != mapping[:target_quantity].to_i
    errors << "No. Farmer required hai." if data["no_farmer"].blank?
    errors << "No. Farmer valid whole number hona chahiye." if data["no_farmer"].present? && whole_number_value(data["no_farmer"]).nil?
    errors << "No. Farmer 0 se jyada hona chahiye." if whole_number_value(data["no_farmer"]) && whole_number_value(data["no_farmer"]).to_i <= 0
    errors
  end

  def training_target_match(data)
    training_target_matches(data).first
  end

  def training_target_matches(data)
    selected_month = normalize_dashboard_text(data["month"])
    selected_ics = normalize_dashboard_text(data["ics_block"].presence || data["ics"])
    selected_village = normalize_dashboard_text(data["gram_name"].presence || data["village"])
    selected_main_activities = training_activity_values(data["main_activities"].presence || data["main_activity"].presence || data["training_topic"])
    selected_sub_activities = training_activity_values(data["sub_activities"].presence || data["sub_activity"].presence || data["training_subject"])

    training_target_mappings.select do |mapping|
      normalize_dashboard_text(mapping[:month]) == selected_month &&
        normalize_dashboard_text(mapping[:ics]) == selected_ics &&
        normalize_dashboard_text(mapping[:village]) == selected_village &&
        selected_main_activities.any? { |main_activity| dashboard_training_activity_text_matches?(main_activity, normalize_dashboard_text(mapping[:main_activity])) } &&
        selected_sub_activities.any? { |sub_activity| dashboard_training_activity_text_matches?(sub_activity, normalize_dashboard_text(mapping[:sub_activity])) }
    end
  end

  def seed_distribution_target_match(data)
    selected_vrp = normalize_dashboard_text(data["jeevika_jankar_id"].presence || data["jeevika_jankar_name"])
    selected_month = normalize_dashboard_text(data["month"])
    selected_ics = normalize_dashboard_text(data["ics"])
    selected_village = normalize_dashboard_text(data["village"])
    selected_topic = normalize_dashboard_text(data["training_topic"])
    selected_subject = normalize_dashboard_text(data["training_subject"])

    seed_distribution_target_mappings.find do |mapping|
      seed_distribution_vrp_matches?(mapping, selected_vrp) &&
        normalize_dashboard_text(mapping[:month]) == selected_month &&
        normalize_dashboard_text(mapping[:ics]) == selected_ics &&
        normalize_dashboard_text(mapping[:village]) == selected_village &&
        normalize_dashboard_text(mapping[:training_topic]) == selected_topic &&
        normalize_dashboard_text(mapping[:training_subject]) == selected_subject
    end
  end

  def seed_distribution_vrp_matches?(mapping, selected_vrp)
    return false if selected_vrp.blank?

    [
      mapping[:vrp_id],
      mapping[:jeevika_jankar_name]
    ].any? { |value| normalize_dashboard_text(value) == selected_vrp }
  end

  def pending_other_target_farmer_ids_for(target_mapping_id)
    return nil unless model_ready?(:TargetMapping)

    target = TargetMapping.find_by(id: target_mapping_id)
    return [] unless target

    target_farmer_ids(target) - other_target_completed_farmer_ids_for(target.id)
  end

  def training_form_activity_scope_present?(data)
    data["month"].present? && data["gram_name"].present? && data["main_activity"].present? && data["sub_activity"].present?
  end

  def pending_training_farmer_ids_for(data)
    return nil unless model_ready?(:TargetMapping)

    selected_month = normalize_dashboard_text(data["month"])
    selected_ics = normalize_dashboard_text(data["ics_block"])
    selected_village = normalize_dashboard_text(data["gram_name"])
    selected_main_activity_type = normalize_dashboard_text(data["main_activity_type"])
    selected_main_activities = training_activity_values(data["main_activities"].presence || data["main_activity"])
    selected_sub_activities = training_activity_values(data["sub_activities"].presence || data["sub_activity"])
    activity_settings = jeevika_jankar_main_activity_settings

    training_target_scope.each_with_object([]) do |target, ids|
      activity_setting = activity_settings[normalize_dashboard_text(target.main_activity_name)]
      next if activity_setting.blank? || !training_main_activity_type?(activity_setting[:main_activity_type])

      target_main_activity_type = normalize_dashboard_text(activity_setting[:main_activity_type].presence || "Training")
      next if normalize_dashboard_text(target.month_name) != selected_month
      next if selected_ics.present? && normalize_dashboard_text(target.ics_name.presence || target.ics_id) != selected_ics
      next if normalize_dashboard_text(target.village_name.presence || target.village_id) != selected_village
      next if selected_main_activity_type.present? && target_main_activity_type != selected_main_activity_type
      next unless selected_main_activities.include?(normalize_dashboard_text(target.main_activity_name))
      next unless selected_sub_activities.include?(normalize_dashboard_text(target.activity_name))

      farmer_ids = Array(target.afl_ids).map(&:to_s).reject(&:blank?).uniq
      ids.concat(farmer_ids - completed_training_farmer_ids_for(target, farmer_ids))
    end.uniq
  end

  def training_trainer_defaults
    if vrp_login_user? && current_vrp_record.present?
      return [current_vrp_record.name, current_vrp_record.mobile_no]
    end

    [current_app_user&.dig("name"), current_app_user&.dig("mobile_no")]
  end

  def training_trainee_department_default
    [
      registered_vrp_fcoc(current_vrp_record),
      current_app_user&.dig("fcoc"),
      current_app_user&.dig("fcoc_name")
    ].compact_blank.first.to_s
  end

  def registered_vrp_fcoc(vrp)
    vrp&.fcoc.to_s.strip
  end

  def training_farmer_names(farmer_ids)
    return [] if farmer_ids.blank? || !model_ready?(:Afl)

    Afl.where(id: farmer_ids)
      .order(:farmer_name, :id)
      .map { |farmer| farmer.farmer_name.presence || "Farmer ##{farmer.id}" }
  end

  def training_total_farmer_count(data)
    male_count = whole_number_value(data["male_count"])
    female_count = whole_number_value(data["female_count"])
    return nil unless male_count && female_count

    male_count + female_count
  end

  def normalize_user_hierarchy_mappings(data)
    raw_mappings = data["level_2_mappings"]
    raw_mappings = raw_mappings.values if raw_mappings.is_a?(Hash)
    raw_mappings = Array(raw_mappings)

    mappings = raw_mappings.filter_map do |mapping|
      mapping = mapping.to_h if mapping.respond_to?(:to_h)
      next unless mapping.is_a?(Hash)

      users = collapsed_hierarchy_users(mapping["level_2_user"], mapping["level_3_users"])
      next if users.blank?

      users.map do |level_2_user|
        {
          "level_2_user" => level_2_user,
          "level_3_users" => []
        }
      end
    end
    mappings.flatten!

    return mappings if mappings.any?

    collapsed_hierarchy_users(data["level_2_users"], data["level_3_users"]).map do |level_2_user|
      {
        "level_2_user" => level_2_user,
        "level_3_users" => []
      }
    end
  end

  def duplicate_access_control_record?(data, except_id: nil)
    return false unless record_source_slug == "access-control"
    return false unless model_ready?(:ModuleRecord)

    stakeholder = normalized_access_value(data["stakeholder_name"].presence || data["stakeholder"])
    stakeholder_role = normalized_access_value(data["stakeholder_role"].presence || data["stakeholder_person_type"])
    role = normalized_access_value(data["role"].presence || data["role_name"])
    role_name = normalized_access_value(data["role"].present? ? data["role_name"] : nil)
    user_management_role = normalized_access_value(data["user_management_role"].presence || data["user_management_person_type"])
    person_type = normalized_access_value(data["person_type"])
    vrp_type = normalized_access_value(data["jeevika_jankar_type"].presence || data["vrp_type"].presence || data["select_vrp_type"])
    return false if stakeholder.blank?

    ModuleRecord
      .where(module_slug: "access-control")
      .where.not(id: except_id)
      .any? do |record|
        normalized_access_value(record.data["stakeholder_name"].presence || record.data["stakeholder"]) == stakeholder &&
          normalized_access_value(record.data["stakeholder_role"].presence || record.data["stakeholder_person_type"]) == stakeholder_role &&
          normalized_access_value(record.data["role"].presence || record.data["role_name"]) == role &&
          normalized_access_value(record.data["role"].present? ? record.data["role_name"] : nil) == role_name &&
          normalized_access_value(record.data["user_management_role"].presence || record.data["user_management_person_type"]) == user_management_role &&
          normalized_access_value(record.data["person_type"]) == person_type &&
          normalized_access_value(record.data["jeevika_jankar_type"].presence || record.data["vrp_type"].presence || record.data["select_vrp_type"]) == vrp_type &&
          normalized_access_value(record.data["status"].presence || "Active") == "active"
      end
  end

  def gram_panchayat_location_records
    @gram_panchayat_location_records ||= ModuleRecord
      .where(module_slug: ["gram-panchayat-master", "lg-directory-list"])
      .select { |candidate| active_module_record?(candidate) }
  end

  def normalized_access_value(value)
    value.to_s.strip.downcase
  end

  def sync_stakeholder_name_change(previous_data, next_data)
    return unless record_source_slug == "stakeholder-master"

    previous_names = stakeholder_record_names(previous_data)
    next_name = (next_data["stakeholder_name_in_english"].presence || next_data["stakeholder_name"].presence).to_s.strip
    return if previous_names.blank? || next_name.blank?

    previous_names.each do |previous_name|
      next if previous_name == next_name

      User.where(stakeholder: previous_name).update_all(stakeholder: next_name, updated_at: Time.current) if model_ready?(:User)
      sync_legacy_user_stakeholder_name(previous_name, next_name)
    end
  end

  def stakeholder_record_names(data)
    [
      data["stakeholder_name_in_english"],
      data["stakeholder_name_in_hindi"],
      data["stakeholder_name"]
    ].compact_blank.map(&:to_s).map(&:strip).uniq
  end

  def sync_legacy_user_stakeholder_name(previous_name, next_name)
    return unless model_ready?(:ModuleRecord)

    ModuleRecord.where(module_slug: "new-user").find_each do |user_record|
      next unless user_record.data["stakeholder"].to_s.strip == previous_name

      user_record.update(data: user_record.data.merge("stakeholder" => next_name))
    end
  end

  def approval_channel_params?
    module_record_params[:approval_steps].present?
  end

  def create_approval_channel
    data = normalized_module_data
    steps = approval_channel_step_rows(data.delete("approval_steps"))
    saved_count = 0

    steps.each do |step|
      level = step["approval_level"]
      approver = step["approver_approved_by"]
      next if approver.blank?

      ModuleRecord.create!(
        module_slug: "approval-master",
        data: data.merge(
          "approval_level" => level,
          "approver_approved_by" => approver,
          "status" => data["status"].presence || "Active"
        )
      )
      saved_count += 1
    end

    if saved_count.positive?
      redirect_to module_path("approval-list"), notice: "Approval channel saved successfully."
    else
      @records = module_records
      flash.now[:alert] = "Please select at least one approval user."
      render :show, status: :unprocessable_entity
    end
  end

  def update_approval_channel(record)
    data = normalized_module_data
    steps = approval_channel_step_rows(data.delete("approval_steps"))
    channel_records = approval_channel_records_for(record)
    records_by_id = channel_records.index_by(&:id)
    records_by_sequence = channel_records.group_by { |approval_record| approval_sequence_from_level(approval_record.data["approval_level"]) }
    saved_records = []

    steps.each do |step|
      level = step["approval_level"]
      approver = step["approver_approved_by"]
      next if approver.blank?

      sequence = approval_sequence_from_level(level)
      approval_record = records_by_id[step["record_id"].to_i] if step["record_id"].present?
      records_by_sequence.each_value { |records| records.delete(approval_record) } if approval_record
      approval_record ||= records_by_sequence[sequence]&.shift || ModuleRecord.new(module_slug: "approval-master")
      approval_record.data = data.merge(
        "approval_level" => level,
        "approver_approved_by" => approver,
        "status" => data["status"].presence || "Active"
      )
      approval_record.save!
      saved_records << approval_record
    end

    if saved_records.blank?
      @record = record
      @records = module_records
      prepare_approval_channel_form(record)
      flash.now[:alert] = "Please select at least one approval user."
      render :show, status: :unprocessable_entity
      return
    end

    stale_records = (channel_records - saved_records)
    stale_records.each(&:destroy)

    redirect_to module_path("approval-list"), notice: "Approval channel updated successfully."
  rescue ActiveRecord::RecordInvalid => e
    @record = record
    @records = module_records
    prepare_approval_channel_form(record)
    flash.now[:alert] = e.record.errors.full_messages.to_sentence
    render :show, status: :unprocessable_entity
  end

  def approval_channel_step_rows(raw_steps)
    steps = raw_steps.respond_to?(:to_h) ? raw_steps.to_h : {}

    steps.filter_map do |level_or_key, value|
      if value.respond_to?(:to_h)
        step_data = value.to_h
        {
          "record_id" => step_data["record_id"].to_s,
          "approval_level" => step_data["approval_level"].presence || level_or_key.to_s,
          "approver_approved_by" => step_data["approver_approved_by"].presence || step_data["approver"].to_s
        }
      else
        {
          "record_id" => "",
          "approval_level" => level_or_key.to_s,
          "approver_approved_by" => value.to_s
        }
      end
    end
  end

  def prepare_approval_channel_form(record)
    @approval_channel_records = approval_channel_records_for(record)
  end

  def approval_channel_records_for(record)
    return [] unless record

    data = record.data
    ModuleRecord
      .where(module_slug: "approval-master")
      .order(created_at: :asc)
      .select { |approval_record| same_approval_channel?(approval_record.data, data) }
  end

  def same_approval_channel?(left_data, right_data)
    ["module_name", "stakeholder_name", "user_name"].all? do |key|
      left_data[key].to_s.strip.casecmp(right_data[key].to_s.strip).zero?
    end
  end

  def user_hierarchy_list_rows(records)
    records.flat_map do |record|
      base = {
        id: record.id,
        edit_path: edit_module_record_path("user-hierarchy-mapping", record),
        stakeholder: record.data["stakeholder_category"].presence || "-",
        level_1_user: record.data["level_1_user"].presence || "-",
        status: record.data["status"].presence || "Active"
      }

      mappings = normalized_user_hierarchy_list_mappings(record)
      if mappings.blank?
        users = collapsed_hierarchy_users(record.data["level_2_users"].presence || record.data["level_2_user"], record.data["level_3_users"].presence || record.data["level_3_user"])
        users = users.select { |level_2_user| cluster_incharge_user_label?(level_2_user) }
        users.map { |level_2_user| base.merge(level_2_user: level_2_user) }
      else
        mappings
          .select { |mapping| cluster_incharge_user_label?(mapping["level_2_user"]) }
          .map { |mapping| base.merge(level_2_user: mapping["level_2_user"].presence || "-") }
      end
    end
  end

  def normalized_user_hierarchy_list_mappings(record)
    mappings = record.data["level_2_mappings"]
    mappings = mappings.values if mappings.is_a?(Hash)

    Array(mappings).filter_map do |mapping|
      next unless mapping.respond_to?(:[])

      collapsed_hierarchy_users(mapping["level_2_user"], mapping["level_3_users"]).map do |level_2_user|
        { "level_2_user" => level_2_user, "level_3_users" => [] }
      end
    end
      .flatten
  end

  def collapsed_hierarchy_users(*values)
    values.flatten.flat_map do |value|
      value.to_s.split(";").flat_map do |segment|
        user_segment = segment.include?("->") ? segment.split("->", 2).last : segment
        user_segment.to_s.split(",")
      end
    end.map(&:strip).compact_blank.uniq
  end

  def cluster_incharge_user_label?(label)
    role_text = label.to_s[/\(([^)]*)\)\s*\z/, 1].to_s
    role_text.downcase.include?("cluster")
  end

  # Hierarchy labels do not always contain the role in parentheses. In that
  # case resolve the matching registered User and inspect its saved role.
  def user_record_cluster_incharge_label?(label)
    return false unless model_ready?(:User)

    normalized_label = normalize_dashboard_user_label(label.to_s.sub(/\s*\([^)]*\)\s*\z/, ""))
    return false if normalized_label.blank?

    @user_record_cluster_incharge_label_cache ||= {}
    return @user_record_cluster_incharge_label_cache[normalized_label] if @user_record_cluster_incharge_label_cache.key?(normalized_label)

    @dashboard_cluster_role_users ||= User.order(:first_name, :last_name, :user_name).to_a
    @user_record_cluster_incharge_label_cache[normalized_label] = @dashboard_cluster_role_users.any? do |user|
      user_labels = [
        user.respond_to?(:full_name) ? user.full_name : nil,
        user.respond_to?(:user_name) ? user.user_name : nil,
        user.respond_to?(:name) ? user.name : nil
      ].compact_blank.map { |value| normalize_dashboard_user_label(value) }
      next false unless user_labels.include?(normalized_label)

      role = (user.respond_to?(:role_name) ? user.role_name : nil).presence ||
        (user.respond_to?(:role) ? user.role : nil)
      role.to_s.downcase.include?("cluster")
    end
  end

  def hierarchy_cluster_incharge_labels
    return @hierarchy_cluster_incharge_labels if defined?(@hierarchy_cluster_incharge_labels)
    return @hierarchy_cluster_incharge_labels = [] unless model_ready?(:ModuleRecord)

    @hierarchy_cluster_incharge_labels = active_module_records_scope("user-hierarchy-mapping")
      .order(created_at: :desc)
      .flat_map { |record| user_hierarchy_list_rows([record]).map { |row| row[:level_2_user] } }
      .select { |label| cluster_incharge_user_label?(label) }
      .compact_blank
      .uniq
  end

  def jeevika_jankar_cluster_rows
    return [] unless model_ready?(:Vrp)

    mapped_cluster_labels = hierarchy_cluster_incharge_labels.compact_blank.uniq

    Vrp.where.not(cluster_incharge: [nil, ""]).order(updated_at: :desc, id: :desc).filter_map do |vrp|
      next if mapped_cluster_labels.any? && !mapped_cluster_labels.any? { |label| cluster_label_matches?(label, vrp.cluster_incharge) }

      {
        id: vrp.id,
        name: vrp.name.presence || vrp.user_name.presence || "Jeevika Jankar ##{vrp.id}",
        user_name: vrp.user_name.presence || "-",
        mobile_no: vrp.mobile_no.presence || "-",
        office_name: vrp.fcoc.presence || vrp.to_name.presence || "-",
        cluster_incharge: vrp.cluster_incharge.presence || "-",
        status: vrp_status_for_hierarchy_list(vrp)
      }
    end
  end

  def vrp_status_for_hierarchy_list(vrp)
    return "Inactive" if vrp.respond_to?(:is_active) && vrp.is_active == false
    return "Final Approved" if vrp.status.to_i == 55
    return "Pending Approval" if vrp.status.to_i >= 25

    "Active"
  end

  def valid_module_data?(data)
    module_data_error_messages(data).blank?
  end

  def module_data_error_messages(data)
    case record_source_slug
    when "new-user"
      data["password"].to_s == data["confirmed_password"].to_s ? [] : ["Password and Confirmed Password must match."]
    when "training-form"
      training_form_error_messages(data)
    when "add-farmer-form"
      add_farmer_form_error_messages(data)
    when "jeevika-jankar-bill-process"
      jeevika_jankar_bill_error_messages(data)
    when *OTHER_TARGET_MODULE_SLUGS
      seed_distribution_target_error_messages(data)
    else
      []
    end
  end

  def training_form_error_messages(data)
    required_fields = {
      "month" => "Month",
      "ics_block" => "ICS Name",
      "gram_name" => "Village Name",
      "fco_name" => "FCO Name",
      "trainer_name" => "Trainer Name",
      "trainer_contact" => "Trainer Contact",
      "training_date" => "Training Date",
      "training_location" => "Training Location",
      "main_activity" => "Main Activity",
      "sub_activity" => "Sub Activity",
      "training_method" => "Training Method",
      "training_description" => "Training Description",
      "male_count" => "Male Count",
      "female_count" => "Female Count",
      "next_farmer_training_date" => "Next Farmer Training Date",
      "training_register_upload" => "Training Register Upload",
      "training_photo_upload_with_geo_tag" => "Training Photo Upload with Geo Tag"
    }

    errors = missing_required_data_errors(data, required_fields)
    selected_farmer_ids = Array(data["selected_farmer_ids"]).map(&:to_s).reject(&:blank?).uniq

    farmer_count = whole_number_value(data["farmer_count"].presence || "0")
    male_count = whole_number_value(data["male_count"])
    female_count = whole_number_value(data["female_count"])
    total_farmer_count = whole_number_value(data["total_farmer_count"].presence || training_total_farmer_count(data).to_s)

    errors << "Target Farmers select karein." if selected_farmer_ids.blank?
    errors << "Farmer Count valid whole number hona chahiye." if farmer_count.nil?
    errors << "Male Count valid whole number hona chahiye." if male_count.nil?
    errors << "Female Count valid whole number hona chahiye." if female_count.nil?
    errors << "Total Farmer Count valid whole number hona chahiye." if total_farmer_count.nil?

    if farmer_count && selected_farmer_ids.any? && farmer_count != selected_farmer_ids.size
      errors << "Farmer Count selected farmers ke count ke equal hona chahiye."
    end

    errors
  end

  def jeevika_jankar_bill_error_messages(data)
    errors = missing_required_data_errors(
      data,
      "bill_month" => "Bill Month",
      "financial_year" => "Financial Year",
      "select_vrp" => "Jeevika Jankar Name"
    )
    return errors if errors.any?

    total_payment = decimal_value(data["grand_total"])
    errors << "Total Payment valid amount hona chahiye." if total_payment.nil?
    errors << "Total Payment zero se jyada hona chahiye." if total_payment && total_payment <= 0
    payment_differs_from_standard = total_payment && (total_payment - JEEVIKA_JANKAR_BILL_FIXED_TOTAL).abs > 0.005
    if payment_differs_from_standard && data["remarks"].to_s.strip.blank?
      errors << "Total Payment ₹#{JEEVIKA_JANKAR_BILL_FIXED_TOTAL.to_i} se kam ya jyada hone par Remarks required hai."
    end

    duplicate = ModuleRecord
      .where(module_slug: "jeevika-jankar-bill-process")
      .detect do |record|
        jeevika_jankar_bill_blocks_duplicate?(record) &&
          normalize_dashboard_text(record.data["select_vrp"]) == normalize_dashboard_text(data["select_vrp"]) &&
          normalize_dashboard_text(record.data["bill_month"]) == normalize_dashboard_text(data["bill_month"])
      end

    if duplicate
      name = jeevika_jankar_display_name(data["select_vrp_name"].presence || jeevika_jankar_vrp_label(data["select_vrp"])).presence || "Selected Jeevika Jankar"
      errors << "#{name} ka #{data["bill_month"]} month ka bill already bana hua hai."
    end

    errors
  end

  def seed_distribution_target_error_messages(data)
    errors = missing_required_data_errors(
      data,
      "jeevika_jankar_name" => "Jeevika Jankar Name",
      "contact_number" => "Contact Number",
      "month" => "Month",
      "ics" => "ICS",
      "village" => "Village",
      "training_topic" => "Main Activity",
      "training_subject" => "Sub Activity",
      "completion_date" => "Completion Date",
      "target" => "Target",
      "achievement" => "Achievement"
    )

    target = decimal_value(data["target"])
    achievement = decimal_value(data["achievement"])
    errors << "Target valid number hona chahiye." if target.nil?
    errors << "Achievement valid number hona chahiye." if achievement.nil?
    errors << "Target zero se kam nahi ho sakta." if target && target.negative?
    errors << "Achievement zero se kam nahi ho sakta." if achievement && achievement.negative?
    errors << "Achievement Target se jyada nahi ho sakta." if target && achievement && achievement > target

    target_mapping = seed_distribution_target_match(data)
    new_farmer_target = target_mapping&.dig(:new_farmer_target)
    farmer_count = whole_number_value(data["farmer_count"])
    selected_farmer_ids = Array(data["selected_farmer_ids"]).map(&:to_s).reject(&:blank?).uniq
    unless new_farmer_target || record_source_slug == "other-target"
      errors << "Farmer Count required hai." if data["farmer_count"].blank?
      errors << "Mapped Farmers select karein." if selected_farmer_ids.blank?
      errors << "Farmer Count valid whole number hona chahiye." if farmer_count.nil?
      errors << "Farmer Count selected farmers ke count ke equal hona chahiye." if farmer_count && selected_farmer_ids.any? && farmer_count != selected_farmer_ids.size
      errors << "Farmer Count Target se jyada nahi ho sakta." if target && farmer_count && farmer_count > target
    end

    errors << "Mapped Other activity target select karein." if target_mapping.blank?
    errors << "Contact Number valid 10 digit hona chahiye." if data["contact_number"].present? && data["contact_number"].to_s.gsub(/\D/, "").length != 10
    errors
  end

  def missing_required_data_errors(data, fields)
    fields.filter_map do |key, label|
      "#{label} required hai." if data[key].blank?
    end
  end

  def whole_number_value(value)
    string = value.to_s.strip
    return nil if string.blank? || !string.match?(/\A\d+\z/)

    string.to_i
  end

  def decimal_value(value)
    string = value.to_s.strip
    return nil if string.blank?

    BigDecimal(string)
  rescue ArgumentError
    nil
  end

  def store_uploaded_module_file(upload)
    upload_dir = Rails.root.join("public", "uploads", "module_records")
    FileUtils.mkdir_p(upload_dir)

    extension = File.extname(upload.original_filename)
    basename = File.basename(upload.original_filename, extension).parameterize
    filename = "#{Time.current.to_i}-#{SecureRandom.hex(4)}-#{basename}#{extension.downcase}"
    path = upload_dir.join(filename)

    if upload.respond_to?(:tempfile) && upload.tempfile
      upload.tempfile.rewind
      IO.copy_stream(upload.tempfile, path)
    else
      File.binwrite(path, upload.read)
    end
    "/uploads/module_records/#{filename}"
  end

  def module_select_field?(field)
    return false if current_slug == "training-topic-mapping" && ["Department", "Training Topic", "Training Subject"].include?(field)
    return false if record_source_slug == "training-form" && ["Trainee Department", "FCO Name", "External Input", "PAPL Staff Name"].include?(field)
    return false if other_target_record_source? && field == "Department"
    return true if current_slug == "parent-office-add" && field == "Parent Office"
    return true if training_target_field?(field)
    return true if training_people_field?(field)
    return true if training_activity_field?(field)
    return true if seed_distribution_target_field?(field)

    source = field_sources[field]
    (source.present? && source[:module] != (@slug || current_slug)) || static_field_options(field).any?
  end

  def module_field_options(field)
    return parent_office_parent_options if current_slug == "parent-office-add" && field == "Parent Office"
    return training_target_field_options(field) if training_target_field?(field)
    return training_people_field_options(field) if training_people_field?(field)
    return training_activity_field_options(field) if training_activity_field?(field)
    return seed_distribution_target_field_options(field) if seed_distribution_target_field?(field)

    source = field_sources[field]
    return [] unless ModuleRecord.table_exists?

    if source
      return [] if source[:module] == (@slug || current_slug)

      return values_from_module(source[:module], source[:field])
    end

    generic_field_options(field)
  end

  def training_target_field?(field)
    record_source_slug == "training-form" && ["Month", "ICS / Block", "Gram Name"].include?(field)
  end

  def training_activity_field?(field)
    record_source_slug == "training-form" && ["Main Activity", "Sub Activity"].include?(field)
  end

  def training_people_field?(field)
    record_source_slug == "training-form" && ["Cluster Coordinator Name", "Agronomist Name", "PAPL Staff Name"].include?(field)
  end

  def training_people_field_options(field)
    case field
    when "Cluster Coordinator Name"
      cluster_coordinator_options
    when "Agronomist Name"
      agronomist_options
    when "PAPL Staff Name"
      papl_staff_options
    else
      []
    end
  end

  def cluster_coordinator_options
    return training_people_options_for_current_vrp(:cluster_coordinator) if vrp_login_user?

    (
      registered_user_options_matching(/cluster/i) +
      registered_vrp_cluster_names
    ).compact_blank.uniq.unshift("N/A").uniq
  end

  def agronomist_options
    return training_people_options_for_current_vrp(:agronomist) if vrp_login_user?

    registered_user_options_matching(/agronomist/i).compact_blank.uniq.unshift("N/A").uniq
  end

  def papl_staff_options
    (
      registered_app_user_names +
      registered_module_user_names
    ).compact_blank
      .select { |name| papl_staff_option_allowed?(name) }
      .uniq { |name| normalize_dashboard_text(name) }
      .unshift("N/A")
      .uniq
  end

  def training_people_options_for_current_vrp(kind)
    values = ["N/A"]
    vrp = current_vrp_record

    case kind
    when :cluster_coordinator
      values << vrp&.cluster_incharge
    when :agronomist
      values << current_vrp_creator_name(vrp)
    when :papl_staff
      values << current_app_user&.dig("name").presence || current_app_user&.dig("username")
    end

    values.map(&:to_s).map(&:strip).reject(&:blank?).uniq { |name| normalize_dashboard_text(name) }
  end

  def current_vrp_creator_name(vrp)
    return if vrp.blank? || vrp.created_by_id.blank?

    if model_ready?(:User)
      user = cached_user_find_by(id: vrp.created_by_id)
      label = user&.full_name.presence || user&.user_name.presence
      return label if label.present?
    end

    if model_ready?(:ModuleRecord)
      record = cached_module_record_find_by_id(vrp.created_by_id)
      label = [
        [record&.data&.[]("first_name"), record&.data&.[]("last_name")].compact_blank.join(" "),
        record&.data&.[]("user_name"),
        record&.data&.[]("name")
      ].compact_blank.first
      return label if label.present?
    end

    nil
  end

  def seed_distribution_target_field?(field)
    other_target_record_source? && ["Jeevika Jankar Name", "Month", "ICS", "Village", "Main Activity", "Sub Activity"].include?(field)
  end

  def seed_distribution_target_field_options(field)
    case field
    when "Jeevika Jankar Name"
      (
        seed_distribution_target_mappings.filter_map { |mapping| mapping[:jeevika_jankar_name].presence } +
        [current_seed_target_vrp_option&.dig(:label)]
      ).compact_blank.uniq
    when "Month"
      seed_distribution_target_month_options
    when "ICS"
      seed_distribution_target_mappings.filter_map { |mapping| mapping[:ics].presence }.uniq
    when "Village"
      seed_distribution_target_mappings.filter_map { |mapping| mapping[:village].presence }.uniq
    when "Main Activity"
      seed_distribution_target_mappings.filter_map { |mapping| mapping[:training_topic].presence }.uniq
    when "Sub Activity"
      seed_distribution_target_mappings.filter_map { |mapping| mapping[:training_subject].presence }.uniq
    else
      []
    end
  end

  def training_target_field_options(field)
    case field
    when "Month"
      training_target_month_options
    when "ICS / Block"
      training_target_mappings.filter_map { |mapping| mapping[:ics].presence }.uniq
    when "Gram Name"
      training_target_mappings.filter_map { |mapping| mapping[:village].presence }.uniq
    else
      []
    end
  end

  def training_activity_field_options(field)
    case field
    when "Main Activity"
      training_target_mappings.filter_map { |mapping| mapping[:main_activity].presence }.uniq
    when "Sub Activity"
      training_target_mappings.filter_map { |mapping| mapping[:sub_activity].presence }.uniq
    else
      []
    end
  end

  def training_activity_mappings
    return [] unless model_ready?(:ModuleRecord)

    ModuleRecord
      .where(module_slug: "training-topic-mapping")
      .order(created_at: :desc)
      .select { |record| active_module_record?(record) }
      .map do |record|
        {
          department: first_present_data(record, "department", "trainee_department").to_s.strip,
          training_topic: first_present_data(record, "training_topic", "topic").to_s.strip,
          training_subject: first_present_data(record, "training_subject", "subject").to_s.strip
        }
      end
      .reject { |mapping| mapping.values.all?(&:blank?) }
      .uniq
  end

  def training_activity_setup_mappings
    activity_settings = jeevika_jankar_main_activity_settings
    sub_activities_by_main = training_setup_sub_activities_by_main

    activity_settings.filter_map do |normalized_name, setting|
      next unless training_main_activity_type?(setting[:main_activity_type])

      main_activity = setting[:main_activity_name].presence || normalized_name
      {
        main_activity: main_activity,
        main_activity_type: "Training",
        sub_activities: sub_activities_by_main[normalized_name] || []
      }
    end
  end

  def training_target_mappings
    @training_target_mappings ||= build_training_target_mappings
  end

  def build_training_target_mappings
    return [] unless model_ready?(:TargetMapping)

    activity_settings = jeevika_jankar_main_activity_settings
    sub_activity_settings = jeevika_jankar_sub_activity_settings(activity_settings)

    targets = training_target_scope
      .includes(:vrp)
      .order(:ics_name, :ics_id, :village_name, :village_id, :id)
      .to_a
      .select do |target|
        activity_setting = jeevika_jankar_activity_setting_for(target, activity_settings, sub_activity_settings)
        activity_setting.present? && training_main_activity_type?(activity_setting[:main_activity_type])
      end

    targets
      .map do |target|
        farmer_ids = Array(target.afl_ids).map(&:to_s).reject(&:blank?).uniq
        {
          target_mapping_id: target.id.to_s,
          vrp_id: target.vrp_id.to_s,
          jeevika_jankar_name: target.vrp&.name.presence || target.vrp&.user_name.presence || "Jeevika Jankar ##{target.vrp_id}",
          contact_number: target.vrp&.mobile_no.to_s.gsub(/\D/, "").last(10),
          month: target.month_name.to_s.strip,
          ics: target.ics_name.presence || target.ics_id,
          village: target.village_name.presence || target.village_id,
          main_activity_type: "Training",
          main_activity: target.main_activity_name.to_s.strip,
          sub_activity: target.activity_name.to_s.strip,
          new_farmer_target: new_farmer_target_mapping?(target),
          farmer_ids: farmer_ids,
          completed_farmer_ids: [],
          farmers: []
        }
      end
      .reject { |mapping| mapping[:ics].blank? && mapping[:village].blank? }
      .uniq
  end

  def seed_distribution_target_mappings
    return [] unless model_ready?(:TargetMapping)

    activity_settings = jeevika_jankar_main_activity_settings
    sub_activity_settings = jeevika_jankar_sub_activity_settings(activity_settings)

    targets = training_target_scope
      .includes(:vrp)
      .order(:ics_name, :ics_id, :village_name, :village_id, :id)
      .to_a
    include_farmer_payload = @record.present? && record_source_slug != "other-target"
    preload_other_target_completed_farmer_ids!(targets) if include_farmer_payload
    preload_training_farmers_for_targets!(targets) if include_farmer_payload

    targets
      .filter_map do |target|
        activity_setting = jeevika_jankar_activity_setting_for(target, activity_settings, sub_activity_settings)
        next unless activity_setting.present? && !training_main_activity_type?(activity_setting[:main_activity_type])

        farmer_ids = record_source_slug == "other-target" ? [] : target_farmer_ids(target)
        {
          target_mapping_id: target.id.to_s,
          vrp_id: target.vrp_id.to_s,
          jeevika_jankar_name: target.vrp&.name.presence || target.vrp&.user_name.presence || "Jeevika Jankar ##{target.vrp_id}",
          contact_number: target.vrp&.mobile_no.to_s.gsub(/\D/, "").last(10),
          department: registered_vrp_fcoc(target.vrp),
          month: target.month_name.to_s.strip,
          ics: target.ics_name.presence || target.ics_id,
          village: target.village_name.presence || target.village_id,
          main_activity_type: "Other",
          training_topic: target.main_activity_name.to_s.strip,
          training_subject: target.activity_name.to_s.strip,
          target: target.target_quantity.to_s,
          new_farmer_target: new_farmer_target_mapping?(target),
          completed_farmer_ids: include_farmer_payload ? other_target_completed_farmer_ids_for(target.id) : [],
          farmers: include_farmer_payload ? training_farmers_for_ids(farmer_ids) : []
        }
      end
      .reject { |mapping| mapping[:ics].blank? && mapping[:village].blank? }
      .uniq
  end

  def training_main_activity_type?(value)
    normalize_dashboard_text(value.presence || "Training") == normalize_dashboard_text("Training")
  end

  def other_target_completed_farmer_ids_for(target_mapping_id)
    return [] unless model_ready?(:ModuleRecord)

    if defined?(@other_target_completed_farmer_ids_by_target) && @other_target_completed_farmer_ids_by_target.key?(target_mapping_id.to_s)
      return Array(@other_target_completed_farmer_ids_by_target[target_mapping_id.to_s])
    end

    targets = model_ready?(:TargetMapping) ? TargetMapping.where(id: target_mapping_id).to_a : []
    preload_other_target_completed_farmer_ids!(targets)
    Array(@other_target_completed_farmer_ids_by_target[target_mapping_id.to_s])
  end

  def preload_other_target_completed_farmer_ids!(targets)
    targets_by_id = Array(targets).index_by { |target| target.id.to_s }
    @other_target_completed_farmer_ids_by_target ||= {}
    return @other_target_completed_farmer_ids_by_target if targets_by_id.blank?

    missing_targets_by_id = targets_by_id.reject { |id, _target| @other_target_completed_farmer_ids_by_target.key?(id) }
    return @other_target_completed_farmer_ids_by_target if missing_targets_by_id.blank?

    records = ModuleRecord
      .where(module_slug: record_source_slug)
      .order(created_at: :asc)
      .reject { |record| record.id.to_s == params[:id].to_s }
      .select { |record| blocking_other_target_record?(record) }

    records_by_target = index_other_target_records_by_target(records, Hash.new { |hash, key| hash[key] = [] }, target_ids: missing_targets_by_id.keys)

    @other_target_completed_farmer_ids_by_target.merge!(missing_targets_by_id.transform_values do |target|
      mapped_farmer_ids = target_farmer_ids(target)
      completed_ids = Array(records_by_target[target.id.to_s]).map(&:to_s).reject(&:blank?).uniq
      mapped_farmer_ids.present? ? (completed_ids & mapped_farmer_ids) : completed_ids
    end)
  end

  def blocking_other_target_record?(record)
    return false if truthy_module_flag?(record.data["deleted"]) ||
      truthy_module_flag?(record.data["is_deleted"]) ||
      truthy_module_flag?(record.data["discarded"])

    status = record.data["approval_status"].presence || record.data["approval_state"].presence || record.data["status"].presence
    return true if status.blank?

    normalized_status = normalize_dashboard_text(status)
    return false if normalized_status.include?("reject") ||
      normalized_status.include?("return") ||
      normalized_status == "inactive"

    true
  end

  def training_target_month_options
    target_months = if model_ready?(:TargetMapping)
      training_target_scope
        .where.not(month_name: [nil, ""])
        .distinct
        .pluck(:month_name)
    else
      []
    end

    master_months = active_month_master_rows.filter_map { |record| record.data["month_name"].presence }

    (master_months + target_months)
      .map(&:to_s)
      .map(&:strip)
      .reject(&:blank?)
      .uniq
      .sort_by { |month| [dashboard_month_index(month), month] }
  end

  def seed_distribution_target_month_options
    target_months = if model_ready?(:TargetMapping)
      training_target_scope
        .where.not(month_name: [nil, ""])
        .distinct
        .pluck(:month_name)
    else
      []
    end
    master_months = active_month_master_rows.filter_map { |record| record.data["month_name"].presence }

    (master_months + target_months)
      .map(&:to_s)
      .map(&:strip)
      .reject(&:blank?)
      .uniq
      .sort_by { |month| [dashboard_month_index(month), month] }
  end

  def current_seed_target_vrp_option
    return nil unless vrp_login_user? && current_vrp_record.present?

    {
      value: current_vrp_record.id.to_s,
      label: current_vrp_record.name.presence || current_vrp_record.user_name.presence || "Jeevika Jankar ##{current_vrp_record.id}",
      contact_number: current_vrp_record.mobile_no.to_s.gsub(/\D/, "").last(10),
      department: registered_vrp_fcoc(current_vrp_record)
    }
  end

  def training_target_scope
    scope = TargetMapping.all
    scope = scope.where(vrp_id: current_vrp_record.id) if vrp_login_user? && current_vrp_record.present?
    scope = scope.where(vrp_id: module_cluster_visible_vrp_ids) if module_mapped_vrp_scope_active?
    scope
  end

  def completed_training_farmer_ids_for(target, farmer_ids)
    farmer_ids = Array(farmer_ids).map(&:to_s).reject(&:blank?).uniq
    return [] if farmer_ids.blank?
    return [] unless model_ready?(:ModuleRecord)

    # Target progress is calculated repeatedly while rendering a dashboard.
    # Restrict the candidate records to this target's month and VRP instead of
    # scanning every training form in the system once for every target row.
    training_records_matching_dashboard_target(target, farmer_ids)
      .flat_map { |record| training_record_selected_farmer_ids(record) & farmer_ids }
      .uniq
  end

  def dashboard_training_completion_records
    return @dashboard_training_completion_records if defined?(@dashboard_training_completion_records)

    @dashboard_training_completion_records = ModuleRecord
      .where(module_slug: "training-form")
      .order(created_at: :desc)
      .select { |record| active_module_record?(record) }
      .select { |record| training_record_countable?(record) }
  end

  def training_record_countable?(record)
    statuses = [
      record.data["status"],
      record.data["approval_status"],
      record.data["approval_state"]
    ].map { |value| normalize_dashboard_text(value) }.reject(&:blank?)

    statuses.none? do |status|
      status.include?("reject") || status.include?("return") || status == "inactive"
    end
  end

  def completed_training_farmer_ids_for_target_deadline(target, farmer_ids)
    farmer_ids = Array(farmer_ids).map(&:to_s).reject(&:blank?).uniq
    return [] if farmer_ids.blank?
    return completed_training_farmer_ids_for(target, farmer_ids) if target.completion_date.blank?
    return [] unless model_ready?(:ModuleRecord)

    matching_training_records_for_target(target, farmer_ids)
      .flat_map { |record| training_record_selected_farmer_ids(record) & farmer_ids }
      .uniq
  end

  def matching_training_records_for_target(target, farmer_ids)
    @matching_training_records_for_target_cache ||= {}
    cache_key = [target.id, target.completion_date.to_s]
    return @matching_training_records_for_target_cache[cache_key] if @matching_training_records_for_target_cache.key?(cache_key)

    @matching_training_records_for_target_cache[cache_key] = training_records_matching_dashboard_target(target, farmer_ids)
      .select { |record| training_record_within_completion_date?(record, target.completion_date) }
  end

  # Reuse the target's already month/VRP-scoped records. The former path
  # scanned every training form for every target row, which was the dominant
  # CPU cost on large dashboard requests.
  def training_records_matching_dashboard_target(target, farmer_ids)
    @training_records_matching_dashboard_target_cache ||= {}
    cache_key = target.id.to_s
    return @training_records_matching_dashboard_target_cache[cache_key] if @training_records_matching_dashboard_target_cache.key?(cache_key)

    @training_records_matching_dashboard_target_cache[cache_key] = dashboard_training_form_records([target], farmer_ids)
      .select { |record| training_record_matches_dashboard_target?(record, target, farmer_ids) }
  end

  def training_record_within_completion_date?(record, completion_date)
    @training_record_deadline_cache ||= {}
    cache_key = [record.id, completion_date.to_s]
    return @training_record_deadline_cache[cache_key] if @training_record_deadline_cache.key?(cache_key)

    deadline = parse_module_date(completion_date)
    return @training_record_deadline_cache[cache_key] = true if deadline.blank?

    record_date = parse_module_date(training_summary(record)[:training_date]) ||
      (record.created_at.to_date if record.respond_to?(:created_at) && record.created_at.present?)
    return @training_record_deadline_cache[cache_key] = false if record_date.blank?

    @training_record_deadline_cache[cache_key] = record_date <= deadline
  end

  def training_completion_index
    return @training_completion_index if defined?(@training_completion_index)

    @training_completion_index = Hash.new { |hash, key| hash[key] = [] }
    return @training_completion_index unless model_ready?(:ModuleRecord)

    records = dashboard_training_completion_records

    records.each do |record|
      next if @record&.id.present? && record.id == @record.id

      summary = training_summary(record)
      key = training_activity_key(summary[:month], summary[:training_topic], summary[:training_subject])
      next if key.all?(&:blank?)

      @training_completion_index[key] |= training_record_selected_farmer_ids(record)
    end

    @training_completion_index
  end

  def training_activity_key(month, main_activity, sub_activity = nil)
    [
      normalize_dashboard_text(month),
      normalize_dashboard_text(main_activity),
      normalize_dashboard_text(sub_activity)
    ]
  end

  def training_farmers_for_ids(farmer_ids)
    return [] unless model_ready?(:Afl)

    farmer_ids = Array(farmer_ids).map(&:to_s).reject(&:blank?).uniq
    return [] if farmer_ids.blank?

    farmers_by_id = training_farmers_by_id(farmer_ids)
    resolved_farmers = farmers_by_id
      .values
      .map do |farmer|
        {
          id: farmer.id.to_s,
          farmer_name: dashboard_text_value(farmer.farmer_name).presence || "Farmer ##{farmer.id}",
          father_name: dashboard_text_value(farmer.father_name),
          tracenet_no: dashboard_text_value(farmer.tracenet_no),
          mobile_no: dashboard_text_value(farmer.mobile_no),
          khasara_no: dashboard_text_value(farmer.khasara_no)
        }
      end

    # Older target mappings can retain valid target IDs after AFL master data is
    # re-imported with new database IDs. Keep those original mapped IDs visible
    # and selectable so training completion continues against the saved target.
    missing_farmers = farmer_ids.reject { |farmer_id| farmers_by_id.key?(farmer_id) }.map do |farmer_id|
      {
        id: farmer_id,
        farmer_name: "Mapped Farmer ##{farmer_id}",
        father_name: nil,
        tracenet_no: nil,
        mobile_no: nil,
        khasara_no: nil,
        record_missing: true
      }
    end

    (resolved_farmers + missing_farmers).sort_by do |farmer|
      [farmer[:record_missing] ? 1 : 0, farmer[:farmer_name].to_s.downcase, farmer[:id].to_i]
    end
  end

  def role_management_mappings
    return [] unless model_ready?(:ModuleRecord)

    stakeholder_role_mappings = ModuleRecord
      .where(module_slug: "stakeholder-role")
      .order(created_at: :desc)
      .select { |record| active_module_record?(record) }
      .flat_map do |record|
        stakeholder_role = first_present_data(record, "stakeholder_role").to_s.strip
        parent_office = first_present_data(record, "parent_office", "parent_category", "office_name", "office").to_s.strip
        office_name = first_present_data(record, "office_name", "office").to_s.strip
        mapping_labels_for_option(stakeholder_role, :stakeholder_role).map do |stakeholder_role_label|
          {
            stakeholder: first_present_data(record, "stakeholder_category", "stakeholder_name", "stakeholder").to_s.strip,
            stakeholder_role: stakeholder_role,
            stakeholder_role_label: stakeholder_role_label,
            parent_office: parent_office,
            office_category: parent_office,
            office_name: office_name,
            office: office_name,
            role: "",
            role_label: "",
            role_name: "",
            role_name_label: "",
            user_management_role: "",
            user_management_role_label: "",
            person_type: "",
            person_type_label: ""
          }
        end
      end

    role_mappings = ModuleRecord
      .where(module_slug: "role-name")
      .order(created_at: :desc)
      .select { |record| active_module_record?(record) }
      .flat_map do |record|
        role = first_present_data(record, "role_name").to_s.strip
        mapping_labels_for_option(role, :role).map do |role_label|
          {
            stakeholder: first_present_data(record, "stakeholder_category", "stakeholder_name", "stakeholder").to_s.strip,
            stakeholder_role: first_present_data(record, "stakeholder_role").to_s.strip,
            role: role,
            role_label: role_label,
            role_name: "",
            role_name_label: "",
            user_management_role: "",
            user_management_role_label: "",
            person_type: ""
          }
        end
      end

    user_management_role_mappings = ModuleRecord
      .where(module_slug: "user-management-role")
      .order(created_at: :desc)
      .select { |record| active_module_record?(record) }
      .flat_map do |record|
        user_management_role = first_present_data(record, "user_management_role").to_s.strip
        mapping_labels_for_option(user_management_role, :user_management_role).map do |user_management_role_label|
          {
            stakeholder: first_present_data(record, "stakeholder_category", "stakeholder_name", "stakeholder").to_s.strip,
            stakeholder_role: first_present_data(record, "stakeholder_role").to_s.strip,
            role: first_present_data(record, "role", "role_name").to_s.strip,
            role_name: "",
            role_name_label: "",
            user_management_role: user_management_role,
            user_management_role_label: user_management_role_label,
            person_type: ""
          }
        end
      end

    person_type_mappings = ModuleRecord
      .where(module_slug: "person-type")
      .order(created_at: :desc)
      .select { |record| active_module_record?(record) }
      .flat_map do |record|
        role = first_present_data(record, "role", "role_name").to_s.strip
        user_management_role = first_present_data(record, "user_management_role").to_s.strip
        person_type = first_present_data(record, "person_type").to_s.strip
        joined_type_labels(role, user_management_role, person_type).map do |person_type_label|
          {
            stakeholder: first_present_data(record, "stakeholder_category", "stakeholder_name", "stakeholder").to_s.strip,
            stakeholder_role: first_present_data(record, "stakeholder_role").to_s.strip,
            role: role,
            role_name: "",
            role_name_label: "",
            user_management_role: user_management_role,
            person_type: person_type,
            person_type_label: person_type_label
          }
        end
      end

    (stakeholder_role_mappings + role_mappings + user_management_role_mappings + person_type_mappings)
      .reject { |mapping| mapping[:stakeholder_role].blank? && mapping[:role].blank? && mapping[:role_name].blank? && mapping[:user_management_role].blank? && mapping[:person_type].blank? }
      .uniq
  end

  def label_with_registered_name(value, attribute)
    mapping_labels_for_option(value, attribute).first.to_s
  end

  def access_control_field_options(field, selected_value = nil)
    key = case field
    when "Stakeholder"
      :stakeholder
    when "Stakeholder Role"
      :stakeholder_role
    when "Role Name", "Role"
      :role
    when "Jeevika Jankar Type"
      return (module_field_options("Jeevika Jankar Type") + [selected_value]).compact_blank.uniq
    end
    return [] unless key

    options = access_control_role_mappings.filter_map { |mapping| mapping[key].presence }
    options << selected_value if selected_value.present?
    options.compact_blank.uniq
  end

  def access_control_role_mappings
    registered_access_users
      .filter_map do |data|
        stakeholder = data["stakeholder"].to_s.strip
        stakeholder_role = data["stakeholder_role"].to_s.strip
        role = (data["role"].presence || data["role_name"]).to_s.strip
        next if stakeholder.blank? || stakeholder_role.blank? || role.blank?

        {
          stakeholder: stakeholder,
          stakeholder_role: stakeholder_role,
          stakeholder_role_label: stakeholder_role,
          role: role,
          role_label: role,
          role_name: "",
          role_name_label: "",
          user_management_role: data["user_management_role"].to_s.strip,
          user_management_role_label: data["user_management_role"].to_s.strip,
          person_type: data["person_type"].to_s.strip,
          person_type_label: data["person_type"].to_s.strip
        }
      end
      .uniq
  end

  def registered_access_users
    registered_access_user_model_rows + registered_access_module_rows
  end

  def registered_access_user_model_rows
    return [] unless model_ready?(:User)

    User.order(updated_at: :desc).filter_map do |user|
      status = user.respond_to?(:status) ? user.status.to_s : "Active"
      next if status.casecmp("Inactive").zero?

      {
        "stakeholder" => user.stakeholder,
        "stakeholder_role" => user.stakeholder_role,
        "role" => user.role,
        "role_name" => user.respond_to?(:role_name) ? user.role_name : nil,
        "user_management_role" => user.respond_to?(:user_management_role) ? user.user_management_role : nil,
        "person_type" => user.respond_to?(:person_type) ? user.person_type : nil
      }
    end
  end

  def registered_access_module_rows
    return [] unless model_ready?(:ModuleRecord)

    active_module_records_scope("new-user")
      .order(updated_at: :desc)
      .map(&:data)
  end

  def mapping_labels_for_option(value, attribute)
    return [] if value.blank?

    [value]
  end

  def joined_type_labels(role, user_management_role, person_type)
    base = [role, user_management_role, person_type].compact_blank.join("-")
    return [] if base.blank?
    [base]
  end

  def registered_names_for_option(attribute, value)
    return [] if value.blank?

    (
      registered_vrp_names_for_option(attribute, value) +
      registered_user_names_for_option(attribute, value) +
      registered_module_user_names_for_option(attribute, value)
    ).compact_blank.uniq
  end

  def registered_user_options_matching(pattern)
    (
      registered_app_user_rows_matching(pattern) +
      registered_module_user_rows_matching(pattern)
    ).compact_blank.uniq
  end

  def registered_app_user_rows_matching(pattern)
    return [] unless model_ready?(:User)

    User.order(updated_at: :desc).filter_map do |user|
      values = [
        user.try(:role),
        user.try(:role_name),
        user.try(:stakeholder_role),
        user.try(:user_management_role),
        user.try(:person_type)
      ].map(&:to_s)
      next unless values.any? { |value| value.match?(pattern) }

      user.full_name.presence || user.user_name.presence
    end
  end

  def registered_module_user_rows_matching(pattern)
    return [] unless model_ready?(:ModuleRecord)

    active_module_records_scope("new-user")
      .order(updated_at: :desc)
      .filter_map do |record|
        values = [
          record.data["role"],
          record.data["role_name"],
          record.data["stakeholder_role"],
          record.data["user_management_role"],
          record.data["person_type"]
        ].map(&:to_s)
        next unless values.any? { |value| value.match?(pattern) }

        [record.data["first_name"], record.data["last_name"]].compact_blank.join(" ").presence || record.data["user_name"].presence
      end
  end

  def registered_vrp_cluster_names
    return [] unless model_ready?(:Vrp)
    return [] unless Vrp.column_names.include?("cluster_incharge")

    Vrp.order(updated_at: :desc).pluck(:cluster_incharge).compact_blank.uniq
  end

  def registered_app_user_names
    return [] unless model_ready?(:User)

    User.order(updated_at: :desc).filter_map { |user| user.full_name.presence || user.user_name.presence }
  end

  def registered_module_user_names
    return [] unless model_ready?(:ModuleRecord)

    active_module_records_scope("new-user")
      .order(updated_at: :desc)
      .filter_map { |record| [record.data["first_name"], record.data["last_name"]].compact_blank.join(" ").presence || record.data["user_name"].presence }
  end

  def papl_staff_option_allowed?(name)
    normalized_name = normalize_dashboard_text(name)
    normalized_name.present? && normalized_name != "admin"
  end

  def registered_vrp_names_for_option(attribute, value)
    return [] unless model_ready?(:Vrp)
    return [] unless Vrp.column_names.include?(attribute.to_s)

    Vrp.where(attribute => value).order(updated_at: :desc).filter_map { |vrp| vrp.name.presence }
  end

  def registered_user_names_for_option(attribute, value)
    return [] unless model_ready?(:User)
    return [] unless User.column_names.include?(attribute.to_s)

    User.where(attribute => value).order(updated_at: :desc).filter_map { |user| user.full_name.presence || user.user_name.presence }
  end

  def registered_module_user_names_for_option(attribute, value)
    return [] unless model_ready?(:ModuleRecord)

    key = attribute.to_s
    return [] unless key.match?(/\A[a-zA-Z0-9_]+\z/)

    active_module_records_scope("new-user")
      .where("LOWER(BTRIM(data::jsonb ->> '#{key}')) = ?", value.to_s.strip.downcase)
      .order(updated_at: :desc)
      .filter_map { |record| [record.data["first_name"], record.data["last_name"]].compact_blank.join(" ").presence || record.data["user_name"].presence }
  end

  def location_hierarchy_mappings
    return [] unless model_ready?(:ModuleRecord)

    states = active_records_for_location("state-master").map do |record|
      location_row(record, state: first_present_data(record, "state_name"))
    end

    districts = active_records_for_location("district-master").map do |record|
      location_row(record,
        state: first_present_data(record, "state"),
        district: first_present_data(record, "district_name"))
    end

    blocks = active_records_for_location("block-master").map do |record|
      location_row(record,
        state: first_present_data(record, "state"),
        district: first_present_data(record, "district"),
        block: first_present_data(record, "block_name"))
    end

    gram_panchayats = active_records_for_location("gram-panchayat-master").map do |record|
      location_row(record,
        state: first_present_data(record, "state"),
        district: first_present_data(record, "district"),
        block: first_present_data(record, "block"),
        gram_panchayat: gram_panchayat_name_from_record(record))
    end

    villages = active_records_for_location("village-master").map do |record|
      location_row(record,
        state: first_present_data(record, "state"),
        district: first_present_data(record, "district"),
        block: first_present_data(record, "block"),
        gram_panchayat: gram_panchayat_name_from_record(record),
        village: first_present_data(record, "village_name", "village", "name"))
    end

    lg_directory_rows = active_records_for_location("lg-directory-list").map do |record|
      location_row(record,
        state: first_present_data(record, "state", "state_name"),
        district: first_present_data(record, "district", "district_name"),
        block: first_present_data(record, "block", "cd_block_name"),
        gram_panchayat: gram_panchayat_name_from_record(record),
        village: first_present_data(record, "village", "village_name"))
    end

    states + districts + blocks + gram_panchayats + villages + lg_directory_rows
  end

  def active_records_for_location(module_slug)
    ModuleRecord
      .where(module_slug: module_slug)
      .order(created_at: :desc)
      .select { |record| active_module_record?(record) }
  end

  def location_row(record, values)
    row = { id: record.id.to_s }
    values.each { |key, value| row[key] = value.to_s.strip if value.present? }
    row
  end

  def gram_panchayat_name_from_record(record)
    first_non_code_data(record, "gram_panchayat_name", "gram_panchayat", "gram_panchayat_id", "gp_name", "gram_name", "name", "gp_code", "gram_code")
  end

  def first_non_code_data(record, *keys)
    values = keys.filter_map { |key| record.data[key].to_s.strip.presence }
    values.find { |value| !code_like_location_value?(value) } || values.first
  end

  def code_like_location_value?(value)
    value.to_s.strip.match?(/\A[\d\s.\/-]+\z/)
  end

  def static_field_options(field)
    {
      "Month Name" => Date::MONTHNAMES.compact,
      "Financial Year" => financial_year_options,
      "Approval Level" => ["First Approval", "Second Approval", "Third Approval"],
      "Priority" => ["High", "Medium", "Low"],
      "Payment Status" => ["Pending", "Paid", "Rejected"],
      "Completion Status" => ["Pending", "Completed", "Overdue"],
      "Gender" => ["Male", "Female", "Other"],
      "User Type" => ["Admin", "User"],
      "Can View" => ["Yes", "No"],
      "Can Create" => ["Yes", "No"],
      "Can Edit" => ["Yes", "No"],
      "Can Delete" => ["Yes", "No"],
      "Select Mandatory" => ["Yes", "No"],
      "Main Activity Type" => ["Training", "Other"],
      "Training Method" => ["General Training/Meeting", "Input Demo INM", "Input Demo PM", "FFS"],
      "Achievement Fill" => ["Auto Fill", "Self"],
      "Office Level" => ["State", "District", "Block", "Gram Panchayat", "Village"],
      "Parent Office Type" => ["Parent Office", "Sub Parent Office"],
      "Module Name" => ["Jeevika Jankar Registration", "Jeevika Jankar Bill", "Training Form Edit"],
      "VRP Name" => vrp_name_options,
      "Sub Module Name" => sidebar_submodule_names
    }[field] || []
  end

  def financial_year_options
    current_year = Date.current.year

    ((current_year - 2)..(current_year + 5)).map do |year|
      "#{year}-#{year + 1}"
    end
  end

  def field_sources
    {
      "State" => { module: "state-master", field: "state_name" },
      "District" => { module: "district-master", field: "district_name" },
      "Block" => { module: "block-master", field: "block_name" },
      "ICS / Block" => { module: "block-master", field: "block_name" },
      "Gram Panchayat" => { module: "gram-panchayat-master", field: "gram_panchayat_name" },
      "Gram Name" => { module: "gram-panchayat-master", field: "gram_panchayat_name" },
      "Village" => { module: "village-master", field: "village_name" },
      "VRP Type" => { module: "add-vrp-type", field: "vrp_type_name" },
      "Select VRP Type" => { module: "add-vrp-type", field: "vrp_type_name" },
      "Jeevika Jankar Type" => { module: "add-vrp-type", field: "jeevika_jankar_type_name" },
      "Jeevika Jankar Type Name" => { module: "add-vrp-type", field: "jeevika_jankar_type_name" },
      "Activity Group" => { module: "add-activity-group", field: "activity_group_name" },
      "Main Activity" => { module: "add-activity-group", field: "main_activity_name" },
      "Select Main Activity" => { module: "add-activity-group", field: "main_activity_name" },
      "VRP Activity" => { module: "add-vrp-activity", field: "activity_name" },
      "Sub Activity" => { module: "add-vrp-activity", field: "sub_activity_name" },
      "Stakeholder" => { module: "stakeholder-master", field: "stakeholder_name_in_english" },
      "Stakeholder Name" => { module: "stakeholder-master", field: "stakeholder_name_in_english" },
      "Stakeholder Category" => { module: "stakeholder-master", field: "stakeholder_name_in_english" },
      "Stakeholder Role" => { module: "stakeholder-role", field: "stakeholder_role" },
      "Parent Office" => { module: "parent-office-add", field: "parent_office_name" },
      "Parent Category" => { module: "parent-office-add", field: "parent_office_name" },
      "Office Category" => { module: "office-category-add", field: "office_name" },
      "Office Name" => { module: "office-category-add", field: "office_name" },
      "Office" => { module: "office-category-add", field: "office_name" },
      "Sub Office Name" => { module: "office-mapping-add", field: "sub_office_name" },
      "Approver (Approved By)" => { module: "new-user", field: "approver_name_with_role" },
      "Level 1 User" => { module: "new-user", field: "approver_name_with_role" },
      "Level 2 User" => { module: "new-user", field: "approver_name_with_role" },
      "Level 3 User" => { module: "new-user", field: "approver_name_with_role" },
      "Select Financial Year" => { module: "month-master", field: "financial_year" },
      "Select Bill Month" => { module: "month-master", field: "month_name" },
      "Month" => { module: "month-master", field: "month_name" },
      "ICS" => { module: "ics-master", field: "ics_name" },
      "Select ICS" => { module: "ics-master", field: "ics_name" },
      "Activity" => { module: "add-vrp-activity", field: "activity_name" },
      "Select Activity" => { module: "add-vrp-activity", field: "activity_name" },
      "Sub Activity Name" => { module: "add-vrp-activity", field: "sub_activity_name" },
      "Trainee Department" => { module: "office-category-add", field: "office_name" },
      "Department" => { module: "office-category-add", field: "office_name" },
      "Training Topic" => { module: "add-activity-group", field: "main_activity_name" },
      "Training Subject" => { module: "add-vrp-activity", field: "sub_activity_name" },
      "Task Indicator" => { module: "task-indicator-master", field: "task_indicator_name" },
      "Select Task Indicator" => { module: "task-indicator-master", field: "task_indicator_name" },
      "Bank Name" => { module: "bank-master", field: "bank_name" },
      "Role" => { module: "role-name", field: "role_name" },
      "Role Name" => { module: "role-name", field: "role_name" },
      "User Management Role" => { module: "user-management-role", field: "user_management_role" },
      "Person Type" => { module: "person-type", field: "person_type" },
      "Project Name" => { module: "project-master", field: "project_name" }
    }
  end

  def office_category_mappings
    return [] unless model_ready?(:ModuleRecord)

    active_module_records_scope_for_all_modules
      .where(module_slug: ["office-category-add", "office-mapping-add"])
      .order(created_at: :desc)
      .map do |record|
        office_category = first_present_data(record, "office_category", "category_name")
        office_name = first_present_data(record, "office_name", "office")
        if record.module_slug == "office-category-add"
          office_category = office_name if office_category.blank?
          office_name = ""
        elsif record.module_slug == "office-mapping-add"
          office_category = office_name if office_category.blank?
          office_name = first_present_data(record, "sub_office_name", "office_mapping", "office").to_s.strip
        end

        {
          stakeholder: first_present_data(record, "stakeholder_category", "stakeholder_name", "stakeholder").to_s.strip,
          parent_office: first_present_data(record, "parent_category", "parent_office", "parent_office_name").to_s.strip,
          office_category: office_category.to_s.strip,
          office_name: office_name.to_s.strip,
          office: office_name.presence || office_category.to_s.strip,
          office_level: first_present_data(record, "office_level").to_s.strip
        }
      end
      .reject { |mapping| mapping[:office_category].blank? && mapping[:office_name].blank? }
      .uniq
  end

  def parent_office_mappings
    return [] unless model_ready?(:ModuleRecord)

    active_module_records_scope("parent-office-add")
      .order(created_at: :desc)
      .filter_map do |record|
        name = first_present_data(record, "parent_office_name", "parent_category").to_s.strip
        next if name.blank?

        parent_office = first_present_data(record, "parent_office").to_s.strip
        parent_office_type = first_present_data(record, "parent_office_type").to_s.strip
        parent_office_type = parent_office.present? ? "Sub Parent Office" : "Parent Office" if parent_office_type.blank?

        {
          stakeholder: first_present_data(record, "stakeholder_category", "stakeholder_name", "stakeholder").to_s.strip,
          parent_office_name: name,
          parent_office_type: parent_office_type,
          parent_office: parent_office,
          office_level: first_present_data(record, "office_level").to_s.strip
        }
      end
      .uniq
  end

  def parent_office_parent_options
    parent_office_mappings
      .filter_map { |mapping| mapping[:parent_office_name].presence }
      .uniq
  end

  def vrp_name_options
    return [] unless model_ready?(:Vrp)

    Vrp.order(:name, :id).filter_map { |vrp| vrp_approval_label(vrp) }.uniq
  end

  def vrp_approval_label(vrp)
    [vrp.name.presence, vrp.mobile_no.presence].compact.join(" - ").presence
  end

  def dashboard_vrp_name_matches?(expected, vrp)
    return true if expected.blank?

    [vrp_approval_label(vrp), vrp.name].compact.any? { |label| dashboard_value_matches?(expected, label) }
  end

  def approval_record_priority(record)
    [(record.data["user_name"].present? || record.data["vrp_name"].present?) ? 1 : 0, record.id]
  end

  def approval_user_options
    approval_user_mappings.map { |mapping| mapping.slice(:value, :label) }.uniq
  end

  def approval_user_mappings
    @approval_user_mappings ||= begin
      mappings = []

      if model_ready?(:ModuleRecord)
        mappings.concat(
          active_module_records_scope("new-user")
            .order(created_at: :desc)
            .filter_map { |record| approval_user_mapping_from_data(record.data) }
        )
      end

      if model_ready?(:User)
        mappings.concat(
          User.order(:user_name, :id).filter_map { |user| approval_user_mapping_from_user(user) }
        )
      end

      mappings.uniq { |mapping| [mapping[:value], mapping[:label], mapping[:office_category], mapping[:office_name]] }
    end
  end

  def approval_user_mapping_from_data(data)
    username = data["user_name"].to_s.strip
    return if username.blank?

    role = data["role"].presence || data["role_name"].presence
    {
      value: username,
      label: approval_user_label(username, role),
      stakeholder: data["stakeholder"].presence || data["stakeholder_name"].presence || data["stakeholder_category"].to_s.strip,
      office_category: data["office_category"].presence || data["office_name"].to_s.strip,
      office_name: data["sub_office_name"].presence || data["office"].to_s.strip,
      office: data["sub_office_name"].presence || data["office"].to_s.strip
    }
  end

  def approval_user_mapping_from_user(user)
    username = user.user_name.to_s.strip
    return if username.blank?

    role = (user.respond_to?(:role) ? user.role : nil).presence ||
      (user.respond_to?(:role_name) ? user.role_name : nil).presence
    office_category = (user.respond_to?(:office_category) ? user.office_category : nil).presence ||
      (user.respond_to?(:office_name) ? user.office_name.to_s.strip : "")
    office_name = user.respond_to?(:sub_office_name) ? user.sub_office_name.presence : nil
    office_name ||= user.respond_to?(:office) ? user.office.to_s.strip : ""
    {
      value: username,
      label: approval_user_label(username, role),
      stakeholder: user.respond_to?(:stakeholder) ? user.stakeholder.to_s.strip : "",
      office_category: office_category,
      office_name: office_name,
      office: office_name
    }
  end

  def approval_user_label(username, role)
    role.present? ? "#{username}(#{role})" : username
  end

  def approval_level_display_label(value)
    text = value.to_s.strip
    return text if text.blank?

    sequence = approval_level_sequence_from_text(text)
    sequence ? approval_level_label_for_sequence(sequence) : text
  end

  def approval_level_label_for_sequence(sequence)
    ordinal = {
      1 => "First",
      2 => "Second",
      3 => "Third",
      4 => "Fourth",
      5 => "Fifth",
      6 => "Sixth",
      7 => "Seventh",
      8 => "Eighth",
      9 => "Ninth",
      10 => "Tenth"
    }[sequence.to_i]

    ordinal ? "#{ordinal} Approval" : "Approval #{sequence.to_i}"
  end

  def sidebar_module_names
    ApplicationHelper::SIDEBAR_SECTIONS.map { |section| section[:title] }
  end

  def sidebar_submodule_names
    ApplicationHelper::SIDEBAR_SECTIONS.flat_map { |section| section[:links].map(&:first) }
  end

  def generic_field_options(field)
    @generic_field_options_cache ||= {}
    cache_key = [(@slug || current_slug).to_s, field.to_s]
    return @generic_field_options_cache[cache_key] if @generic_field_options_cache.key?(cache_key)

    key = field.parameterize(separator: "_")
    candidate_keys = [
      key,
      "#{key}_name",
      "#{key}_title",
      "#{key}_code",
      key.delete_prefix("select_"),
      "#{key.delete_prefix('select_')}_name"
    ].uniq

    @generic_field_options_cache[cache_key] = active_module_records_scope_for_all_modules
      .where.not(module_slug: @slug || current_slug)
      .order(created_at: :desc)
      .flat_map { |record| candidate_keys.filter_map { |candidate| record.data[candidate].presence } }
      .uniq
  end

  def values_from_module(module_slug, field_key)
    return approver_options if module_slug == "new-user" && field_key == "approver_name_with_role"

    @values_from_module_cache ||= {}
    cache_key = [module_slug.to_s, field_key.to_s]
    return @values_from_module_cache[cache_key] if @values_from_module_cache.key?(cache_key)

    if module_slug == "gram-panchayat-master" && field_key == "gram_panchayat_name"
      return @values_from_module_cache[cache_key] = active_module_records_scope(module_slug)
        .order(created_at: :desc)
        .filter_map { |record| gram_panchayat_name_from_record(record) }
        .uniq
    end

    field_keys = [field_key]
    field_keys << "role_name" if module_slug == "role-management" && field_key == "role"
    field_keys << "activity_group_name" if module_slug == "add-activity-group" && field_key == "main_activity_name"
    field_keys << "vrp_activity_name" if module_slug == "add-vrp-activity" && field_key == "activity_name"
    field_keys.concat(["activity_name", "vrp_activity_name"]) if module_slug == "add-vrp-activity" && field_key == "sub_activity_name"
    field_keys << "category_name" if module_slug == "office-category-add" && field_key == "office_name"
    field_keys << "vrp_type_name" if module_slug == "add-vrp-type" && field_key == "jeevika_jankar_type_name"
    field_keys << "jeevika_jankar_type_name" if module_slug == "add-vrp-type" && field_key == "vrp_type_name"

    @values_from_module_cache[cache_key] = active_module_records_scope(module_slug)
      .order(created_at: :desc)
      .flat_map { |record| field_keys.filter_map { |key| record.data[key].presence } }
      .uniq
  end

  def approver_options
    user_options = []
    if model_ready?(:User)
      user_options = User.order(created_at: :desc).filter_map do |user|
        full_name = user.full_name.presence || user.user_name.presence
        next if full_name.blank?

        user.role.present? ? "#{full_name} (#{user.role})" : full_name
      end
    end

    return user_options.uniq if user_options.any?
    return [] unless model_ready?(:ModuleRecord)

    active_module_records_scope("new-user")
      .order(created_at: :desc)
      .filter_map do |record|
        full_name = [record.data["first_name"], record.data["last_name"]].compact_blank.join(" ").presence ||
          record.data["user_name"].presence
        role = record.data["role"].presence
        next if full_name.blank?

        role.present? ? "#{full_name} (#{role})" : full_name
      end
      .uniq
  end

  def active_module_record?(record)
    return false if truthy_module_flag?(record.data["deleted"]) ||
      truthy_module_flag?(record.data["is_deleted"]) ||
      truthy_module_flag?(record.data["discarded"])

    status = record.data["status"].to_s.strip
    return true if status.blank?

    status.casecmp("Active").zero?
  end

  def truthy_module_flag?(value)
    ["1", "true", "yes", "deleted"].include?(value.to_s.strip.downcase)
  end

  def sync_vrp_master_record(record)
    case record.module_slug
    when "bank-master"
      sync_bank_master(record)
    when "add-vrp-type"
      sync_vrp_type(record)
    end
  end

  def sync_bank_master(record)
    klass = "VrpBankMaster".safe_constantize
    return unless klass&.table_exists?

    name = record.data["bank_name"].to_s.strip
    return if name.blank?

    bank = klass.find_or_initialize_by(name: name)
    bank.is_active = record.data["status"].to_s != "Inactive" if bank.respond_to?(:is_active=)
    bank.is_deleted = false if bank.respond_to?(:is_deleted=)
    bank.save(validate: false)
  end

  def sync_vrp_type(record)
    klass = "VrpType".safe_constantize
    return unless klass&.table_exists?

    type_name = (record.data["position_type_name"].presence || record.data["jeevika_jankar_type_name"].presence || record.data["vrp_type_name"]).to_s.strip
    return if type_name.blank?

    vrp_type = klass.find_or_initialize_by(type_name: type_name)
    vrp_type.is_active = record.data["status"].to_s != "Inactive" if vrp_type.respond_to?(:is_active=)
    vrp_type.is_deleted = false if vrp_type.respond_to?(:is_deleted=)
    vrp_type.save(validate: false)
  end

  def model_ready?(name)
    @model_ready_cache ||= {}
    key = name.to_s
    return @model_ready_cache[key] if @model_ready_cache.key?(key)

    klass = name.to_s.safe_constantize
    @model_ready_cache[key] = klass.present? && (!klass.respond_to?(:table_exists?) || klass.table_exists?)
  end

  def dashboard_vrp_previous_status(vrp)
    history = vrp_approval_history_for(vrp).sort_by(&:created_at)
    return "-" if history.blank?

    if history.size >= 2
      history[-2].data["status"].presence || "-"
    else
      "Submitted"
    end
  end

  def dashboard_vrp_status_label(vrp)
    return "Rejected" if vrp.status.to_i == 99 || vrp_approval_rejected?(vrp)
    return "Final Approved" if vrp.status.to_i == 55 || vrp_approval_complete?(vrp)

    if vrp_approval_sent?(vrp)
      step = dashboard_current_approval_step_for_visibility(vrp)
      approver = step&.data&.[]("approver_approved_by").presence || "Approver"
      "Pending at #{approver}"
    else
      "Submitted"
    end
  end
end
