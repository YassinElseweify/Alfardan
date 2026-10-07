# Service Appointment Management: DEV → QA promotion (2026-10-07)

`package.xml` in this folder lists every metadata component the Service Appointment feature
(ALF-SA-01 to ALF-SA-07) needs in QA, including the dependencies. It covers everything the
"Service appointment Management" session changed in DEV on 2026-10-07.

## How to promote

```bash
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
