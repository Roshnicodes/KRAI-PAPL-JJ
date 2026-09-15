# Android / React Native dashboard API handoff

Base URL: `https://krai.ploughmanagro.com/api/v1`
All endpoints below use GET and require `Authorization: Bearer <login_token>` and `Accept: application/json` (except Excel responses).

Use prefix `/admin-dashboard` for admin login or `/user-dashboard` for CC/Agronomist/FCO office login. These reports describe JJ data; they are not JJ-login endpoints.

## Refresh all dashboard boxes

1. Call `GET /admin-dashboard/filters?month=August&main_activity=Farmers%27%20Training`.
2. Render all five dropdowns from `filters`. On changes, refresh dependent options and use returned `applied_filters`.
3. Call `GET /admin-dashboard?month=August&main_activity=Farmers%27%20Training&sub_activity=All&fco=All&ics=All`.
4. Replace the dashboard state with the new response, including `cc_jj_work_status` and `demonstration_method`. Do not request every widget separately just to refresh the screen; the full response already contains the dashboard sections.
5. Send the same query to a section's list/export when opening it.

Replace `/admin-dashboard` with `/user-dashboard` for office login. URL-encode every selected value. Send null selections as `All` to prevent omitted parameters reactivating defaults. Discard stale responses when users change selections rapidly.

See [complete cascading filter contract and React Native code](react-native-dashboard-filters-api.md), and [all widget/list keys](dashboard-api-reference.md).

**Filter refresh does not mean every numeric value must change.** Existing report calculations remain in place:

| Section | Filter behavior |
|---|---|
| Target/mapping-based boxes | Main activity, sub activity, month, FCO, ICS restrict the target population |
| Total Mapped Main/Sub Indicators | Distinct mapped names by month, FCO and ICS; these web summary totals ignore main/sub activity selections |
| Demonstration Method | Targets follow dashboard filters; training entries are counted for the resulting JJs and selected month |
| CC and JJ Work Status | Month and FCO plus login visibility; activity/sub-activity/ICS do not restrict this report |
| Participation/weekly sections | Existing section-specific month/FCO/week defaults and parameters also apply |

This preserves web report semantics. Do not label CC/JJ as ICS- or activity-filtered. Its unmapped categories intentionally include people without activity/training mappings. An aggregate may remain unchanged after a filter selection.

## CC and JJ Work Status

| Operation | Admin endpoint |
|---|---|
| Summary widget | `/admin-dashboard/widgets/cc_jj_work_status?month=August&fco=All` |
| Open card / View List | `/admin-dashboard/lists/cc_jj_work_status?month=August&fco=All` |
| Excel | `/admin-dashboard/lists/cc_jj_work_status/export?month=August&fco=All` |

For office login the same suffixes work under `/user-dashboard`.

The widget `value` (also full dashboard `cc_jj_work_status`) is an array of rows with:

`month`, `fco_id`, `status`, `toatl_cc`, `toatl_jj`, `map_farmer`, `red_farmer`, `green_farmer`.

**Keep the existing spellings `toatl_cc` and `toatl_jj` in client property access.** FCO scope is currently Sausar `1004` and Turekela `1006`; other FCOs return no report rows. One pending mapped farmer makes a JJ Red; one Red JJ makes the CC Red. FCOs without training mappings can have zero-count `No Training Mapping` summary rows.

List response: `{ success, message, dashboard_type, list_type, title, filters, count, records, generated_at }`.
Each list record uses these exact column keys:

```text
month
fco_id
fpo_id
fpo_name
cluster_incharge
vrp_name
total_farmer
No Activity Mapping
No Training Mapping
Training Mapped But No Entry
Training Entry Done
Red
Completed
Cluster Coordinator Involved
Agronomist Involved
```

The screenshot's open icon should open this list endpoint's records.

## Demonstration Method — current shared web/API logic

| Operation | Admin endpoint |
|---|---|
| Summary widget | `/admin-dashboard/widgets/demonstration_method?month=August&main_activity=Farmers%27%20Training` |
| View List | `/admin-dashboard/lists/demonstration_method?month=August&main_activity=Farmers%27%20Training` |
| Excel | `/admin-dashboard/lists/demonstration_method/export?month=August&main_activity=Farmers%27%20Training` |

Append selected `sub_activity`, `fco`, and `ics`. Use `/user-dashboard` for office login.

Both web and API call `DemonstrationMethodReport`. The latest code already exposes the updated list columns; no web edit is needed to enable them in the API.

Individual Demonstration Method card endpoints use `/admin-dashboard/widgets/` plus:

| Card | Widget key |
|---|---|
| OPG Training Target | `opg_training_target` |
| General Training/Meeting | `general_training_meeting` |
| Input Demo INM | `input_demo_inm` |
| Input Demo PM | `input_demo_pm` |
| FFS Exposure | `ffs_exposure` (legacy `ffs` also works) |

Each individual card returns its total in `value`. The FFS report column remains `FFS`.
SQL decimal totals such as `OPG Target` may be JSON strings; parse them as numbers before adding in Android.

Summary widget `value` (also full dashboard `demonstration_method`) is an FCO-wise array with:

`fco_id`, `fco_name`, `OPG Target`, `General Training/Meeting`, `Input Demo INM`, `Input Demo PM`, `FFS`.

View List `records` has these exact keys:

```text
fco_id
fco_name
vrp_id
VRP Name
Target Farmer Count
OPG Target
General Training/Meeting Count
General Training/Meeting Farmer
Input Demo INM Count
Input Demo INM Farmer
Input Demo PM Count
Input Demo PM Farmer
FFS Count
FFS Farmer
```

Use bracket access, e.g. `row['General Training/Meeting Farmer']`.

Current calculation:

- Summary OPG target takes the maximum per FCO/village before summing.
- List OPG target and Target Farmer Count take maximums per FCO/JJ/village before summing.
- Each method's Count is distinct training records; Farmer is distinct selected farmer IDs per JJ/method.
- Summary method values count training entries. Summary does not expose the list's separate Farmer metrics.
- Month, training-method whitespace/case and creator-ID whitespace are normalized. Mapped JJs without entries remain with zero method counts.
- Training achievements use the selected JJs and month; they are not independently limited to selected ICS farmer IDs.

Widget response: `{ success, dashboard_type, widget, heading, value, filters, generated_at }`. List response is the envelope described above. Excel returns XLSX bytes, not JSON. Display numeric SQL values using `Number(value ?? 0)` when needed.

## Deployment and verification

These URLs already exist in the repository. Shared report changes become available after the running backend uses the updated code; React Native must render the new fields. This handoff does not claim production deployment or measured latency. Web controllers, views, report services and SQL were not edited for this handoff.
