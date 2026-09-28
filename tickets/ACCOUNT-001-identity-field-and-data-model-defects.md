# ACCOUNT-001: Account identity fields — locked out, duplicated, and disconnected

**Module:** Account & Contact Management
**Severity:** Critical
**Status:** Open
**Found during:** QA testing of the Account (Customer) record, 2026-08-25

## Summary

While testing how Customer Accounts are created and maintained, we found eleven issues. Most trace back to three root causes: (1) the fields that hold a customer's core identity (Qatar ID, Nationality, Date of Birth) currently cannot be entered or corrected by any user except a System Administrator, (2) several fields were added to the system more than once over the course of the design and the older versions were never cleaned up or connected to anything, and (3) some picklists still expose far more options than the business actually uses. This ticket lists all eleven together so they can be fixed as one coordinated piece of work.

---

## 1. [Critical] Nobody except System Administrator can enter or fix a customer's Qatar ID, Nationality, or Date of Birth

**Steps to reproduce:**
1. Log in as any user who is *not* a System Administrator (e.g. a CRM Agent or Sales Representative).
2. Go to Accounts and click **New** to create a customer record (or open an existing one and click **Edit**).
3. Find the "Identity & Compliance" section on the form.
4. Try to click into or type a value in the Qatar ID, Nationality, or Date of Birth fields.

**Expected behavior:** Sales and CRM staff should be able to enter a new customer's Qatar ID, Nationality, and Date of Birth when creating their record, and correct any of the three later if entered wrong.

**Actual behavior:** All three fields show up as plain, non-clickable text with no box to type into. There's nothing to interact with. Checking directly confirmed the same thing from the system side — only System Administrator (and the background system that syncs with Keyloop) has permission to set these fields. No CRM or Sales role has it.

**Where this comes from:**
- BRD, Account & Contact Management section — the customer record must capture Salutation, Full Name, and Qatar ID, and Sales staff must be able to create new customer records.
- Solution Design, Account & Contact Management page — describes a dedicated "core edit" permission meant to let authorized staff maintain these fields, and separately notes that permission was removed later in the project as supposedly no longer needed. It isn't there, and nothing replaced it.

---

## 2. [Critical] A customer with only a passport (no Qatar ID) can never be registered — even though the system is supposed to allow this

