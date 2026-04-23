import LightningModal from "lightning/modal";
import { api, track } from "lwc";
import retrieveOwnedGoogleFiles from "@salesforce/apex/GoogleCloudChatterController.retrieveOwnedGoogleFiles";
import GoogleCloudFileUploadModal from "c/googleCloudUploaderModal";

import {
  normalizeError,
  isEmpty,
  getFileIcon,
  formatFileSize
} from "c/googleCloudUtils";

const DEFAULT_MAX_SELECTION = 10;
const FILE_QUERY_LIMIT = 300;
const UPLOAD_SOURCE = "Chatter";

export default class GoogleCloudChatterFilePickerModal extends LightningModal {
  @api maxSelection = DEFAULT_MAX_SELECTION;
  @api selectedFileIds = [];
  @api recordId;

  @track isLoading = false;
  @track errorMessage = "";
  @track searchTerm = "";
  @track selectionMessage = "";
  @track rows = [];

  connectedCallback() {
    this.loadOwnedFiles();
  }

  async loadOwnedFiles() {
    this.isLoading = true;
    this.errorMessage = "";

    try {
      const initialSelection = new Set(
        (Array.isArray(this.selectedFileIds)
          ? this.selectedFileIds
          : []
        ).filter((id) => !isEmpty(id))
      );

      const files = await retrieveOwnedGoogleFiles({
        maxRecords: FILE_QUERY_LIMIT
      });

      this.rows = (Array.isArray(files) ? files : []).map((fileRecord) =>
        this.toRow(fileRecord, initialSelection)
      );
      this.selectionMessage = "";
    } catch (error) {
      this.errorMessage = normalizeError(error);
      this.rows = [];
    } finally {
      this.isLoading = false;
    }
  }

  toRow(fileRecord, selectedIdSet) {
    const fileName = fileRecord?.name || "Untitled";
    const metadataParts = [];

    if (fileRecord?.sizeBytes) {
      metadataParts.push(formatFileSize(fileRecord.sizeBytes));
    }

    if (!isEmpty(fileRecord?.mimeType)) {
      metadataParts.push(fileRecord.mimeType);
    }

    return {
      localId: fileRecord?.localId,
      fileName,
      icon: getFileIcon(fileName),
      ownerName: fileRecord?.createdBy?.name || "Unknown owner",
      info: metadataParts.join(" | "),
      isSelected: selectedIdSet.has(fileRecord?.localId)
    };
  }

  handleSearchChange(event) {
    this.searchTerm = (event.target.value || "").trim().toLowerCase();
  }

  handleSelectionChange(event) {
    const localId = event.target.dataset.fileId;
    const shouldSelect = event.target.checked === true;

    if (isEmpty(localId)) {
      return;
    }

    const row = this.rows.find((item) => item.localId === localId);
    if (!row) {
      return;
    }

    if (
      shouldSelect &&
      !row.isSelected &&
      this.selectedCount >= this.effectiveMaxSelection
    ) {
      this.selectionMessage = `You can select up to ${this.effectiveMaxSelection} files.`;
      this.rows = this.rows.map((item) => {
        if (item.localId !== localId) {
          return item;
        }

        return { ...item, isSelected: false };
      });
      return;
    }

    this.selectionMessage = "";
    this.rows = this.rows.map((item) => {
      if (item.localId !== localId) {
        return item;
      }

      return { ...item, isSelected: shouldSelect };
    });
  }

  handleUploadClick() {
    const input = this.refs.uploadInput;
    if (input) {
      input.click();
    }
  }

  handleUploadInputReset(event) {
    const input = event?.target || this.refs.uploadInput;
    if (input) {
      input.value = null;
    }
  }

  async handleUploadInputChange(event) {
    const selectedFiles = [...(event.target.files || [])];
    if (isEmpty(selectedFiles)) {
      return;
    }

    try {
      const uploadedFiles = await GoogleCloudFileUploadModal.open({
        recordId: this.recordId,
        uploadSource: UPLOAD_SOURCE,
        size: "small",
        inputFiles: selectedFiles
      });

      if (Array.isArray(uploadedFiles) && uploadedFiles.length > 0) {
        const existingIds = new Set(this.rows.map((r) => r.localId));
        const newRows = uploadedFiles
          .filter((f) => !isEmpty(f?.localId) && !existingIds.has(f.localId))
          .map((f) => {
            const fileName = f?.name || f?.fileName || "Untitled";
            return {
              localId: f.localId,
              fileName,
              icon: getFileIcon(fileName),
              ownerName: "Me",
              info: "",
              isSelected: true
            };
          });

        this.rows = [...newRows, ...this.rows];
      }
    } catch (error) {
      this.errorMessage = normalizeError(error);
    } finally {
      this.handleUploadInputReset(event);
    }
  }

  handleCancel() {
    this.close();
  }

  handleApply() {
    this.close(
      this.selectedRows.map((row) => ({
        localId: row.localId,
        fileName: row.fileName,
        icon: row.icon
      }))
    );
  }

  get effectiveMaxSelection() {
    const configuredMax = Number(this.maxSelection);
    if (!Number.isFinite(configuredMax) || configuredMax <= 0) {
      return DEFAULT_MAX_SELECTION;
    }

    return Math.min(DEFAULT_MAX_SELECTION, configuredMax);
  }

  get filteredRows() {
    if (isEmpty(this.searchTerm)) {
      return this.rows;
    }

    return this.rows.filter((row) => {
      const haystack =
        `${row.fileName} ${row.ownerName} ${row.info}`.toLowerCase();
      return haystack.includes(this.searchTerm);
    });
  }

  get hasRows() {
    return this.rows.length > 0;
  }

  get hasFilteredRows() {
    return this.filteredRows.length > 0;
  }

  get selectedRows() {
    return this.rows.filter((row) => row.isSelected);
  }

  get selectedCount() {
    return this.selectedRows.length;
  }

  get hasSelectionMessage() {
    return !isEmpty(this.selectionMessage);
  }

  get isApplyDisabled() {
    return this.isLoading || this.selectedCount <= 0;
  }

  get applyButtonLabel() {
    if (this.selectedCount <= 0) {
      return "Add files";
    }

    return this.selectedCount === 1
      ? "Add 1 file"
      : `Add ${this.selectedCount} files`;
  }
}
