import { api, LightningElement } from 'lwc';

export default class GoogleCloudFileExplorerTitleCell extends LightningElement {
	@api rowId;
	@api label;
	@api titleText;

	handleClick(event) {
		event.preventDefault();
		event.stopPropagation();

		this.dispatchEvent(new CustomEvent('titleclick', {
			bubbles: true,
			composed: true,
			detail: {
				rowId: this.rowId
			}
		}));
	}
}