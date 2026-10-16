import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import syncLeadDetails from '@salesforce/apex/FetchLeadDetailsController.syncLeadDetails';

export default class FetchLeadDetailsAction extends LightningElement {
    @api recordId;
    @track isProcessing = false;

    @api invoke() {
        this.isProcessing = true;
        
        syncLeadDetails({ recordId: this.recordId })
            .then(result => {
                this.showToast('Success', result, 'success');
                // Refresh the standard record page to show newly populated fields
                getRecordNotifyChange([{recordId: this.recordId}]);
            })
            .catch(error => {
                const errMsg = error.body ? error.body.message : error.message;
                this.showToast('Error', errMsg, 'error');
            })
            .finally(() => {
                this.isProcessing = false;
                this.dispatchEvent(new CloseActionScreenEvent());
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}