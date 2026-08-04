import { api, LightningElement } from 'lwc';

const USER_ID_PREFIX = '005';

export default class GoogleCloudFileExplorerUserCell extends LightningElement {
    @api userId;
    @api label;

    get isNavigable() {
        return typeof this.userId === 'string' && this.userId.startsWith(USER_ID_PREFIX);
    }

    handleClick(event) {
        event.preventDefault();
        event.stopPropagation();

        this.dispatchEvent(new CustomEvent('userclick', {
            bubbles: true,
            composed: true,
            detail: {
                userId: this.userId
            }
        }));
    }
}
