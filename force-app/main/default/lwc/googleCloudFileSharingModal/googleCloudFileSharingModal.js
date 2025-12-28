import { api } from 'lwc';
import LightningModal from 'lightning/modal';

export default class GoogleCloudFileSharingModal extends LightningModal {
	@api label;
	@api localFileRecordId;
}