import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAllSlots from '@salesforce/apex/AF_TestDriveSchedulerController.getAllSlots';
import getBookedSlots from '@salesforce/apex/AF_TestDriveSchedulerController.getBookedSlots';
import confirmSchedule from '@salesforce/apex/AF_TestDriveSchedulerController.confirmSchedule';

/**
 * Date + fixed-slot picker shown after Demo Vehicle selection (afDemoVehicleExplorer).
 * Already-booked slots for the chosen vehicle/date are removed from selection
 * (locked, matching the reference mockup) rather than just visually greyed with
 * no protection — this is a real block, re-validated server-side on confirm.
 * On confirm, Status is set to Scheduled so the existing completion-Task ->
 * confirmation-email chain (AF_FL_Task_TestDriveConfirmationEmail) can fire once
 * the owner's "Complete Test Drive Details" Task is closed.
 */
export default class AfTestDriveScheduler extends LightningElement {
    @api recordId; // Test Drive Id
    @api vehicleId;
    @api vehicleName;

    @track selectedDate = this.defaultDate();
    @track selectedSlot;
    @track bookedSlots = [];
    @track location = '';
    @track isLoadingSlots = true;
    @track isSubmitting = false;
    @track error;

    allSlots = [];

    connectedCallback() {
        getAllSlots()
            .then((slots) => {
                this.allSlots = slots || [];
                this.loadBookedSlots();
            })
            .catch((err) => this.handleError(err));
    }

    defaultDate() {
        const d = new Date();
        d.setDate(d.getDate() + 1);
        return d.toISOString().slice(0, 10);
    }

    loadBookedSlots() {
        this.isLoadingSlots = true;
        this.selectedSlot = undefined;
        getBookedSlots({ vehicleId: this.vehicleId, scheduleDate: this.selectedDate, testDriveId: this.recordId })
            .then((slots) => {
                this.bookedSlots = slots || [];
                this.error = undefined;
            })
            .catch((err) => this.handleError(err))
            .finally(() => {
                this.isLoadingSlots = false;
            });
    }

    handleDateChange(event) {
        this.selectedDate = event.target.value;
        if (this.selectedDate) {
            this.loadBookedSlots();
        }
    }

    handleLocationChange(event) {
        this.location = event.target.value;
    }

    handleSlotClick(event) {
        const slot = event.currentTarget.dataset.slot;
        if (this.bookedSlots.includes(slot)) {
            return;
        }
        this.selectedSlot = slot;
    }

    handleConfirm() {
        if (!this.selectedSlot) {
            this.showToast('Select a time slot', 'Choose an available time slot before confirming.', 'warning');
            return;
        }
        if (!this.location || !this.location.trim()) {
            this.showToast('Location required', 'Enter a location/showroom before confirming.', 'warning');
            return;
        }
        this.isSubmitting = true;

        confirmSchedule({
            testDriveId: this.recordId,
            vehicleId: this.vehicleId,
            scheduleDate: this.selectedDate,
            timeSlot: this.selectedSlot,
            location: this.location.trim()
        })
            .then(() => {
                // Confirmation is shown by the parent in its own small modal
                // (afTestDriveConfirmedModal) — not rendered here, since this
                // scheduler stays inside the full-size browsing modal, which
                // can't shrink for just this one screen.
                this.dispatchEvent(new CustomEvent('scheduled', {
                    bubbles: true,
                    composed: true,
                    detail: {
                        vehicleName: this.vehicleName,
                        date: this.formattedSelectedDate,
                        timeSlot: this.selectedSlot,
                        location: this.location.trim()
                    }
                }));
            })
            .catch((err) => {
                this.showToast('Could not confirm booking', this.extractErrorMessage(err), 'error');
                // A conflict here means someone else just took the slot — refresh so it shows locked.
                this.loadBookedSlots();
            })
            .finally(() => {
                this.isSubmitting = false;
            });
    }

    handleBack() {
        this.dispatchEvent(new CustomEvent('back', { bubbles: true, composed: true }));
    }

    handleError(err) {
        this.error = this.extractErrorMessage(err) || 'An error occurred loading slot availability.';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    extractErrorMessage(error) {
        return (error && error.body && error.body.message) || (error && error.message) || 'An unexpected error occurred.';
    }


    get slotItems() {
        return this.allSlots.map((label) => {
            const isBooked = this.bookedSlots.includes(label);
            const isSelected = this.selectedSlot === label;
            let cssClass = 'af-slot';
            if (isBooked) {
                cssClass += ' af-slot-booked';
            } else if (isSelected) {
                cssClass += ' af-slot-selected';
            }
            return { label, isBooked, isSelected, cssClass };
        });
    }

    get formattedSelectedDate() {
        if (!this.selectedDate) {
            return '';
        }
        const [year, month, day] = this.selectedDate.split('-').map(Number);
        const d = new Date(year, month - 1, day);
        return d.toLocaleDateString(undefined, { year: 'numeric', month: 'long', day: 'numeric' });
    }

    get minDate() {
        return new Date().toISOString().slice(0, 10);
    }

    get canConfirm() {
        return !!this.selectedSlot && !!this.location && this.location.trim().length > 0 && !this.isSubmitting;
    }

    get hasError() {
        return this.error !== undefined;
    }
}