**Steps to reproduce:**
1. Log in as System Administrator (the only role that can currently set these fields at all — see issue #1).
2. Create a new Account, set Account Type to "Individual."
3. Leave Qatar ID blank. Fill in the "Other ID Number" field with a passport or Omani ID value instead.
4. Save.
5. Repeat using the newer "Open Identification" field instead of "Other ID Number."

**Expected behavior:** A non-Qatari customer should be registerable using the alternate identification field, with no Qatar ID required.

**Actual behavior:** Both attempts are rejected with the message *"An Individual Account requires a Qatar ID."* Qatar ID is effectively mandatory for every individual customer, with no working exception.

**Where this comes from:**
- BRD, Lead Management section (Account matching) — customer identification should support two ID fields: one Qatar ID field and one open field for other document types.
- Solution Design — documents the rule as accepting *either* the Qatar ID *or* the alternate ID field, which is not how it actually behaves.

---

## 3. [High — new] The Account Type dropdown offers far more options than the business actually uses

**Steps to reproduce:**
1. Open a new or existing Account record.
2. Click the Account Type dropdown.
3. Review every option listed.

**Expected behavior:** Per business confirmation, **Individual** should be the only value available in this dropdown.

**Actual behavior:** The dropdown currently offers 14 values, all inherited from standard Salesforce and never trimmed down: Individual, Company, Analyst, Competitor, Customer, Dealer, Integrator, Investor, Other, Partner, Press, Prospect, Reseller, Service Partner.

**Note — this connects to issue #2 above:** the mandatory-Qatar-ID rule currently treats "Company" as the one exception that doesn't need an ID. If Company is removed from the list entirely per this fix, that exception logic in the rule will need to be revisited at the same time, since there'll no longer be any value it's designed to exempt.

**Where this comes from:** Confirmed directly with the business that only "Individual" should be selectable. Worth noting the Solution Design's own stated intent was already narrower than what's live — it describes the field as only meant to carry "Individual" and "Company" — so even that reduced intent was never enforced in the actual picklist configuration, let alone the further-reduced "Individual only" the business has now confirmed.

---

## 4. [Critical] There are three different fields for "alternate ID," and only one of them is ever actually used

**Steps to reproduce:**
1. As System Administrator, go to Setup → Object Manager → Account → Fields & Relationships.
2. Search for fields related to identification. Note three exist: "Other ID Number," "Open Identification," and "Open Identification Type."
3. Create a Lead with a value entered in its "Other ID Number" field, then convert that Lead into a Customer.
4. Check the resulting Account record: which of the three fields actually received the value?

**Expected behavior:** One clearly defined field should hold this information, consistently, everywhere it's used.

**Actual behavior:** Only "Other ID Number" gets filled in by Lead conversion. "Open Identification" and "Open Identification Type" are never touched by anything and sit permanently empty unless someone fills them in by hand.

**Where this comes from:**
- BRD — asks for one dedicated field for non-Qatari identification documents.
- Solution Design — introduces the extra pair of fields later in the project without removing or reconciling the original one.

---

## 5. [Critical] Three different names are used for the "Keyloop customer reference" field — and the one the integration team was told to use doesn't even exist

**Steps to reproduce:**
1. As System Administrator, go to Setup → Object Manager → Account → Fields & Relationships and search for "Keyloop."
2. Note two fields exist: "Keyloop Customer Reference" and "Customer Master Key."
3. Convert a Lead into a Customer and check both fields on the resulting Account.
4. Compare against the MuleSoft Integration Design document, which instructs writing the customer's Keyloop reference into a field called `AF_CustomerId`.

**Expected behavior:** One field should exist for this purpose, and the integration design should reference the field that actually exists.

**Actual behavior:** Two live fields exist, neither is ever populated by Lead conversion, and the integration document references a third field name that matches neither of them and doesn't exist in the system at all.

**Where this comes from:**
- Solution Design, Data Design section — defines one field for this purpose.
- Solution Design, "Key Changes" notes — adds a second field for the same purpose later.
- MuleSoft Integration Design document — instructs writing to a third field name that doesn't exist.

---

## 6. [High] When two customer records look like duplicates, only the newer one gets flagged — the older one never does

**Steps to reproduce:**
1. Note the phone number on an existing Account.
2. Create a brand-new Account using that same phone number.
3. Save, then check the new record's "Duplicate Status" field.
4. Go back and check the original, older Account's "Duplicate Status" field.

**Expected behavior:** Both records in the matching pair should show as flagged, so a data-cleanup report can find the whole pair.

**Actual behavior:** The new record is correctly marked "Potential Duplicate." The original, older record — the one it actually matches — still shows "None."

**Where this comes from:** Solution Design — describes the duplicate-check feature as flagging matches when a new or updated record shares a Qatar ID, phone, or email with an existing one, without saying it should apply to only one side of the match.

---

## 7. [High] There's an Email field directly on the Account that isn't supposed to be there, and nothing ever fills it in

**Steps to reproduce:**
1. As System Administrator, go to Setup → Object Manager → Account → Fields & Relationships and search for "Email."
2. Note the Account-level Email field exists.
3. Convert a Lead (with an email address on it) into a Customer, or check any existing customer's Account.
4. Check whether the Account-level Email field is ever filled in.

**Expected behavior:** Per the agreed design, a customer's email address should live only on the brand-specific Contact record underneath the Account — not on the shared Account itself.

**Actual behavior:** The field exists on Account anyway, and it's never populated by anything.

**Where this comes from:**
- Solution Design, confirmed field-governance notes — states that contact details like email belong at the brand/Contact level, not on the shared Account.
- Solution Design, "Key Changes" notes — adds an Email field to the Account anyway, without reconciling it against that rule.

---

## 8. [Medium] A safeguard for catching conflicting customer matches during Lead conversion was designed but never built

**Steps to reproduce:**
1. Set up a scenario where converting a Lead would match two *different* existing Accounts — for example, the Lead's Qatar ID matches one existing customer, but its phone number matches a completely different existing customer.
2. Convert that Lead.
3. Check both candidate Accounts for any field flagging that a conflicting match was found.

**Expected behavior:** Both Accounts should be flagged for manual review, since the system found two different, disagreeing matches.

**Actual behavior:** No such field exists on the Account object at all. The conversion silently proceeds with whichever match it finds first, with nothing alerting anyone that the match was ambiguous.

**Where this comes from:**
- Solution Design, Lead Management section — describes this exact safeguard and the field it should use.
- Solution Design, Open Items list — separately admits this safeguard was designed but never actually implemented.

---

## 9. [Low] The error message shown to users for an invalid Qatar ID includes an internal engineering note that was never cleaned up

**Steps to reproduce:**
1. Create or edit an Account.
2. Enter a Qatar ID that isn't exactly 11 digits (too short, too long, or containing letters).
3. Save.

**Expected behavior:** A clean, user-facing message stating the format rule.

**Actual behavior:** The message reads *"Qatar ID must be 11 numeric digits. (Placeholder rule — exact format pending customer confirmation.)"* — the parenthetical is clearly an internal note-to-self that was accidentally left in.

**Where this comes from:** Solution Design — the 11-digit rule is itself labeled internally as a placeholder pending confirmation; that internal label leaked directly into the live error text.

---

## 10. [Documentation only — no system fix needed] The design document gives conflicting instructions about what should happen when two customers share a Qatar ID

**Steps to reproduce:**
1. Create an Account with a Qatar ID.
2. Create a second Account using the exact same Qatar ID.
3. Save, and count how many separate error messages appear.

**Expected behavior (per the document, read literally):** Unclear — the document does not agree with itself.

**Actual behavior:** Exactly one error appears, from the Qatar ID field's own "must be unique" setting. No second, separate "duplicate detected" message appears from the Duplicate Rule feature.

**The conflict, and which fields/settings it's about:** This is about how two separate Salesforce features should be configured to work together: the **Qatar ID field's "Unique" setting** (a hard database-level rule) and the **Account Duplicate Rule** (a separate, configurable feature that checks for matching records and can be set to either warn or block). The design document gives three different instructions for this:
- One section says to configure the Duplicate Rule to **Block** whenever Qatar ID matches.
- Another section says doing that would be a mistake — it would be redundant with the Unique setting already blocking it, and would also break bulk data-loading if it caught blank Qatar IDs along the way.
- A third section describes the sensible approach — and what was actually built: let the Qatar ID field's Unique setting be the thing that blocks true duplicates, and leave the Duplicate Rule itself set to only warn (Alert), not block.

Since testing confirms only one error appears, the system was built the sensible (third) way. The document just needs its other two, contradictory sections removed so it stops disagreeing with itself.

**Where this comes from:** Solution Design, Account & Contact Management page — contains all three conflicting statements in the same document.

---

## 11. [Documentation only — no system fix needed] The design document says the customer record is one Salesforce record type in one place, and the opposite in another

**Steps to reproduce:**
1. Open any existing Account record and check its Record Type.
2. Convert a new Lead into a Customer and check the resulting Account's Record Type.
3. As System Administrator, go to Setup → Object Manager → Account → Record Types and check whether "Person Account" is active.

**Expected behavior (per the document, read literally):** Unclear — one part of the document says customer records should use the "Person Account" structure, another part says the opposite.

**Actual behavior:** Every Account in the system uses the ordinary "Business Account" record type. The custom "Person Account" record type exists but is switched off, and has literally been renamed to say it should not be used.

**The conflict, and which field/setting it's about:** This is about the **Account's Record Type**. Earlier in the project, the design called for customer records to use Salesforce's special "Person Account" structure (which merges an Account and its main Contact into a single record). That decision was later reversed — the design was changed to use the ordinary "Business Account" type instead, with brand-specific Contact records living underneath it (the "Brand Profile Contact" model explained separately). The problem is purely that the *earlier* section of the document describing the original Person Account decision was never deleted or corrected after the reversal, so the document currently contains both the old, outdated instruction and the newer, correct one, with nothing marking the old one as replaced.

**Where this comes from:**
- Solution Design, Account & Contact Management page — the outdated section still says Person Account.
- Solution Design, Data Model page — the corrected, more recent section confirms Business Account is what's actually live.

---

## Not yet tested (raised separately, not part of this ticket's findings)

A few related areas need further testing before we can say they're clean: whether a customer's shared record is properly protected from being seen/edited across different Alfardan business units (early signs suggest it currently isn't), whether the connection to Keyloop actually sends customer updates out correctly, and how the system handles a large bulk import of customer records. These will be covered in follow-up testing.
