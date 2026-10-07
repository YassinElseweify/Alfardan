# Service Appointment Management: DEV → QA promotion (2026-10-07)

`package.xml` in this folder lists every metadata component the Service Appointment feature
(ALF-SA-01 to ALF-SA-07) needs in QA, including the dependencies. It is built to cover
everything the "Service appointment Management" session created or changed. That is the
whole session, not only 2026-10-07; see "Work done across the session" below.

## How to promote

```bash
# 0. Completeness check against DEV. It lists anything the manifest's components use, anything
#    that uses them, and anything modified in DEV since the date, that isn't in package.xml.
#    Set the date to when the SA work started.
manifests/service-appointment-qa-promotion-1007/check-completeness.sh "ALFardan DEV" 2026-09-01T00:00:00Z

# 1. Retrieve fresh from DEV (DEV is the source of truth: the local force-app was stale for SA)
sf project retrieve start -x manifests/service-appointment-qa-promotion-1007/package.xml \
  -o "ALFardan DEV" -r manifests/service-appointment-qa-promotion-1007

# 2. Validate against QA first (no changes made)
sf project deploy validate -x manifests/service-appointment-qa-promotion-1007/package.xml \
  -o "<QA alias>" -l RunSpecifiedTests \
  -t AF_ServiceAppointmentCommsSenderTest -t AF_ServiceAppointmentCommsServiceTest \
  -t AF_ServiceAppointmentVehicleResolverTest

# 3. Deploy (or quick-deploy the validation job id)
sf project deploy start -x manifests/service-appointment-qa-promotion-1007/package.xml \
  -o "<QA alias>" -l RunSpecifiedTests \
  -t AF_ServiceAppointmentCommsSenderTest -t AF_ServiceAppointmentCommsServiceTest \
  -t AF_ServiceAppointmentVehicleResolverTest
```

The retrieve in step 1 has not been run yet. The original session ran out of usage before it
could. If the CLI or the QA org rejects API `68.0`, change `<version>` to `67.0`, which matches
`sfdx-project.json`.

## Work done across the session, and where it is in the manifest

From the session's transcript and its memory notes (`alfardan-sa-ux-polish-1007`, which follows
on from `alfardan-sa01-novehicle-bugfix-1007`):

| Work | Covered by |
|---|---|
| Booking flow built, then redesigned vehicle-first: 3 entry paths (Contact with a vehicle, Contact with no vehicle and the vehicle created on the fly, and the list-view button with no context) | Flow `AF_FL_ServiceAppointment_NewBooking`, ApexClass `AF_ServiceAppointmentVehicleResolver` (+Test) |
| `AccountId` → `ParentRecordId` fix on the record create | NewBooking flow |
| Confirmation screen rebuilt as a styled card (Contact FirstName/LastName fix) | NewBooking flow |
| v15: Phone/Email wired via `Get_BookingContact`; Subject/BookingChannel | NewBooking flow |
| v16/v17: Sched*/EarliestStart/DueDate, PreferredBranch = chosen shop, shop-scoped advisor screens, `SystemModeWithoutSharing` | NewBooking flow, `ServiceResource.AF_MaintenanceShop__c`, `AF_PS_ServiceResource_FullAccess` |
| Page layout redesigned in the Case style (AccountId hidden) | Layout `ServiceAppointment-Service Appointment Layout` |
| Highlights panel shows the Contact: new compact layout, assigned on the object | CompactLayout `AF_ServiceAppointment_Compact` + CustomObject `ServiceAppointment` (holds `compactLayoutAssignment`) |
| Record page you created mid-session | FlexiPage `Service_Appointment_Record_Page` + CustomObject `ServiceAppointment` (holds the page assignment) |
| List-view button that launches the flow (no-context path) | CustomObject `ServiceAppointment` (a retrieve of the object includes its `webLinks` and `searchLayouts`). The completeness check lists the button by name under reverse dependencies. |
| Contact quick action | QuickAction `Contact.AF_New_ServiceAppointment`. The check lists the Contact layout or page that holds it. |
| SA-02 confirmation/reminder emails | Flow `AF_FL_ServiceAppointment_SendComms`, Comms Apex classes, CMDT types and records |
| SA-03 no-show, SA-05 follow-up and feedback, SA-06/07 vehicle reminders | Their flows, `AF_Feedback__c`, the permission sets |

The session's local manifest folders (`service-appointment-polish-1007`,
`service-appointment-shopadvisor-1007`, `_sa_fixes*`) were deleted during that session. This
manifest supersedes them all. The transcript from before 09:42 on 2026-10-07 was compacted and
isn't recoverable, which is why step 0 exists: it checks DEV itself rather than relying on the
conversation history.

## What's in the manifest

