import LightningModal from 'lightning/modal';
import { api } from 'lwc';

import { normalizeError, showToast, truncateFileName } from 'c/googleCloudUtils';

import openInDrive from '@salesforce/apex/GoogleCloudDriveAccessController.openInDrive';

const MODAL_FILE_NAME_MAX_LENGTH = 40;
const DRIVE_TAB_FEATURES = 'noopener,noreferrer';

export default class GoogleCloudOpenInDriveModal extends LightningModal {
    @api label = 'Open in Google Drive';
    @api fileName;
    @api localGoogleFileId;
    @api localGoogleFileVersionId;

    isLoading = true;
    driveUrl;
    expiresOn;
    failureMessage;
    hasFocusedOpenButton = false;

    async connectedCallback() {
        await this.resolveDriveAccess();
    }

    renderedCallback() {
        if (this.isReady && !this.hasFocusedOpenButton) {
            this.hasFocusedOpenButton = true;
            this.refs.openButton?.focus();
        }
    }

    async resolveDriveAccess() {
        if (!this.localGoogleFileId || !this.localGoogleFileVersionId) {
            this.failureMessage = 'This file can’t be opened in Google Drive right now.';
            this.isLoading = false;
            return;
        }

        try {
            const access = await openInDrive({
                localGoogleFileId: this.localGoogleFileId,
                localGoogleFileVersionId: this.localGoogleFileVersionId
            });

            this.driveUrl = access?.driveUrl;
            this.expiresOn = access?.expiresOn;

            if (!this.driveUrl) {
                this.failureMessage = 'Google Drive didn’t return a link for this file. Please try again later.';
            }
        } catch (error) {
            this.failureMessage = normalizeError(error);
        } finally {
            this.isLoading = false;
        }
    }

    handleOpen() {
        if (!this.driveUrl) {
            return;
        }

        window.open(this.driveUrl, '_blank', DRIVE_TAB_FEATURES);
        this.close(true);
    }

    async handleCopyLink() {
        if (!this.driveUrl) {
            return;
        }

        try {
            await navigator.clipboard.writeText(this.driveUrl);
            showToast(this, 'Link copied', 'The Google Drive link is on your clipboard', 'success');
        } catch (error) {
            showToast(this, 'Unable to copy link', 'Use the open button instead', 'warning');
        }
    }

    handleCancel() {
        this.close(false);
    }

    get isReady() {
        return this.isLoading === false && !this.failureMessage && !!this.driveUrl;
    }

    get hasFailed() {
        return this.isLoading === false && !!this.failureMessage;
    }

    get displayFileName() {
        return truncateFileName(this.fileName, MODAL_FILE_NAME_MAX_LENGTH);
    }

    get accessMessage() {
        if (!this.expiresOn) {
            return 'You have now view access to this file in Google Drive.';
        }

        const readableDate = new Intl.DateTimeFormat(undefined, {
            dateStyle: 'medium',
            timeStyle: 'short'
        }).format(new Date(this.expiresOn));

        return `You have now view access to this file in Google Drive until ${readableDate}.`;
    }
}
