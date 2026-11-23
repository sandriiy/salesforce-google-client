import { LightningElement, api } from 'lwc';

export default class GoogleCloudBaseCard extends LightningElement {
	@api title;
    @api iconName;
    @api subtitle;
    @api badgeText;
    @api showFooter = false;
    @api plainTitle = false;

    handleHeaderClick(event) {
        event.preventDefault();
        this.dispatchEvent(new CustomEvent('headerclick'));
    }
}