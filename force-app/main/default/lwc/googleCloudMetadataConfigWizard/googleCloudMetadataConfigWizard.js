import { LightningElement, track, wire } from 'lwc';

import { isEmpty, showToast, normalizeError } from 'c/googleCloudUtils';
import { gql, graphql } from 'lightning/uiGraphQLApi';

import validateConfig from '@salesforce/apex/GoogleCloudConfigController.validateMetadataConfig';
import saveConfig from '@salesforce/apex/GoogleCloudConfigController.saveMetadataConfig';

import QUICK_SETUP_LINK from '@salesforce/label/c.GoogleClientQuickSetupLink';

const LINKS = { quickSetup: QUICK_SETUP_LINK,};
const DEV_NAME = 'GoogleClient';
const QUERY = gql`
    query GoogleDriveClientConfigQuery {
        uiapi {
            query {
                GoogleClientConfig__mdt(
                    where: { DeveloperName: { eq: "GoogleClient" } }
                    first: 1
                ) {
                    edges {
                        node {
                            DeveloperName { value }
                            MasterLabel { value }

                            CustomGoogleAuthorizerClass__c { value }
                            DefaultGoogleUploadFolderId__c { value }
                            DefaultBigFileSize__c { value }
                            IsFilePreviewDisabled__c { value }
                            MaxDeleteChainSize__c { value }
                        }
                    }
                }
            }
        }
    }
`;

export default class GoogleDriveClientConfigWizard extends LightningElement {
    server = null;

    @track draft = {
        customGoogleAuthorizerClass: '',
        defaultGoogleUploadFolderId: '',
        defaultBigFileSize: null,
        isFilePreviewDisabled: false,
        maxDeleteChainSize: null
    };

    isLoading = true;
    busy = false;
    errorMessage = '';
    currentStep = '1';

    @wire(graphql, { query: QUERY })
    wiredConfig({ data, errors }) {
        this.isLoading = true;
        this.errorMessage = '';

        if (errors?.length) {
            this.errorMessage = errors.map(e => e.message).join(', ');
            this.isLoading = false;
            return;
        }

        try {
            const edge = data?.uiapi?.query?.GoogleClientConfig__mdt?.edges?.[0];
            const n = edge?.node;

            if (!n) {
                this.errorMessage = `No GoogleClientConfig__mdt record found for DeveloperName "${DEV_NAME}". Create it first.`;
                this.isLoading = false;
                return;
            }

            const snapshot = {
                developerName: n.DeveloperName?.value,
                masterLabel: n.MasterLabel?.value,
                customGoogleAuthorizerClass: n.CustomGoogleAuthorizerClass__c?.value,
                defaultGoogleUploadFolderId: n.DefaultGoogleUploadFolderId__c?.value,
                defaultBigFileSize: this.toNumberOrNull(n.DefaultBigFileSize__c?.value),
                isFilePreviewDisabled: !!n.IsFilePreviewDisabled__c?.value,
                maxDeleteChainSize: this.toNumberOrNull(n.MaxDeleteChainSize__c?.value)
            };

            this.server = snapshot;
            this.draft = {
                customGoogleAuthorizerClass: snapshot.customGoogleAuthorizerClass || '',
                defaultGoogleUploadFolderId: snapshot.defaultGoogleUploadFolderId || '',
                defaultBigFileSize: snapshot.defaultBigFileSize,
                isFilePreviewDisabled: snapshot.isFilePreviewDisabled,
                maxDeleteChainSize: snapshot.maxDeleteChainSize
            };

            this.currentStep = isEmpty(this.draft.customGoogleAuthorizerClass) 
				? '1' 
				: isEmpty(this.draft.defaultGoogleUploadFolderId) ? '2' : '3';
        } catch (e) {
            this.errorMessage = e?.message || 'Unknown error parsing GraphQL response';
        } finally {
            this.isLoading = false;
        }
    }

    get configDeveloperName() {
        return this.server?.developerName;
    }

    get isStep1() { return this.currentStep === '1'; }
    get isStep2() { return this.currentStep === '2'; }
    get isStep3() { return this.currentStep === '3'; }

    get step1HasValue() {
        return !isEmpty(this.draft.customGoogleAuthorizerClass);
    }

    get step2HasValue() {
        return !isEmpty(this.draft.defaultGoogleUploadFolderId);
    }

    get isDirty() {
        if (!this.server) return false;

        const s = this.server;
        const d = this.draft;

        return (
            (s.customGoogleAuthorizerClass || '') !== (d.customGoogleAuthorizerClass || '') ||
            (s.defaultGoogleUploadFolderId || '') !== (d.defaultGoogleUploadFolderId || '') ||
            (s.defaultBigFileSize ?? null) !== (d.defaultBigFileSize ?? null) ||
            !!s.isFilePreviewDisabled !== !!d.isFilePreviewDisabled ||
            (s.maxDeleteChainSize ?? null) !== (d.maxDeleteChainSize ?? null)
        );
    }

    get saveDisabled() {
        return this.isLoading || this.busy || !this.isDirty || !this.server?.developerName;
    }

