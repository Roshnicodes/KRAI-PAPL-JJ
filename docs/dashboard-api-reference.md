# Mobile Dashboard API URLs

See [React Native report handoff](react-native-dashboard-reports-api.md) for CC/JJ Work Status endpoints, current Demonstration Method Count/Farmer fields, and exact filter limitations.

Base URL: `https://krai.ploughmanagro.com/api/v1`  
Header on every request: `Authorization: Bearer <token>`

## Admin dashboard box APIs

| Heading | URL |
|---|---|
| Total ICS Count | `/admin-dashboard/widgets/total_ics_count` |
| Total Registered Jeevika Jankar | `/admin-dashboard/widgets/total_registered` |
| Final Approved | `/admin-dashboard/widgets/final_approved` |
| Pending Approval | `/admin-dashboard/widgets/pending_approval` |
| Target Records | `/admin-dashboard/widgets/target_records` |
| Without Target | `/admin-dashboard/widgets/without_target` |
| Activities Assigned | `/admin-dashboard/widgets/activities_assigned` |
| Without Activity | `/admin-dashboard/widgets/without_activity` |
| Level 2 Users | `/admin-dashboard/widgets/level_2_users` |
| Bill Approved | `/admin-dashboard/widgets/bill_approved` |
| Bill Pending | `/admin-dashboard/widgets/bill_pending` |

Example: `https://krai.ploughmanagro.com/api/v1/admin-dashboard/widgets/total_ics_count`

For cascading mobile dropdowns and React Native integration, see [dashboard auto-filter API](react-native-dashboard-filters-api.md).

### Card values and filters

Read each widget's `value` field. Send the same filters to every card, for example
`?month=August&fco=Sausar&ics=ICS%20A&main_activity=All`.
Omitted `month` defaults to the previous calendar month; `month=All` includes all months.

- ICS, village and farmer totals use the web dashboard's AFL population, not the target-mapping dropdown count. Month does not restrict these registration totals.
- Mapped main/sub indicator cards count distinct names for the selected month, FCO and ICS. Like the web summary cards, these two counts ignore main/sub activity selections.
- Demonstration Method and CC/JJ widgets return arrays, not a single number. See the [report response keys and filter rules](react-native-dashboard-reports-api.md).

## Admin filter API

`GET https://krai.ploughmanagro.com/api/v1/admin-dashboard/filters`

It returns five dynamic dropdowns with these exact headings: **Main Major Work Indicator**, **Sub Major Work Indicator**, **FCO**, **ICS Name**, and **Month**. Each item has `key`, `heading`, `all_option`, and live `options`.

Apply selected filters to any box URL using:

```text
?main_activity=Farmers%27%20Training&sub_activity=...&fco=FCO-C%20Sausar&ics=...&month=August
```

## Remaining Admin box API URLs

All use `https://krai.ploughmanagro.com/api/v1/admin-dashboard/widgets/` before the last column value.

| Heading | Widget value in URL |
|---|---|
| Total Villages Count | `total_villages_count` |
| Total Farmer Count | `total_farmer_count` |
| Total Mapped Main Major Work Indicators | `total_mapped_main_activities` |
| Total Mapped Sub-Major Work Indicators | `total_mapped_sub_activities` |
| Mapped Farmer | `mapped_farmer` |
| No Training | `no_training` |
| Only 1 Training | `only_1_training` |
| 1+ Trainings | `one_plus_trainings` |
| OPG Training Target | `opg_training_target` |
| OPG Training Achievement | `opg_training_achievement` |
| General Training/Meeting | `general_training_meeting` |
| Input Demo INM | `input_demo_inm` |
| FFS Exposure | `ffs_exposure` (`ffs` also supported) |
| Input Demo PM | `input_demo_pm` |
| Sausar Required / Active / Vacant | `sausar_required` / `sausar_active` / `sausar_vacant` |
| Turekela Required / Active / Vacant | `turekela_required` / `turekela_active` / `turekela_vacant` |
| Sausar Male / Female | `sausar_male` / `sausar_female` |
| Turekela Male / Female | `turekela_male` / `turekela_female` |

## Jeevika Jankar dashboard box APIs

| Heading | URL |
|---|---|
| Mapped Villages | `/jeevika-jankar-dashboard/widgets/mapped_villages` |
| Main Activities | `/jeevika-jankar-dashboard/widgets/main_activities` |
| Sub Activities | `/jeevika-jankar-dashboard/widgets/sub_activities` |
| Assigned Farmers | `/jeevika-jankar-dashboard/widgets/mapped_farmers` |
| Assigned Target | `/jeevika-jankar-dashboard/widgets/assigned_target` |
| Achieved Target | `/jeevika-jankar-dashboard/widgets/achieved_target` |
| Pending Target | `/jeevika-jankar-dashboard/widgets/pending_target` |

