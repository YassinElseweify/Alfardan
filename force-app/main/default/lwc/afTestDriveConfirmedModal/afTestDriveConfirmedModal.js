import { api } from 'lwc';
import LightningModal from 'lightning/modal';

/**
 * A genuinely small modal for the "Test Drive Scheduled!" confirmation —
 * split out from afTestDriveScheduler because that screen was previously
 * rendered inline inside afDemoVehicleExplorerModal, which opens at
 * size:'full' for the browsing/scheduling steps. lightning/modal's size is
 * fixed for a given modal's lifetime (can't shrink one already-open modal
 * for its last screen), so the fix is to close that full-size modal and
 * open this small one instead, rather than trying to visually shrink content
 * inside a modal shell that stays full width regardless.
 */
export default class AfTestDriveConfirmedModal extends LightningModal {
    @api vehicleName;
    @api date;
    @api timeSlot;
    @api location;

    handleDone() {
        this.close();
    }
}