| Type | Components | Why |
|---|---|---|
| Flow | `AF_FL_ServiceAppointment_NewBooking` | SA-01 booking (v17: Sched*/EarliestStart/DueDate wired, PreferredBranch = chosen shop, shop-scoped advisor screens, `SystemModeWithoutSharing`) |
| Flow | `AF_FL_ServiceAppointment_SendComms` | SA-02 confirmation, 24h and 2-3h reminders |
| Flow | `AF_FL_ServiceAppointment_NoShowDetection` | SA-03 |
| Flow | `AF_FL_ServiceAppointment_PostServiceFollowUp` | SA-05 |
| Flow | `AF_FL_Vehicle_ServiceDueReminders`, `AF_FL_Vehicle_WarrantyRenewalFollowUp`, `AF_FL_Task_WarrantyRenewalEscalation` | SA-06 / SA-07 |
| Flow | `AF_FL_Sub_DeriveBusinessUnit` | Subflow called by NewBooking and PostServiceFollowUp. Without it they won't deploy. |
| ApexClass | `AF_ServiceAppointmentVehicleResolver`, `AF_ServiceAppointmentCommsService`, `AF_ServiceAppointmentCommsSender` and their 3 test classes | Invocable actions used by the flows |
| CustomObject | `ServiceAppointment`, `ServiceResource` | Fields, record-page (FlexiPage) and compact-layout assignments |
| CustomObject | `AF_Feedback__c` | SA-05 feedback object (shared with Case Management) |
| CustomObject | `AF_EmailTemplateConfig__mdt`, `AF_BrandMailbox__mdt` | CMDT types. They must exist before their records deploy. |
| CustomField | 10 × `ServiceAppointment.AF_*`, `ServiceResource.AF_MaintenanceShop__c`, 11 × `AF_Feedback__c.AF_*` | All live custom fields (confirmed via FieldDefinition in DEV) |
| CustomMetadata | `AF_EmailTemplateConfig__mdt.AF_SA_BookingConfirmation` / `AF_SA_Reminder24h` / `AF_SA_Reminder2to3h` | SA-02 email templates |
| CustomMetadata | `AF_BrandMailbox__mdt.BMW` / `BMW_Motorrad` / `Ferrari` / `Jaguar` / `Mini` | `AF_ServiceAppointmentCommsSender` reads the brand no-reply address from these |
| CustomTab | `AF_Feedback__c` | Referenced by `AF_PS_Feedback_FullAccess` |
| Layout / FlexiPage / CompactLayout | `ServiceAppointment-Service Appointment Layout`, `Service_Appointment_Record_Page`, `AF_ServiceAppointment_Compact` | SA record UI |
| QuickAction | `Contact.AF_New_ServiceAppointment` | Launches the booking flow from a Contact |
| PermissionSet | `AF_PS_ServiceResource_FullAccess` | New today. FLS for `ServiceResource.AF_MaintenanceShop__c`, which the shop-scoped advisor lookup needs. |
| PermissionSet | `AF_PS_ServiceAppointment_FullAccess`, `AF_PS_Feedback_FullAccess` | FLS for the SA and Feedback fields |

## Fixes compared with the first draft (the version on the Mac)

1. **Retrieve failed.** The `<types>` block for `ServiceAppointment`/`ServiceResource`/`AF_Feedback__c`
   had no `<name>CustomObject</name>`. The CLI returned `Invalid types definition ... Found: ""`.
   This is now fixed.
2. Added the **CMDT type definitions** `AF_EmailTemplateConfig__mdt` and `AF_BrandMailbox__mdt`.
   Before, only the records were listed, and records fail if the type is missing in QA.
3. Added the **`AF_BrandMailbox__mdt` records**. The session said it would include them but didn't.
4. Added the **permission sets `AF_PS_ServiceAppointment_FullAccess` and `AF_PS_Feedback_FullAccess`**,
   plus the `AF_Feedback__c` **tab** that the Feedback permission set references. Without these,
   the new fields deploy but users in QA can't see them.

## Prerequisites QA must already have (not in the manifest; owned by earlier releases)

Check these in QA before deploying. If any are missing, add them to the manifest.

- Queues `AF_Q_Cases_Automobiles`, `AF_Q_Cases_PremierMotors`, `AF_Q_Cases_SportsMotors`.
  PostServiceFollowUp looks them up by DeveloperName at runtime, so a missing queue won't fail
  the deploy, only the flow at runtime.
- `Vehicle.AF_CurrentOwnerContact__c`, used by `AF_ServiceAppointmentVehicleResolver`.
- `Contact.AF_Brand__c` and GlobalValueSet `AF_Brand`, used by `AF_ServiceAppointmentCommsSender`.
- Org-Wide Email Addresses: the brand no-reply addresses and the `No Reply` fallback. These are
  setup data, not metadata, so create and verify them manually in QA.
- Automotive Cloud objects: Vehicle, VehicleDefinition, Asset, Product2.

## Post-deploy steps in QA (data and setup, not metadata)

- Assign `AF_PS_ServiceAppointment_FullAccess`, `AF_PS_ServiceResource_FullAccess` and
  `AF_PS_Feedback_FullAccess` to the SA personas.
- Set `AF_MaintenanceShop__c` on the advisor ServiceResource records. In DEV only the dummy
  "Test ServiceAdvisor" has a value. Without it, the advisor screen in the booking flow is empty.
- Check that `AF_New_ServiceAppointment` appears on the Contact page layout or Lightning page
  that QA users get. The Contact layout isn't in this manifest.
- Activate the flows if the target org deploys them as inactive.
- Check that the scheduled jobs for `AF_FL_Vehicle_ServiceDueReminders` and
  `AF_FL_Vehicle_WarrantyRenewalFollowUp` show up in Scheduled Jobs.

## Known, intentional gaps (not defects)

- `AppointmentType`, `WorkTypeId`, `EngagementChannelTypeId` and `AppointmentCategoryId` are blank.
  The org has no reference data for them, and the user chose to leave them blank.
- Booking slot times are dummy placeholders (tomorrow 9-10 or 14-15) until Keyloop is integrated.
  Records SA-0012 to SA-0019 were deliberately not backfilled.
- SA-04 (status visibility) depends on Keyloop and isn't built.

## Excluded on purpose

- `ScheduleServiceAppt` flow (in `force-app`). This is the standard Automotive Cloud actionable-event
  flow and isn't part of this feature.
- `Profile:Admin`. The session retrieved it to fix FLS but solved the problem with
  `AF_PS_ServiceResource_FullAccess` instead.