Use `?month=August` to select a month. Example: `https://krai.ploughmanagro.com/api/v1/jeevika-jankar-dashboard/widgets/assigned_target?month=August`

## CC / Agronomist / FCO dashboard box APIs

| Heading | URL |
|---|---|
| Total Registered JJ | `/user-dashboard/widgets/total_registered` |
| Final Approved | `/user-dashboard/widgets/final_approved` |
| Pending Approval | `/user-dashboard/widgets/pending_approval` |
| Target Records | `/user-dashboard/widgets/target_records` |
| Activities Assigned | `/user-dashboard/widgets/activities_assigned` |
| Bill Approved | `/user-dashboard/widgets/bill_approved` |
| Bill Pending | `/user-dashboard/widgets/bill_pending` |
| Total Mapped Villages | `/user-dashboard/widgets/total_mapped_villages` |
| Targeted Farmers | `/user-dashboard/widgets/targeted_farmers` |
| Farmer-wise Achievement | `/user-dashboard/widgets/farmer_wise_achievement` |
| Farmer-wise Pending Achievement | `/user-dashboard/widgets/farmer_wise_pending_achievement` |

The logged-in user's CC/Agronomist/FCO scope is applied automatically.

## Dynamic list and export APIs

For every box, replace `:list_type` with the required type, for example `total_ics_count`, `target_records`, `mapped_villages`, `training_green`, `weekly_completed`, or `bill_pending`.

| Purpose | URL |
|---|---|
| Admin View List | `/admin-dashboard/lists/:list_type` |
| Admin XLSX Export | `/admin-dashboard/lists/:list_type/export` |
| User View List | `/user-dashboard/lists/:list_type` |
| User XLSX Export | `/user-dashboard/lists/:list_type/export` |
| JJ View List | `/jeevika-jankar-dashboard/lists/:list_type` |
| JJ XLSX Export | `/jeevika-jankar-dashboard/lists/:list_type/export` |

Widget response format: `{ success, dashboard_type, widget, heading, value, filters, generated_at }`.

### Demonstration Method

Admin and office-user dashboard responses include `demonstration_method`, an FCO-wise array with `fco_id`, `fco_name`, `OPG Target`, `General Training/Meeting`, `Input Demo INM`, `Input Demo PM`, and `FFS`.

- `GET /api/v1/admin-dashboard/lists/demonstration_method?month=August`
- `GET /api/v1/user-dashboard/lists/demonstration_method?month=August`
- Append `/export` before the query string to download Excel.
- `GET /api/v1/{admin-dashboard|user-dashboard}/widgets/demonstration_method?month=August` returns the summary widget.

List rows additionally include `vrp_id` and `VRP Name`. The existing Demonstration Method section displays metric boxes; View List opens `/dashboard/demonstration-method` and Export Excel downloads the same VRP rows.

The report follows dashboard filters and login visibility. The default dashboard month is the previous calendar month (August in September); use `month=August` explicitly to reproduce the supplied August query. OPG targets use village-wise maximums before summing (FCO/village for summary, FCO/VRP/village for list), while each matching training-form entry is counted once per FCO/VRP. Training month and method whitespace are normalized. Creator IDs are trimmed in both summary and View List. VRPs with targets and no matching entries remain in the result with zero counts.

### CC and JJ Work Status

The card beside Gender Count and `cc_jj_work_status` in admin/user dashboard responses execute the report for the selected month and FCO with login visibility restrictions. One pending mapped farmer makes a JJ Red; one Red JJ makes its CC Red.

- Web View List: `/dashboard/cc-jj-work-status`; the page includes Export Excel.
- API View List: `/api/v1/{admin-dashboard|user-dashboard}/lists/cc_jj_work_status`.
- API export: append `/export` to the list endpoint.
- Widget: `/api/v1/{admin-dashboard|user-dashboard}/widgets/cc_jj_work_status`.

The list uses the supplied FPO/CC/JJ grouping and includes no activity mapping, no training mapping, pending and completed entries, and CC/agronomist involvement. Its farmer population differs from the training-mapped JJ summary. The report follows `month` and `fcoc`/`fco`/`fco_id` (All FCOs is restricted to Sausar 1004 and Turekela 1006; all other FCOs are excluded from summary, list, and export); absent month defaults to the previous month. Legacy Sausar/Turekela target FCO names are normalized to 1004/1006 for joins. Names come from the monthly target assignment; missing assignments display Not mapped / Not assigned. FCOs without training mappings display zero status counts. Activity filters do not exclude the unmapped/non-training categories.
