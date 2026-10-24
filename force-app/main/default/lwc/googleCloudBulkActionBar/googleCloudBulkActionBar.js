import { LightningElement, api } from 'lwc';

export default class GoogleCloudBulkActionBar extends LightningElement {
    @api selectedCount = 0;
    @api totalCount = 0;
    @api primaryLabel = 'Download';
    @api primaryIconName = 'utility:download';
    @api busyLabel = 'Downloading';
    @api stopLabel = 'Stop';
    @api busy = false;
    @api isStopping = false;
    @api hideActions = false;
    @api progress;

    get isVisible() {
        return this.busy === true || this.selectedCount > 0;
    }

    get showActions() {
        return this.hideActions !== true;
    }

    get selectionText() {
        if (this.totalCount > 0) {
            return `${this.selectedCount} of ${this.totalCount} selected`;
        }

        return `${this.selectedCount} selected`;
    }

    get primaryButtonLabel() {
        return `${this.primaryLabel} (${this.selectedCount})`;
    }

    get isPrimaryDisabled() {
        return !(this.selectedCount > 0);
    }

    get progressPercent() {
        const percent = Number(this.progress?.percent);
        if (!Number.isFinite(percent)) return 0;
        return Math.min(100, Math.max(0, Math.round(percent)));
    }

    get progressText() {
        if (this.isStopping === true) {
            return 'Stopping…';
        }

        if (this.progress?.statusText) {
            return this.progress.statusText;
        }

        const current = Number(this.progress?.current) || 0;
        const total = Number(this.progress?.total) || this.selectedCount || 0;
        const counter = total > 0 ? `${this.busyLabel} ${current} of ${total}` : `${this.busyLabel}…`;

        return this.progress?.fileName ? `${counter} · ${this.progress.fileName}` : counter;
    }

    handleConfirm() {
        this.dispatchEvent(new CustomEvent('confirm'));
    }

    handleClear() {
        this.dispatchEvent(new CustomEvent('clearselection'));
    }

    handleStop() {
        this.dispatchEvent(new CustomEvent('stop'));
    }
}
