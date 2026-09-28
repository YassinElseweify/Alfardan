/**
 * LFRDN-346 (ALF-RS-16) - Internal Requisition Form generation.
 *
 * Replaces the plain-text ContentVersion previously generated inline by
 * AF_FL_Opp_RequisitionApproved (via the generic AF_DocumentGenerationService) with a properly
 * styled PDF, matching AF_FL_AppraisalItem_GenerateBookInSheet's Eval Expert Book-In Sheet look
 * (Alfardan navy header, status pill, bordered detail tables) and rendered via the same
 * AF_PdfGenerationService (Blob.toPdf(), Spring 26+) used there - not a new custom PDF pipeline.
 *
 * A Flow-only body formula (the org's existing convention for single-record document bodies -
 * see AF_FL_AppraisalItem_GenerateBookInSheet, AF_FL_Opp_RequisitionApproved's old formula) can't
 * loop over the flagged OpportunityLineItems to list each accessory/PDI job spec, which AC1
 * requires ("vehicle details and job specifications populated"). No Flow in this org loops line
 * items into a string (confirmed by inspection of every Quote/Opportunity flow that builds an
 * HTML/text body); the one other document that needs line-item detail, the Sales Order
 * (AF_SalesOrderService), delegates to Apex for exactly this reason. This class follows that same
 * convention rather than inventing a new one.
 */