    handleStepClick(event) {
        const stepValue = event?.target?.value;
        if (!stepValue) return;

        if (stepValue === '2' && !this.step1HasValue) {
			showToast(
				this,
				'Incomplete Stage 1',
				'Provide and validate the authorizer class before continuing',
				'warning'
			);

            this.currentStep = '1';
            return;
        }

        if (stepValue === '3' && (!this.step1HasValue || !this.step2HasValue)) {
			showToast(
				this,
				'Incomplete Stages',
				'Finish Stage 1 and Stage 2 before opening Other Settings',
				'warning'
			);

            this.currentStep = !this.step1HasValue ? '1' : '2';
            return;
        }

        this.currentStep = stepValue;
    }

    goStep1() {
		this.currentStep = '1'
	}

    goStep2() {
        if (!this.step1HasValue) {
			showToast(
				this,
				'Incomplete Stage 1',
				'Provide the authorizer class first',
				'warning'
			);

            return;
        }

        this.currentStep = '2';
    };

    goStep3() {
        if (!this.step1HasValue || !this.step2HasValue) {
			showToast(
				this,
				'Incomplete Stages',
				'Complete Stage 1 and Stage 2 first',
				'warning'
			);

            return;
        }
		
        this.currentStep = '3';
    };

    handleChange(event) {
        const field = event.target.dataset.field;
        this.draft = { ...this.draft, [field]: event.target.value };
    }

    handleChangeNumber(event) {
        const field = event.target.dataset.field;
        this.draft = { ...this.draft, [field]: this.toNumberOrNull(event.target.value) };
    }

    handleToggle(event) {
        const field = event.target.dataset.field;
        this.draft = { ...this.draft, [field]: event.target.checked };
    }

    async handleValidate() {
        this.busy = true;
        try {
            const className = this.draft.customGoogleAuthorizerClass;
			if (!isEmpty(className)) {
				const responseMessage = await validateConfig({ className });
				showToast(this, 'Validation Successful', responseMessage, 'success');
			}
        } catch (e) {
			showToast(this, 'Validation Error', normalizeError(e), 'error');
        } finally {
            this.busy = false;
        }
    }

    async handleSave() {
        this.busy = true;
        try {
            const changes = this.buildChangedFieldMap();
			if (!this.hasInputErrors()) {
				if ('CustomGoogleAuthorizerClass__c' in changes && !isEmpty(this.draft.customGoogleAuthorizerClass)) {
					await validateConfig({ className: this.draft.customGoogleAuthorizerClass });
				}

				await saveConfig({fieldApiToValue: changes});
				showToast(this, 'Saved Successful', '', 'success');

				this.server = {
					...this.server,
					customGoogleAuthorizerClass: this.draft.customGoogleAuthorizerClass || '',
					defaultGoogleUploadFolderId: this.draft.defaultGoogleUploadFolderId || '',
					defaultBigFileSize: this.draft.defaultBigFileSize,
					isFilePreviewDisabled: !!this.draft.isFilePreviewDisabled,
					maxDeleteChainSize: this.draft.maxDeleteChainSize
				};
			}
        } catch (e) {
			showToast(this, 'Save Failed', normalizeError(e), 'error');
        } finally {
            this.busy = false;
        }
    }

    buildChangedFieldMap() {
        const s = this.server;
        const d = this.draft;

        const map = {};
        this.putIfChanged(map, 'CustomGoogleAuthorizerClass__c', s.customGoogleAuthorizerClass, d.customGoogleAuthorizerClass);
        this.putIfChanged(map, 'DefaultGoogleUploadFolderId__c', s.defaultGoogleUploadFolderId, d.defaultGoogleUploadFolderId);
        this.putIfChanged(map, 'DefaultBigFileSize__c', s.defaultBigFileSize, d.defaultBigFileSize);
        this.putIfChanged(map, 'IsFilePreviewDisabled__c', !!s.isFilePreviewDisabled, !!d.isFilePreviewDisabled);
        this.putIfChanged(map, 'MaxDeleteChainSize__c', s.maxDeleteChainSize, d.maxDeleteChainSize);

        return map;
    }

    putIfChanged(map, apiName, oldVal, newVal) {
        const a = oldVal ?? null;
        const b = newVal ?? null;
        if (a !== b) map[apiName] = b;
    }

    openQuickSetupGuide() {
        window.open(LINKS.quickSetup, '_blank');
    }

    toNumberOrNull(v) {
        if (v === null || v === undefined || String(v).trim() === '') return null;
        const n = Number(v);
        return Number.isFinite(n) ? n : null;
    }

    hasInputErrors(selector = 'lightning-input', toastTitle = 'Invalid Fields', toastMessage = 'Please review the highlighted fields and try again') {
		const inputs = Array.from(this.template.querySelectorAll(selector));

		if (!inputs.length) {
			return false;
		}

		let hasErrors = false;
		inputs.forEach((input) => {
			if (typeof input.reportValidity === 'function') {
				input.reportValidity();
			}

			if (typeof input.checkValidity === 'function' && !input.checkValidity()) {
				hasErrors = true;
			}
		});

		if (hasErrors) {
			showToast(this, toastTitle, toastMessage, 'error');
			return true;
		}

		return false;
	}
}