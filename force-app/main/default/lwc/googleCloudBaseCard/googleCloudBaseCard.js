import { LightningElement, api } from 'lwc';

export default class GoogleCloudBaseCard extends LightningElement {
	@api title;
    @api iconName;
    @api subtitle;
    @api badgeText;
    @api showFooter = false;

    handleHeaderClick() {
        this.dispatchEvent(new CustomEvent('headerclick'));
    }
}