public with sharing class AF_InternalRequisitionFormService {

    public class Request {
        @InvocableVariable(required=true label='Opportunity Id')
        public Id opportunityId;
    }

    public class Result {
        @InvocableVariable public Id contentDocumentId;
        @InvocableVariable public Id contentVersionId;
    }

    @InvocableMethod(
        label='Generate Internal Requisition Form PDF'
        description='LFRDN-346: renders the approved Internal Requisition Form as a styled PDF (via AF_PdfGenerationService) listing the vehicle and every flagged accessory/PDI line item, and attaches it to the Opportunity.'
    )
    public static List<Result> generate(List<Request> requests) {
        List<Result> results = new List<Result>();
        if (requests == null || requests.isEmpty()) {
            return results;
        }

        Set<Id> opportunityIds = new Set<Id>();
        for (Request req : requests) {
            if (req.opportunityId != null) {
                opportunityIds.add(req.opportunityId);
            }
        }

        Map<Id, Opportunity> opportunities = new Map<Id, Opportunity>([
            SELECT Id, Name, AF_Brand__c, AF_RequisitionCompletionDate__c, AF_RequisitionStatus__c,
                   AF_SelectedVehicle__c, AF_SelectedVehicle__r.MakeName,
                   AF_SelectedVehicle__r.ModelName, AF_SelectedVehicle__r.ModelYear,
                   AF_SelectedVehicle__r.ManufacturedDate,
                   AF_SelectedVehicle__r.VehicleIdentificationNumber,
                   AF_SelectedVehicle__r.ExteriorColor,
                   AF_SelectedVehicle__r.VehicleDefinition.Name,
                   AF_SelectedVehicle__r.VehicleDefinition.VariantName,
                   AF_SelectedVehicle__r.VehicleDefinition.AF_Brand__c,
                   Owner.Name
            FROM Opportunity
            WHERE Id IN :opportunityIds
            WITH USER_MODE
        ]);

        // LFRDN-742: AF_PrimaryQuote__c is never populated by Create Quotation, so the form always
        // printed "-" for Quote Number. Reading Quote.IsSyncing alone isn't reliable either - live
        // QA check against the ticket's own reported record (Opportunity 006FV00BzHIbuJIYUZ / Quote
        // 00000236) found that Opportunity's one and only Quote has IsSyncing = false, because Quote
        // Sync only started reliably setting it after this session's earlier fix. Create Quotation
        // still only allows one Quote per deal (the ticket's own note), so ordering by
        // CreatedDate DESC and taking the newest Quote per Opportunity is the reliable read.
        Map<Id, String> quoteNumberByOpp = new Map<Id, String>();
        for (Quote q : [
            SELECT OpportunityId, QuoteNumber
            FROM Quote
            WHERE OpportunityId IN :opportunityIds
            WITH USER_MODE
            ORDER BY CreatedDate DESC
        ]) {
            if (!quoteNumberByOpp.containsKey(q.OpportunityId)) {
                quoteNumberByOpp.put(q.OpportunityId, q.QuoteNumber);
            }
        }

        Map<Id, List<OpportunityLineItem>> lineItemsByOpp = new Map<Id, List<OpportunityLineItem>>();
        for (OpportunityLineItem oli : [
            SELECT OpportunityId, Product2.Name, Quantity, AF_CustomizationDescription__c
            FROM OpportunityLineItem
            WHERE OpportunityId IN :opportunityIds
            AND AF_RequiresInternalRequisition__c = true
            WITH USER_MODE
            ORDER BY Product2.Name
        ]) {
            if (!lineItemsByOpp.containsKey(oli.OpportunityId)) {
                lineItemsByOpp.put(oli.OpportunityId, new List<OpportunityLineItem>());
            }
            lineItemsByOpp.get(oli.OpportunityId).add(oli);
        }

        // LFRDN-744: always inserting a fresh ContentVersion with FirstPublishLocationId created a
        // brand new ContentDocument every time, so re-requesting after a post-approval change left
        // two files both titled "Internal Requisition Form - <Opp Name>" with no way to tell which
        // was current (SD p.70: "regeneration replaces with version history via Files"). Looking up
        // the existing document by its ContentDocumentLink to this Opportunity + matching Title and
        // inserting the new PDF as ContentDocumentId (not FirstPublishLocationId) adds a version to
        // that same document instead of creating a second one; only falls back to a new document
        // when this is genuinely the first requisition for the deal.
        Map<Id, Id> existingDocumentIdByOpp = new Map<Id, Id>();
        for (ContentDocumentLink link : [
            SELECT LinkedEntityId, ContentDocumentId, ContentDocument.Title
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :opportunityIds
        ]) {
            Opportunity linkedOpp = opportunities.get(link.LinkedEntityId);
            if (linkedOpp != null && link.ContentDocument.Title == 'Internal Requisition Form - ' + linkedOpp.Name) {
                existingDocumentIdByOpp.put(link.LinkedEntityId, link.ContentDocumentId);
            }
        }

        List<ContentVersion> versionsToInsert = new List<ContentVersion>();
        List<Id> oppIdsForInsert = new List<Id>();

        for (Request req : requests) {
            Opportunity opp = opportunities.get(req.opportunityId);
            Result res = new Result();
            results.add(res);
            if (opp == null) {
                continue;
            }

            List<OpportunityLineItem> lines = lineItemsByOpp.get(opp.Id);
            if (lines == null) {
                lines = new List<OpportunityLineItem>();
            }

            ContentVersion cv = new ContentVersion();
            cv.Title = 'Internal Requisition Form - ' + opp.Name;
            cv.PathOnClient = 'Internal_Requisition_Form_' + opp.Id + '.pdf';
            cv.VersionData = Blob.toPdf(buildBody(opp, lines, quoteNumberByOpp.get(opp.Id)));

            Id existingDocumentId = existingDocumentIdByOpp.get(opp.Id);
            if (existingDocumentId != null) {
                cv.ContentDocumentId = existingDocumentId;
            } else {
                cv.FirstPublishLocationId = opp.Id;
            }

            versionsToInsert.add(cv);
            oppIdsForInsert.add(opp.Id);
        }

        if (versionsToInsert.isEmpty()) {
            return results;
        }

        insert as user versionsToInsert;

        Map<Id, ContentVersion> withDocIds = new Map<Id, ContentVersion>([
            SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id IN :versionsToInsert
        ]);

        Integer insertIdx = 0;
        for (Result res : results) {
            if (res.contentDocumentId != null || insertIdx >= versionsToInsert.size()) {
                continue;
            }
            ContentVersion cv = versionsToInsert[insertIdx];
            res.contentVersionId = cv.Id;
            res.contentDocumentId = withDocIds.get(cv.Id).ContentDocumentId;
            insertIdx++;
        }

        return results;
    }

    @TestVisible
    private static String buildBody(Opportunity opp, List<OpportunityLineItem> lines, String quoteNumber) {
        Boolean hasVehicle = opp.AF_SelectedVehicle__c != null;

        // LFRDN-746: the form was only ever generated after approval (status pill hardcoded
        // "Approved"), so the Sales Manager approved blind - no vehicle, no job list, no form
        // existed at approval time. Now also generated on submission (Pending Approval) so the
        // approver has something to review; the pill and description reflect whichever status the
        // Opportunity was at when this render ran.
        Boolean isApproved = opp.AF_RequisitionStatus__c == 'Approved';
        String statusPillColor = isApproved ? 'background:#DFF3E6;color:#1E7A46;' : 'background:#FCEFC7;color:#8A6D00;';
        String statusLabel = isApproved ? 'Approved' : 'Pending Approval';
        String statusDescription = isApproved
            ? 'PDI and accessory fitting requisition, approved by the Sales Manager, for action by the After Sales team.'
            : 'PDI and accessory fitting requisition, awaiting Sales Manager approval before it can be issued to the After Sales team.';

        // LFRDN-742: make/model live on VehicleDefinition (the model line), not on the Vehicle
        // record itself - every vehicle in the org had MakeName/ModelName blank because the form
        // was reading the wrong object, printing the literal string "null null". Same root cause
        // and fallback pattern as LFRDN-674's AF_SalesOrderService fix.
        VehicleDefinition vDef = hasVehicle ? opp.AF_SelectedVehicle__r.VehicleDefinition : null;
        String vehicleMake = vDef != null && String.isNotBlank(vDef.AF_Brand__c) ? vDef.AF_Brand__c
            : (hasVehicle ? opp.AF_SelectedVehicle__r.MakeName : null);
        String vehicleModel = vDef != null && String.isNotBlank(vDef.VariantName) ? vDef.VariantName
            : (hasVehicle ? opp.AF_SelectedVehicle__r.ModelName : null);
        String vehicleLabel = String.isBlank(vehicleMake) && String.isBlank(vehicleModel) ? null
            : (nv(vehicleMake) + ' ' + nv(vehicleModel)).trim();
        String modelYear = hasVehicle && opp.AF_SelectedVehicle__r.ModelYear != null ? String.valueOf(opp.AF_SelectedVehicle__r.ModelYear)
            : (hasVehicle && opp.AF_SelectedVehicle__r.ManufacturedDate != null ? String.valueOf(opp.AF_SelectedVehicle__r.ManufacturedDate.year()) : null);

        List<String> rows = new List<String>();
        for (OpportunityLineItem oli : lines) {
            rows.add(
                '<tr>' +
                '<td style="padding:10px 0;border-bottom:1px solid #EAEAEA;">' + nv(oli.Product2.Name) + '</td>' +
                '<td style="padding:10px 0;border-bottom:1px solid #EAEAEA;text-align:center;">' + (oli.Quantity == null ? '-' : String.valueOf(oli.Quantity.intValue())) + '</td>' +
                '<td style="padding:10px 0;border-bottom:1px solid #EAEAEA;">' + nv(oli.AF_CustomizationDescription__c) + '</td>' +
                '</tr>'
            );
        }
        String lineItemRows = rows.isEmpty()
            ? '<tr><td colspan="3" style="padding:10px 0;color:#9A9A9A;">No accessory/PDI line items were flagged.</td></tr>'
            : String.join(rows, '');

        return
            '<html><body style="margin:0;font-family:\'Arial Unicode MS\',Helvetica,Arial,sans-serif;color:#1A1A1A;">' +
            '<div style="max-width:680px;margin:0 auto;">' +
                '<div style="background:#0B2545;padding:24px 32px;">' +
                    '<div style="color:#8FA6C7;font-size:11px;font-weight:bold;letter-spacing:.1em;text-transform:uppercase;">Alfardan Automobiles</div>' +
                    '<h1 style="margin:6px 0 0;font-size:22px;color:#FFF;">Internal Requisition Form</h1>' +
                '</div>' +
                '<div style="padding:16px 32px 0;">' +
                    '<span style="display:inline-block;' + statusPillColor + 'font-size:11px;font-weight:bold;text-transform:uppercase;padding:5px 12px;border-radius:3px;">' + statusLabel + '</span>' +
                    '<p style="color:#6B6B6B;font-size:13px;line-height:1.5;margin:12px 0 0;">' + statusDescription + '</p>' +
                '</div>' +
                '<div style="padding:14px 32px 4px;">' +
                    '<div style="color:#0B2545;font-size:12px;font-weight:bold;text-transform:uppercase;border-bottom:2px solid #0B2545;padding-bottom:5px;">Opportunity &amp; Vehicle Details</div>' +
                    '<table style="width:100%;border-collapse:collapse;font-size:14px;">' +
                        '<tr><td style="padding:10px 0;width:38%;color:#6B6B6B;border-bottom:1px solid #EAEAEA;">Opportunity</td><td style="padding:10px 0;font-weight:600;border-bottom:1px solid #EAEAEA;">' + nv(opp.Name) + '</td></tr>' +
                        '<tr><td style="padding:10px 0;color:#6B6B6B;border-bottom:1px solid #EAEAEA;">Brand</td><td style="padding:10px 0;font-weight:600;border-bottom:1px solid #EAEAEA;">' + nv(opp.AF_Brand__c) + '</td></tr>' +
                        '<tr><td style="padding:10px 0;color:#6B6B6B;border-bottom:1px solid #EAEAEA;">Quote Number</td><td style="padding:10px 0;font-weight:600;border-bottom:1px solid #EAEAEA;">' + nv(quoteNumber) + '</td></tr>' +
                        '<tr><td style="padding:10px 0;color:#6B6B6B;border-bottom:1px solid #EAEAEA;">Vehicle</td><td style="padding:10px 0;font-weight:600;border-bottom:1px solid #EAEAEA;">' + nv(vehicleLabel) + '</td></tr>' +
                        '<tr><td style="padding:10px 0;color:#6B6B6B;border-bottom:1px solid #EAEAEA;">Model Year</td><td style="padding:10px 0;font-weight:600;border-bottom:1px solid #EAEAEA;">' + nv(modelYear) + '</td></tr>' +
                        '<tr><td style="padding:10px 0;color:#6B6B6B;border-bottom:1px solid #EAEAEA;">VIN</td><td style="padding:10px 0;font-weight:600;font-family:monospace;border-bottom:1px solid #EAEAEA;">' + nv(hasVehicle ? opp.AF_SelectedVehicle__r.VehicleIdentificationNumber : null) + '</td></tr>' +
                        '<tr><td style="padding:10px 0;color:#6B6B6B;border-bottom:1px solid #EAEAEA;">Exterior Colour</td><td style="padding:10px 0;font-weight:600;border-bottom:1px solid #EAEAEA;">' + nv(hasVehicle ? opp.AF_SelectedVehicle__r.ExteriorColor : null) + '</td></tr>' +
                        '<tr><td style="padding:10px 0;color:#6B6B6B;">Requested Completion Date</td><td style="padding:10px 0;font-weight:600;">' + dt(opp.AF_RequisitionCompletionDate__c) + '</td></tr>' +
                    '</table>' +
                '</div>' +
                '<div style="padding:4px 32px 20px;">' +
                    '<div style="color:#0B2545;font-size:12px;font-weight:bold;text-transform:uppercase;border-bottom:2px solid #0B2545;padding-bottom:5px;">Accessory / PDI Job Specifications</div>' +
                    '<table style="width:100%;border-collapse:collapse;font-size:14px;">' +
                        '<tr><td style="padding:8px 0;width:37%;color:#6B6B6B;font-size:11px;text-transform:uppercase;border-bottom:2px solid #EAEAEA;">Item</td><td style="padding:8px 0;width:8%;color:#6B6B6B;font-size:11px;text-transform:uppercase;text-align:center;border-bottom:2px solid #EAEAEA;">Qty</td><td style="padding:8px 0;width:55%;color:#6B6B6B;font-size:11px;text-transform:uppercase;border-bottom:2px solid #EAEAEA;">Job Specification</td></tr>' +
                        lineItemRows +
                    '</table>' +
                '</div>' +
                '<div style="border-top:1px solid #EAEAEA;padding:14px 32px;color:#9A9A9A;font-size:11px;">Sales Representative: ' + nv(opp.Owner != null ? opp.Owner.Name : null) + ' | Generated ' + System.now().format('dd MMM yyyy HH:mm') + '</div>' +
            '</div></body></html>';
    }

    // LFRDN-745: values were inserted into the HTML body unescaped, so anything in angle brackets
    // (e.g. "<front + rear>") was parsed as an HTML tag and silently dropped from the rendered PDF
    // - with no visual sign on the form that text was missing. escapeHtml4() must run before the
    // blank check, since an escaped non-blank string ("&lt;front...") should never fall through to "-".
    private static String nv(String value) {
        return String.isBlank(value) ? '-' : formatForPdf(value);
    }

    private static final Integer MAX_ARABIC_LINE_CHARS = 40;

    // Blob.toPdf() can't lay out Arabic: it reverses a run of Arabic letters and then joins them in the
    // reversed order, so words print as different words, and it prints Arabic presentation forms in the
    // order given. So text containing Arabic is shaped here and put into visual order one line at a time
    // (lines are broken here, so the renderer never wraps and scrambles the order). Text with no Arabic
    // is only escaped, as before.
    @TestVisible
    private static String formatForPdf(String value) {
        if (!Pattern.compile('[\\u0600-\\u06FF]').matcher(value).find()) {
            return value.escapeHtml4();
        }
        List<String> paragraphs = new List<String>();
        for (String paragraph : value.replace('\r', '').split('\n')) {
            Boolean rtl = isRtlParagraph(paragraph);
            List<String> visualLines = new List<String>();
            for (String line : wrapWords(paragraph)) {
                visualLines.add(toVisualOrder(line, rtl).escapeHtml4());
            }
            String joined = String.join(visualLines, '<br/>');
            paragraphs.add(rtl ? '<div style="text-align:right;">' + joined + '</div>' : joined);
        }
        return String.join(paragraphs, '<br/>');
    }

    private static List<String> wrapWords(String paragraph) {
        List<String> lines = new List<String>();
        String current = '';
        for (String word : paragraph.split(' ')) {
            if (current.length() > 0 && current.length() + 1 + word.length() > MAX_ARABIC_LINE_CHARS) {
                lines.add(current);
                current = word;
            } else {
                current = current.length() > 0 ? current + ' ' + word : word;
            }
        }
        lines.add(current);
        return lines;
    }

    private static Boolean isArabicChar(Integer c) {
        return (c >= 1536 && c <= 1791 && !(c >= 1632 && c <= 1641) && !(c >= 1776 && c <= 1785)) || (c >= 64336 && c <= 65279);
    }

    private static Boolean isStrongLtr(Integer c) {
        return (c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122)
            || (c >= 192 && c <= 591 && c != 215 && c != 247) || (c >= 1632 && c <= 1641) || (c >= 1776 && c <= 1785);
    }

    private static Boolean isRtlParagraph(String paragraph) {
        for (Integer c : paragraph.getChars()) {
            if (isArabicChar(c)) {
                return true;
            }
            if (isStrongLtr(c)) {
                return false;
            }
        }
        return false;
    }

    // Simplified bidi for one line: neutrals between two runs of the same direction take that direction,
    // otherwise the paragraph's; Arabic runs are shaped and reversed; in a right-to-left paragraph the run
    // order is reversed too. Digits and Latin keep their own left-to-right order.
    private static String toVisualOrder(String line, Boolean rtl) {
        List<Integer> cps = line.getChars();
        Integer n = cps.size();
        List<Boolean> strongRtl = new List<Boolean>();
        List<Boolean> isStrong = new List<Boolean>();
        for (Integer c : cps) {
            Boolean ar = isArabicChar(c);
            strongRtl.add(ar);
            isStrong.add(ar || isStrongLtr(c));
        }
        List<Boolean> resolvedRtl = new List<Boolean>();
        for (Integer i = 0; i < n; i++) {
            if (isStrong[i]) {
                resolvedRtl.add(strongRtl[i]);
                continue;
            }
            Integer p = i - 1;
            while (p >= 0 && !isStrong[p]) {
                p--;
            }
            Integer q = i + 1;
            while (q < n && !isStrong[q]) {
                q++;
            }
            Boolean before = p >= 0 ? strongRtl[p] : rtl;
            Boolean after = q < n ? strongRtl[q] : rtl;
            resolvedRtl.add(before == after ? before : rtl);
        }
        List<String> runs = new List<String>();
        Integer start = 0;
        for (Integer i = 1; i <= n; i++) {
            if (i == n || resolvedRtl[i] != resolvedRtl[start]) {
                List<Integer> slice = new List<Integer>();
                for (Integer k = start; k < i; k++) {
                    slice.add(cps[k]);
                }
                String run = String.fromCharArray(slice);
                runs.add(resolvedRtl[start] ? reverseMirrored(shapeArabic(run)) : run);
                start = i;
            }
        }
        if (rtl) {
            List<String> reversedRuns = new List<String>();
            for (Integer i = runs.size() - 1; i >= 0; i--) {
                reversedRuns.add(runs[i]);
            }
            runs = reversedRuns;
        }
        return String.join(runs, '');
    }

    private static String reverseMirrored(String value) {
        Map<Integer, Integer> mirror = new Map<Integer, Integer>{ 40 => 41, 41 => 40, 60 => 62, 62 => 60, 91 => 93, 93 => 91, 123 => 125, 125 => 123 };
        List<Integer> cps = value.getChars();
        List<Integer> out = new List<Integer>();
        for (Integer i = cps.size() - 1; i >= 0; i--) {
            out.add(mirror.containsKey(cps[i]) ? mirror.get(cps[i]) : cps[i]);
        }
        return String.fromCharArray(out);
    }

    private static Map<Integer, List<Integer>> arabicForms;

    // base letter => [isolated, final, initial, medial]; letters that never join the next one have only two
    private static Map<Integer, List<Integer>> getArabicForms() {
        if (arabicForms == null) {
            arabicForms = new Map<Integer, List<Integer>>{
                1569 => new List<Integer>{ 65152 },
                1570 => new List<Integer>{ 65153, 65154 }, 1571 => new List<Integer>{ 65155, 65156 },
                1572 => new List<Integer>{ 65157, 65158 }, 1573 => new List<Integer>{ 65159, 65160 },
                1574 => new List<Integer>{ 65161, 65162, 65163, 65164 }, 1575 => new List<Integer>{ 65165, 65166 },
                1576 => new List<Integer>{ 65167, 65168, 65169, 65170 }, 1577 => new List<Integer>{ 65171, 65172 },
                1578 => new List<Integer>{ 65173, 65174, 65175, 65176 }, 1579 => new List<Integer>{ 65177, 65178, 65179, 65180 },
                1580 => new List<Integer>{ 65181, 65182, 65183, 65184 }, 1581 => new List<Integer>{ 65185, 65186, 65187, 65188 },
                1582 => new List<Integer>{ 65189, 65190, 65191, 65192 }, 1583 => new List<Integer>{ 65193, 65194 },
                1584 => new List<Integer>{ 65195, 65196 }, 1585 => new List<Integer>{ 65197, 65198 },
                1586 => new List<Integer>{ 65199, 65200 }, 1587 => new List<Integer>{ 65201, 65202, 65203, 65204 },
                1588 => new List<Integer>{ 65205, 65206, 65207, 65208 }, 1589 => new List<Integer>{ 65209, 65210, 65211, 65212 },
                1590 => new List<Integer>{ 65213, 65214, 65215, 65216 }, 1591 => new List<Integer>{ 65217, 65218, 65219, 65220 },
                1592 => new List<Integer>{ 65221, 65222, 65223, 65224 }, 1593 => new List<Integer>{ 65225, 65226, 65227, 65228 },
                1594 => new List<Integer>{ 65229, 65230, 65231, 65232 }, 1601 => new List<Integer>{ 65233, 65234, 65235, 65236 },
                1602 => new List<Integer>{ 65237, 65238, 65239, 65240 }, 1603 => new List<Integer>{ 65241, 65242, 65243, 65244 },
                1604 => new List<Integer>{ 65245, 65246, 65247, 65248 }, 1605 => new List<Integer>{ 65249, 65250, 65251, 65252 },
                1606 => new List<Integer>{ 65253, 65254, 65255, 65256 }, 1607 => new List<Integer>{ 65257, 65258, 65259, 65260 },
                1608 => new List<Integer>{ 65261, 65262 }, 1609 => new List<Integer>{ 65263, 65264 },
                1610 => new List<Integer>{ 65265, 65266, 65267, 65268 },
                1662 => new List<Integer>{ 64342, 64343, 64344, 64345 }, 1670 => new List<Integer>{ 64378, 64379, 64380, 64381 },
                1688 => new List<Integer>{ 64394, 64395 }, 1705 => new List<Integer>{ 64398, 64399, 64400, 64401 },
                1711 => new List<Integer>{ 64402, 64403, 64404, 64405 }, 1740 => new List<Integer>{ 64508, 64509, 64510, 64511 }
            };
        }
        return arabicForms;
    }

    private static Boolean isArabicMark(Integer c) {
        return (c >= 1611 && c <= 1631) || c == 1648;
    }

    private static Boolean joinsToNext(Integer c) {
        return c == 1600 || (getArabicForms().containsKey(c) && getArabicForms().get(c).size() == 4);
    }

    private static Boolean joinsToPrevious(Integer c) {
        return c == 1600 || (getArabicForms().containsKey(c) && c != 1569);
    }

    // Contextual forms (isolated/final/initial/medial, plus lam-alef ligatures), in logical order.
    private static String shapeArabic(String value) {
        Map<Integer, Integer> lamAlefIsolated = new Map<Integer, Integer>{ 1570 => 65269, 1571 => 65271, 1573 => 65273, 1575 => 65275 };
        List<Integer> cps = value.getChars();
        List<Integer> result = new List<Integer>();
        Integer n = cps.size();
        for (Integer i = 0; i < n; i++) {
            Integer c = cps[i];
            if (!getArabicForms().containsKey(c)) {
                result.add(c);
                continue;
            }
            Integer p = i - 1;
            while (p >= 0 && isArabicMark(cps[p])) {
                p--;
            }
            Integer nx = i + 1;
            while (nx < n && isArabicMark(cps[nx])) {
                nx++;
            }
            Boolean prevJoins = p >= 0 && joinsToNext(cps[p]) && joinsToPrevious(c);
            if (c == 1604 && nx < n && lamAlefIsolated.containsKey(cps[nx])) {
                Integer ligature = lamAlefIsolated.get(cps[nx]);
                result.add(prevJoins ? ligature + 1 : ligature);
                for (Integer k = i + 1; k < nx; k++) {
                    result.add(cps[k]);
                }
                i = nx;
                continue;
            }
            Boolean nextJoins = joinsToNext(c) && nx < n && joinsToPrevious(cps[nx]);
            List<Integer> forms = getArabicForms().get(c);
            if (prevJoins && nextJoins) {
                result.add(forms[3]);
            } else if (nextJoins) {
                result.add(forms[2]);
            } else if (prevJoins) {
                result.add(forms.size() > 1 ? forms[1] : forms[0]);
            } else {
                result.add(forms[0]);
            }
        }
        return String.fromCharArray(result);
    }

    private static String dt(Date value) {
        return value == null ? '-' : DateTime.newInstance(value, Time.newInstance(0, 0, 0, 0)).format('dd MMM yyyy');
    }
}