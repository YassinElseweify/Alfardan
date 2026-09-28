trigger AF_VehicleImagesTrigger on ContentDocumentLink (after insert, after delete) {
    if (Trigger.isInsert) {
        AF_VehicleImagesHandler.handleAfterInsert(Trigger.new);
    } else if (Trigger.isDelete) {
        AF_VehicleImagesHandler.handleAfterDelete(Trigger.old);
    }
}