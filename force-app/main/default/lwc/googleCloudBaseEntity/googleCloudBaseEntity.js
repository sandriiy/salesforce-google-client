import { api, LightningElement } from 'lwc';

export default class GoogleCloudBaseEntity extends LightningElement {
	@api value;
	@api title;
	@api meta;
	@api detail;
	@api detailVariant = 'default';
	@api leadingIconName;
	@api leadingIconAlternativeText;
	@api trailingPrimary;
	@api trailingSecondary;

	handleClick() {
		this.dispatchEvent(new CustomEvent('entityclick', {
			detail: {
				value: this.value
			},
			bubbles: true,
			composed: true
		}));
	}

	get hasIconLeading() {
		return Boolean(this.leadingIconName);
	}

	get hasTrailing() {
		return Boolean(this.trailingPrimary || this.trailingSecondary);
	}

	get detailClass() {
		return this.detailVariant === 'warning'
			? 'base-entity__detail base-entity__detail--warning'
			: 'base-entity__detail';
	}

	get buttonTitle() {
		return this.title;
	}
}