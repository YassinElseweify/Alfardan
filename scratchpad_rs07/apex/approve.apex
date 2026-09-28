Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();
req.setWorkitemId('04iFV001DUzw7MmYYI');
req.setAction('Approve');
req.setComments('QA RS07 - approve Tier 4 step 1 to test escalation');
try {
    Approval.ProcessResult r = Approval.process(req);
    System.debug('APPROVE_SUCCESS=' + r.isSuccess() + '|instanceStatus=' + r.getInstanceStatus());
    System.debug('NEW_WORKITEMS=' + r.getNewWorkitemIds());
} catch (Exception e) {
    System.debug('APPROVE_FAILED=' + e.getMessage());
}
