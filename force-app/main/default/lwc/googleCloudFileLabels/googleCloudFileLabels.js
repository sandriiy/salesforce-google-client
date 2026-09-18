import { LightningElement, api, track } from 'lwc';

import retrieveLocalGoogleFileLabels from '@salesforce/apex/GoogleCloudFilesViewController.retrieveLocalGoogleFileLabels';

import { normalizeError, formatDateAsDayMonthYear } from 'c/googleCloudUtils';

const DEFAULT_ERROR_MESSAGE = 'Unable to retrieve the labels.';
const DEFAULT_LABEL_NAME = 'Untitled';
const LATEST_VERSION_SUFFIX = ' (latest)';

export default class GoogleCloudFileLabels extends LightningElement {
    @api recordId;

    @track labels = [];
    @track errorMessage = '';
    @track isLoading = false;

    connectedCallback() {
        this.loadLabels();
    }

    @api
    async refresh() {
        await this.loadLabels();
    }

    async loadLabels() {
        if (!this.recordId) {
            this.labels = [];
            this.errorMessage = '';
            this.isLoading = false;
            return;
        }

        this.isLoading = true;
        this.errorMessage = '';

        try {
            const result = await retrieveLocalGoogleFileLabels({ localFileRecordId: this.recordId });
            this.labels = this.buildLabelViewModels(result);
        } catch (error) {
            this.labels = [];
            this.errorMessage = normalizeError(error) || DEFAULT_ERROR_MESSAGE;
        } finally {
            this.isLoading = false;
        }
    }

    buildLabelViewModels(labels) {
        if (!Array.isArray(labels)) {
            return [];
        }

        return labels.map((label) => ({
            id: label.id,
            name: label.name || DEFAULT_LABEL_NAME,
            versionLabel: `${label.versionName || ''}${label.isLatestVersion ? LATEST_VERSION_SUFFIX : ''}`,
            appliedDateLabel: formatDateAsDayMonthYear(label.appliedDate),
            confidenceLabel: label.confidence == null ? '' : `${label.confidence}% confidence`
        }));
    }

    get hasLabels() {
        return this.labels.length > 0;
    }

    get hasError() {
        return this.errorMessage.length > 0;
    }

    get badgeText() {
        return this.hasLabels ? `(${String(this.labels.length)})` : '';
    }
}
