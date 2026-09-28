({
    // See AF_SelectVehicleActionController.js for why Aura's native
    // force:closeQuickAction is used instead of the nested LWC's
    // CloseActionScreenEvent — same panel-ownership rationale applies here.
    handleLaunched: function (component, event, helper) {
        $A.get('e.force:closeQuickAction').fire();
    }
})