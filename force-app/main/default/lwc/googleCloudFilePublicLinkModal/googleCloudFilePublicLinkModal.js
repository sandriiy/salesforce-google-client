import { api } from 'lwc';
import LightningModal from 'lightning/modal';

export default class GoogleCloudFilePublicLinkModal extends LightningModal {
	@api label;
    @api localFileVersionId;
}