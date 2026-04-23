import { api, LightningElement, track } from "lwc";

import loadFeed from "@salesforce/apex/GoogleCloudChatterController.loadFeed";
import createFeedItemDirect from "@salesforce/apex/GoogleCloudChatterController.createFeedItemDirect";
import createFeedComment from "@salesforce/apex/GoogleCloudChatterController.createFeedComment";

import GoogleCloudChatterFilePickerModal from "c/googleCloudChatterFilePickerModal";
import GoogleCloudFileUploadModal from "c/googleCloudUploaderModal";
import { isExperienceCloudContext } from "c/googleCloudCrossPlatformUtils";
import {
  showToast,
  normalizeError,
  isEmpty,
  getFileIcon,
  formatFileSize
} from "c/googleCloudUtils";

const PUBLISHER_TYPE = {
  POST: "POST",
  POLL: "POLL",
  QUESTION: "QUESTION"
};

const FEED_LIMIT = 30;
const MIN_POLL_CHOICES = 2;
const MAX_POLL_CHOICES = 10;
const MAX_FILES_PER_PUBLISH = 10;
const EXPERIENCE_UPLOAD_SOURCE = "Chatter";

const MODE = {
  READ_ONLY: "READ_ONLY",
  READ_WRITE: "READ_WRITE"
};

const DEFAULT_ALLOWED_PUBLISHER_TYPES = [
  PUBLISHER_TYPE.POST,
  PUBLISHER_TYPE.POLL,
  PUBLISHER_TYPE.QUESTION
];

export default class GoogleCloudChatter extends LightningElement {
  _recordId;
  resolvedParentRecordId;
  pollChoiceCounter = 2;

  @api publisherTabs = "POST_POLL_QUESTION";
  @api readOnly = false;
  @api mode = MODE.READ_WRITE;

  @track isLoading = false;
  @track isPublishing = false;
  @track errorMessage = "";
  @track activePublisherType = PUBLISHER_TYPE.POST;
  @track isPublisherExpanded = false;

  @track postBody = "";
  @track pollQuestion = "";
  @track questionBody = "";
  @track pollChoices = [
    { id: "poll-choice-1", value: "" },
    { id: "poll-choice-2", value: "" }
  ];

  @track selectedGoogleFiles = [];
  @track feedItems = [];
  @track sortOrder = "DESC";
  @track searchTerm = "";
  @track audienceOptions = [];
  @track selectedAudienceValue = "";

  @track capabilities = {
    canReadFeed: false,
    canCreatePosts: false,
    canCreateComments: false,
    canToggleLikes: false,
    canAttachGoogleFiles: false,
    isReadOnlyMode: false,
    allowedPublisherTypes: DEFAULT_ALLOWED_PUBLISHER_TYPES
  };

  commentDraftByFeedItemId = {};
  isExperienceSite = false;

  richTextFormats = [
    "font",
    "size",
    "bold",
    "italic",
    "underline",
    "strike",
    "list",
    "indent",
    "link",
    "clean"
  ];

  @api
  get recordId() {
    return this._recordId;
  }

  set recordId(value) {
    const normalizedValue = value || null;
    const hasChanged = normalizedValue !== this._recordId;
    this._recordId = normalizedValue;

    if (!isEmpty(normalizedValue)) {
      this.resolvedParentRecordId = normalizedValue;
    }

    if (!this.effectiveParentRecordId) {
      this.feedItems = [];
      this.errorMessage = "";
      return;
    }

    if (hasChanged && this.isConnected) {
      this.loadFeedData();
    }
  }

  connectedCallback() {
    this.isExperienceSite = isExperienceCloudContext();

    if (isEmpty(this.resolvedParentRecordId)) {
      this.resolvedParentRecordId = this.inferRecordIdFromLocation();
    }

    this.ensureActivePublisherType();

    if (this.effectiveParentRecordId) {
      this.loadFeedData();
    }
  }

  async loadFeedData() {
    const parentRecordId = this.effectiveParentRecordId;
    if (!parentRecordId) return;

    this.isLoading = true;
    this.errorMessage = "";

    try {
      const response = await loadFeed({
        parentRecordId,
        feedLimitSize: FEED_LIMIT,
        mode: this.componentMode,
        publisherTabs: this.publisherTabs
      });

      if (!isEmpty(response?.parentRecordId)) {
        this.resolvedParentRecordId = response.parentRecordId;
      }

      const responseCapabilities = response?.capabilities || {};
      const serverAllowedPublisherTypes = Array.isArray(
        responseCapabilities.allowedPublisherTypes
      )
        ? responseCapabilities.allowedPublisherTypes
            .map((value) => (value || "").trim().toUpperCase())
            .filter((value) => !isEmpty(value))
        : [];

      this.capabilities = {
        canReadFeed: responseCapabilities.canReadFeed === true,
        canCreatePosts: responseCapabilities.canCreatePosts === true,
        canCreateComments: responseCapabilities.canCreateComments === true,
        canToggleLikes: false,
        canAttachGoogleFiles:
          responseCapabilities.canAttachGoogleFiles === true,
        isReadOnlyMode: responseCapabilities.isReadOnlyMode === true,
        allowedPublisherTypes:
          serverAllowedPublisherTypes.length > 0
            ? serverAllowedPublisherTypes
            : DEFAULT_ALLOWED_PUBLISHER_TYPES
      };

      const loadedAudienceOptions = Array.isArray(
        responseCapabilities.audienceOptions
      )
        ? responseCapabilities.audienceOptions
            .filter((option) => !isEmpty(option?.value))
            .map((option) => ({
              value: option.value,
              label: option.label || option.value
            }))
        : [];

      this.audienceOptions = loadedAudienceOptions;

      const suggestedDefaultAudience =
        responseCapabilities.defaultAudienceValue ||
        loadedAudienceOptions[0]?.value ||
        "";
      const hasCurrentAudience = loadedAudienceOptions.some(
        (option) => option.value === this.selectedAudienceValue
      );
      this.selectedAudienceValue = hasCurrentAudience
        ? this.selectedAudienceValue
        : suggestedDefaultAudience;

      this.feedItems = this.mapFeedItems(response?.items || []);
      this.ensureActivePublisherType();
    } catch (error) {
      this.errorMessage = normalizeError(error);
      this.feedItems = [];
    } finally {
      this.isLoading = false;
    }
  }

  mapFeedItems(rawItems) {
    return (rawItems || []).map((rawItem) => this.decorateFeedItem(rawItem));
  }

  decorateFeedItem(rawItem) {
    const comments = (rawItem.comments || []).map((rawComment) =>
      this.decorateFeedComment(rawComment)
    );
    const googleFiles = (rawItem.googleFiles || []).map((rawFile) =>
      this.decorateGoogleFile(rawFile)
    );
    const pollChoices = (rawItem.pollChoices || []).map((rawChoice) =>
      this.decoratePollChoice(rawChoice)
    );

    const pendingComment = this.commentDraftByFeedItemId[rawItem.id] || "";
    const commentCount = comments.length;

    return {
      ...rawItem,
      title: rawItem.title || "",
      body: rawItem.body || "",
      bodyText: this.stripHtml(rawItem.body || ""),
      authorName: rawItem.author?.name || "Unknown",
      authorInitials: this.resolveInitials(rawItem.author?.name),
      authorPhotoUrl: rawItem.author?.photoUrl,
      createdDateLabel: this.formatRelativeDate(rawItem.createdDate),
      isCommentSaving: false,
      comments,
      hasComments: comments.length > 0,
      commentSummary: this.buildCommentSummary(commentCount),
      pendingComment,
      isCommentSubmitDisabled: isEmpty(pendingComment.trim()),
      googleFiles,
      hasGoogleFiles: googleFiles.length > 0,
      isPoll: rawItem.type === "PollPost",
      isQuestion: rawItem.type === "QuestionPost",
      hasPollChoices: pollChoices.length > 0,
      pollChoices
    };
  }

  decorateFeedComment(rawComment) {
    return {
      ...rawComment,
      commentBody: rawComment.commentBody || "",
      authorName: rawComment.author?.name || "Unknown",
      authorInitials: this.resolveInitials(rawComment.author?.name),
      authorPhotoUrl: rawComment.author?.photoUrl,
      createdDateLabel: this.formatRelativeDate(rawComment.createdDate)
    };
  }

  decorateGoogleFile(rawFile) {
    const fileName = rawFile.name || "Untitled";
    const parts = [];

    if (rawFile.sizeBytes) {
      parts.push(formatFileSize(rawFile.sizeBytes));
    }

    if (rawFile.mimeType) {
      parts.push(rawFile.mimeType);
    }

    return {
      ...rawFile,
      localId: rawFile.localId,
      fileName,
      icon: getFileIcon(fileName),
      info: parts.join(" | ")
    };
  }

  decoratePollChoice(rawChoice) {
    const voteCount = Number.isFinite(rawChoice?.voteCount)
      ? rawChoice.voteCount
      : null;

    return {
      ...rawChoice,
      hasVoteCount: voteCount !== null,
      voteCountLabel:
        voteCount === null
          ? ""
          : `${voteCount} ${voteCount === 1 ? "vote" : "votes"}`
    };
  }

  handleTabClick(event) {
    const type = (event.currentTarget.dataset.type || "").trim().toUpperCase();
    if (type) {
      this.activePublisherType = type;
    }
    this.handleExpandPublisher();
  }

  handleExpandPublisher() {
    if (!this.canShowPublisher) {
      return;
    }

    this.isPublisherExpanded = true;
  }

  handleCollapsePublisher() {
    this.isPublisherExpanded = false;
  }

  handlePostBodyChange(event) {
    this.postBody = event.detail.value || "";
  }

  handleQuestionBodyChange(event) {
    this.questionBody = event.target.value || "";
  }

  handlePollQuestionChange(event) {
    this.pollQuestion = event.target.value || "";
  }

  handlePollChoiceChange(event) {
    const choiceId = event.target.dataset.choiceId;
    const value = event.target.value || "";

    this.pollChoices = this.pollChoices.map((choice) => {
      if (choice.id !== choiceId) return choice;
      return { ...choice, value };
    });
  }

  handleAddPollChoice() {
    if (this.pollChoices.length >= MAX_POLL_CHOICES) {
      showToast(
        this,
        "Maximum choices reached",
        `A poll supports up to ${MAX_POLL_CHOICES} choices in this component.`,
        "warning"
      );
      return;
    }

    this.pollChoiceCounter += 1;
    this.pollChoices = [
      ...this.pollChoices,
      { id: `poll-choice-${this.pollChoiceCounter}`, value: "" }
    ];
  }

  handleRemovePollChoice(event) {
    const choiceId = event.currentTarget.dataset.choiceId;
    if (this.pollChoices.length <= MIN_POLL_CHOICES) {
      return;
    }

    this.pollChoices = this.pollChoices.filter(
      (choice) => choice.id !== choiceId
    );
  }

  async handleAttachGoogleFile() {
    if (
      !this.canAttachGoogleFiles ||
      this.isPublishing ||
      this.attachmentLimitReached
    ) {
      return;
    }

    if (this.isExperienceSite) {
      this.openExperienceUploadInput();
      return;
    }

    try {
      const selectedFiles = await GoogleCloudChatterFilePickerModal.open({
        size: "large",
        maxSelection: MAX_FILES_PER_PUBLISH,
        recordId: this.effectiveParentRecordId,
        selectedFileIds: this.selectedGoogleFiles.map(
          (fileRecord) => fileRecord.localId
        )
      });

      if (!Array.isArray(selectedFiles) || selectedFiles.length <= 0) {
        return;
      }

      this.selectedGoogleFiles = selectedFiles
        .filter((fileRecord) => !isEmpty(fileRecord?.localId))
        .slice(0, MAX_FILES_PER_PUBLISH)
        .map((fileRecord) => {
          const fileName = fileRecord.fileName || "Untitled";
          return {
            localId: fileRecord.localId,
            fileName,
            icon: getFileIcon(fileName)
          };
        });
    } catch (error) {
      showToast(
        this,
        "Unable to open file picker",
        normalizeError(error),
        "error"
      );
    }
  }

  openExperienceUploadInput() {
    const fileInput = this.refs.experienceUploadInput;
    if (fileInput) {
      fileInput.click();
    }
  }

  handleExperienceFileInputReset(event) {
    const input = event?.target || this.refs.experienceUploadInput;
    if (input) {
      input.value = null;
    }
  }

  async handleExperienceFileSelected(event) {
    const selectedFiles = [...(event.target.files || [])];
    if (isEmpty(selectedFiles)) {
      return;
    }

    const parentRecordId = this.effectiveParentRecordId;
    if (isEmpty(parentRecordId)) {
      showToast(
        this,
        "Missing record context",
        "Unable to upload because no record context is available.",
        "error"
      );
      this.handleExperienceFileInputReset(event);
      return;
    }

    try {
      const uploadedFiles = await GoogleCloudFileUploadModal.open({
        recordId: parentRecordId,
        uploadSource: EXPERIENCE_UPLOAD_SOURCE,
        size: "small",
        inputFiles: selectedFiles
      });

      this.applyUploadedFiles(uploadedFiles);
    } catch (error) {
      showToast(
        this,
        "Unable to upload file(s)",
        normalizeError(error),
        "error"
      );
    } finally {
      this.handleExperienceFileInputReset(event);
    }
  }

  applyUploadedFiles(uploadedFiles) {
    const uploadedList = Array.isArray(uploadedFiles) ? uploadedFiles : [];
    if (isEmpty(uploadedList)) {
      return;
    }

    const existingIds = new Set(
      this.selectedGoogleFiles.map((fileRecord) => fileRecord.localId)
    );
    const additions = [];

    uploadedList.forEach((uploadedFile) => {
      if (
        this.selectedGoogleFiles.length + additions.length >=
        MAX_FILES_PER_PUBLISH
      ) {
        return;
      }

      const localId = uploadedFile?.localId || uploadedFile?.Id;
      if (isEmpty(localId) || existingIds.has(localId)) {
        return;
      }

      const fileName =
        uploadedFile?.name || uploadedFile?.fileName || "Untitled";
      additions.push({
        localId,
        fileName,
        icon: getFileIcon(fileName)
      });

      existingIds.add(localId);
    });

    if (!isEmpty(additions)) {
      this.selectedGoogleFiles = [...this.selectedGoogleFiles, ...additions];
    }

    if (this.selectedGoogleFiles.length >= MAX_FILES_PER_PUBLISH) {
      showToast(
        this,
        "Attachment limit reached",
        `You can attach up to ${MAX_FILES_PER_PUBLISH} files.`,
        "info"
      );
    }
  }

  handleAudienceChange(event) {
    this.selectedAudienceValue = event.detail.value;
  }

  handleRemoveSelectedFile(event) {
    const localFileId = event.currentTarget.dataset.fileId;
    this.selectedGoogleFiles = this.selectedGoogleFiles.filter(
      (fileRecord) => fileRecord.localId !== localFileId
    );
  }

  handlePreviewSelectedFile(event) {
    const localFileId = event.currentTarget.dataset.fileId;
    this.openFilePreview(localFileId);
  }

  handleFeedFilePreview(event) {
    const localFileId = event.currentTarget.dataset.fileId;
    this.openFilePreview(localFileId);
  }

  openFilePreview(localFileId) {
    const previewModal = this.refs.filePreviewModal;
    if (!previewModal || !localFileId) return;
    previewModal.open(localFileId);
  }

  async handlePublish() {
    if (this.isPublishDisabled || this.isPublishing) return;

    const parentRecordId = this.effectiveParentRecordId;
    if (isEmpty(parentRecordId)) {
      showToast(
        this,
        "Missing record context",
        "Unable to publish because no parent record was resolved.",
        "error"
      );
      return;
    }

    this.isPublishing = true;

    try {
      const createdFeedItem = await createFeedItemDirect({
        parentRecordId,
        publisherType: this.activePublisherType,
        body: this.resolvePublisherBody(),
        visibility: this.selectedAudienceValue || null,
        pollChoices: this.isPollMode ? this.validPollChoices : [],
        googleFileIds: this.selectedGoogleFiles
          .map((fileRecord) => fileRecord.localId)
          .filter((fileId) => !isEmpty(fileId)),
        mode: this.componentMode,
        publisherTabs: this.publisherTabs
      });

      const decoratedFeedItem = this.decorateFeedItem(createdFeedItem);
      this.feedItems = [decoratedFeedItem, ...this.feedItems];

      this.resetPublisher();
      showToast(
        this,
        "Success",
        this.resolvePublishSuccessMessage(),
        "success"
      );
    } catch (error) {
      showToast(this, "Unable to publish", normalizeError(error), "error");
    } finally {
      this.isPublishing = false;
    }
  }

  handleCommentChange(event) {
    const feedItemId = event.target.dataset.feedItemId;
    const value = event.target.value || "";

    if (!feedItemId) return;

    this.commentDraftByFeedItemId = {
      ...this.commentDraftByFeedItemId,
      [feedItemId]: value
    };

    this.markFeedItemState(feedItemId, {
      pendingComment: value,
      isCommentSubmitDisabled: isEmpty(value.trim())
    });
  }

  async handleCommentSubmit(event) {
    const feedItemId = event.currentTarget.dataset.feedItemId;
    if (!feedItemId || !this.canComment) return;

    const draft = (this.commentDraftByFeedItemId[feedItemId] || "").trim();
    if (isEmpty(draft)) return;

    this.markFeedItemState(feedItemId, { isCommentSaving: true });

    try {
      const createdComment = await createFeedComment({
        feedItemId,
        commentBody: draft,
        mode: this.componentMode
      });

      this.commentDraftByFeedItemId = {
        ...this.commentDraftByFeedItemId,
        [feedItemId]: ""
      };

      this.feedItems = this.feedItems.map((feedItem) => {
        if (feedItem.id !== feedItemId) return feedItem;

        const decoratedComment = this.decorateFeedComment(createdComment);
        const updatedComments = [...feedItem.comments, decoratedComment];

        return {
          ...feedItem,
          comments: updatedComments,
          hasComments: true,
          commentSummary: this.buildCommentSummary(updatedComments.length),
          pendingComment: "",
          isCommentSubmitDisabled: true,
          isCommentSaving: false
        };
      });
    } catch (error) {
      showToast(this, "Unable to comment", normalizeError(error), "error");
      this.markFeedItemState(feedItemId, { isCommentSaving: false });
    }
  }

  handleSortToggle() {
    this.sortOrder = this.sortOrder === "DESC" ? "ASC" : "DESC";
  }

  handleSearchInput(event) {
    this.searchTerm = (event.target.value || "").trim().toLowerCase();
  }

  async handleRefreshFeed() {
    await this.loadFeedData();
  }

  markFeedItemState(feedItemId, stateUpdates) {
    this.feedItems = this.feedItems.map((feedItem) => {
      if (feedItem.id !== feedItemId) return feedItem;
      return { ...feedItem, ...stateUpdates };
    });
  }

  resolvePublisherBody() {
    if (this.isPollMode) {
      return this.pollQuestion.trim();
    }

    if (this.isQuestionMode) {
      return this.questionBody.trim();
    }

    return this.postBody;
  }

  resolvePublishSuccessMessage() {
    if (this.isPollMode) {
      return "Poll posted successfully.";
    }

    if (this.isQuestionMode) {
      return "Question posted successfully.";
    }

    return "Post shared successfully.";
  }

  resetPublisher() {
    this.postBody = "";
    this.pollQuestion = "";
    this.questionBody = "";
    this.selectedGoogleFiles = [];
    this.pollChoiceCounter = 2;
    this.pollChoices = [
      { id: "poll-choice-1", value: "" },
      { id: "poll-choice-2", value: "" }
    ];
    this.isPublisherExpanded = false;
    this.activePublisherType =
      this.enabledPublisherTypes[0] || PUBLISHER_TYPE.POST;
  }

  ensureActivePublisherType() {
    const enabledTypes = this.enabledPublisherTypes;
    if (enabledTypes.length <= 0) {
      this.activePublisherType = PUBLISHER_TYPE.POST;
      return;
    }

    if (!enabledTypes.includes(this.activePublisherType)) {
      this.activePublisherType = enabledTypes[0];
    }
  }

  buildCommentSummary(commentCount) {
    if (commentCount <= 0) {
      return "No comments";
    }

    return `${commentCount} ${commentCount === 1 ? "comment" : "comments"}`;
  }

  resolveInitials(nameValue) {
    if (isEmpty((nameValue || "").trim())) return "U";

    const tokens = nameValue.trim().split(/\s+/).filter(Boolean);

    if (tokens.length === 1) {
      return tokens[0].substring(0, 1).toUpperCase();
    }

    return `${tokens[0].substring(0, 1)}${tokens[tokens.length - 1].substring(0, 1)}`.toUpperCase();
  }

  formatRelativeDate(dateValue) {
    const date = new Date(dateValue);
    if (Number.isNaN(date.getTime())) {
      return "Unknown time";
    }

    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffMinutes = Math.floor(diffMs / (1000 * 60));

    if (diffMinutes < 1) return "just now";
    if (diffMinutes < 60)
      return `${diffMinutes} ${diffMinutes === 1 ? "minute" : "minutes"} ago`;

    const diffHours = Math.floor(diffMinutes / 60);
    if (diffHours < 24)
      return `${diffHours} ${diffHours === 1 ? "hour" : "hours"} ago`;

    const diffDays = Math.floor(diffHours / 24);
    if (diffDays < 7)
      return `${diffDays} ${diffDays === 1 ? "day" : "days"} ago`;

    return date.toLocaleString();
  }

  stripHtml(rawValue) {
    return (rawValue || "")
      .replace(/<[^>]*>/g, " ")
      .replace(/&nbsp;/g, " ")
      .replace(/\s+/g, " ")
      .trim();
  }

  doesFeedItemMatchSearch(feedItem, normalizedSearchTerm) {
    const feedText = [
      feedItem.authorName,
      feedItem.title,
      feedItem.bodyText,
      feedItem.commentSummary
    ]
      .join(" ")
      .toLowerCase();

    if (feedText.includes(normalizedSearchTerm)) {
      return true;
    }

    const hasMatchingComment = feedItem.comments.some((comment) => {
      const commentText =
        `${comment.authorName} ${comment.commentBody}`.toLowerCase();
      return commentText.includes(normalizedSearchTerm);
    });

    if (hasMatchingComment) {
      return true;
    }

    return feedItem.googleFiles.some((fileRecord) => {
      const fileText =
        `${fileRecord.fileName} ${fileRecord.info}`.toLowerCase();
      return fileText.includes(normalizedSearchTerm);
    });
  }

  parsePublisherTypeConfig(rawValue) {
    const normalizedValue = (rawValue || "").trim().toUpperCase();
    if (isEmpty(normalizedValue)) {
      return [...DEFAULT_ALLOWED_PUBLISHER_TYPES];
    }

    if (normalizedValue === "POST_ONLY") {
      return [PUBLISHER_TYPE.POST];
    }

    if (normalizedValue === "POST_POLL") {
      return [PUBLISHER_TYPE.POST, PUBLISHER_TYPE.POLL];
    }

    if (normalizedValue === "POST_POLL_QUESTION") {
      return [...DEFAULT_ALLOWED_PUBLISHER_TYPES];
    }

    const output = [];
    const preparedValue = normalizedValue
      .replace(/;/g, ",")
      .replace(/\|/g, ",");

    preparedValue.split(",").forEach((value) => {
      const token = (value || "").trim().toUpperCase();
      if (isEmpty(token)) {
        return;
      }

      if (
        token === PUBLISHER_TYPE.POST &&
        !output.includes(PUBLISHER_TYPE.POST)
      ) {
        output.push(PUBLISHER_TYPE.POST);
      }

      if (
        token === PUBLISHER_TYPE.POLL &&
        !output.includes(PUBLISHER_TYPE.POLL)
      ) {
        output.push(PUBLISHER_TYPE.POLL);
      }

      if (
        token === PUBLISHER_TYPE.QUESTION &&
        !output.includes(PUBLISHER_TYPE.QUESTION)
      ) {
        output.push(PUBLISHER_TYPE.QUESTION);
      }
    });

    if (!output.includes(PUBLISHER_TYPE.POST)) {
      output.unshift(PUBLISHER_TYPE.POST);
    }

    return output;
  }

  resolveMode(rawValue) {
    const normalized = (rawValue || "").trim().toUpperCase();
    if (normalized === MODE.READ_ONLY || normalized === "READONLY") {
      return MODE.READ_ONLY;
    }

    return MODE.READ_WRITE;
  }

  get componentMode() {
    const normalizedReadOnly =
      this.readOnly === true ||
      (typeof this.readOnly === "string" &&
        this.readOnly.trim().toLowerCase() === "true");

    if (normalizedReadOnly) {
      return MODE.READ_ONLY;
    }

    return this.resolveMode(this.mode);
  }

  get validPollChoices() {
    return this.pollChoices
      .map((choice) => (choice.value || "").trim())
      .filter((value) => !isEmpty(value));
  }

  get hasRecordContext() {
    return !isEmpty(this.effectiveParentRecordId);
  }

  get effectiveParentRecordId() {
    return (
      this._recordId ||
      this.resolvedParentRecordId ||
      this.inferRecordIdFromLocation()
    );
  }

  inferRecordIdFromLocation() {
    if (typeof window === "undefined" || !window.location) {
      return null;
    }

    const candidates = [];

    try {
      const params = new URLSearchParams(window.location.search || "");
      ["recordId", "id", "c__recordId", "c__id"].forEach((paramName) => {
        const value = params.get(paramName);
        if (!isEmpty(value)) {
          candidates.push(value);
        }
      });
    } catch {
      // Intentionally ignored.
    }

    const pathParts = (window.location.pathname || "")
      .split("/")
      .filter(Boolean);
    candidates.push(...pathParts);

    const foundRecordId = candidates.find((candidate) =>
      this.isSalesforceId(candidate)
    );
    return foundRecordId || null;
  }

  isSalesforceId(value) {
    const normalizedValue = (value || "").trim();
    return /^[a-zA-Z0-9]{15}(?:[a-zA-Z0-9]{3})?$/.test(normalizedValue);
  }

  get configuredPublisherTypes() {
    return this.parsePublisherTypeConfig(this.publisherTabs);
  }

  get serverAllowedPublisherTypes() {
    const serverValues = Array.isArray(this.capabilities.allowedPublisherTypes)
      ? this.capabilities.allowedPublisherTypes
      : [];

    const normalizedServerValues = serverValues
      .map((value) => (value || "").trim().toUpperCase())
      .filter((value) => !isEmpty(value));

    return normalizedServerValues.length > 0
      ? normalizedServerValues
      : [...DEFAULT_ALLOWED_PUBLISHER_TYPES];
  }

  get enabledPublisherTypes() {
    const serverSet = new Set(this.serverAllowedPublisherTypes);
    const enabled = this.configuredPublisherTypes.filter((typeName) =>
      serverSet.has(typeName)
    );

    if (
      !enabled.includes(PUBLISHER_TYPE.POST) &&
      serverSet.has(PUBLISHER_TYPE.POST)
    ) {
      enabled.unshift(PUBLISHER_TYPE.POST);
    }

    return enabled;
  }

  get hasPublisherTabs() {
    return this.enabledPublisherTypes.length > 0;
  }

  get isReadOnlyMode() {
    return (
      this.capabilities.isReadOnlyMode === true ||
      this.componentMode === MODE.READ_ONLY
    );
  }

  get canShowPublisher() {
    return (
      !this.isReadOnlyMode &&
      this.capabilities.canCreatePosts === true &&
      this.hasPublisherTabs
    );
  }

  get canComment() {
    return !this.isReadOnlyMode && this.capabilities.canCreateComments === true;
  }

  get hasSelectedFiles() {
    return this.selectedGoogleFiles.length > 0;
  }

  get attachmentLimitReached() {
    return this.selectedGoogleFiles.length >= MAX_FILES_PER_PUBLISH;
  }

  get canAttachGoogleFiles() {
    return (
      !this.isReadOnlyMode && this.capabilities.canAttachGoogleFiles === true
    );
  }

  get isAttachActionDisabled() {
    return (
      this.isPublishing ||
      !this.canAttachGoogleFiles ||
      this.attachmentLimitReached
    );
  }

  get attachmentActionLabel() {
    return this.isExperienceSite ? "Upload Google file" : "Attach Google file";
  }

  get attachmentIconName() {
    return this.isExperienceSite ? "utility:upload" : "utility:attach";
  }

  get attachmentToolbarLabel() {
    return this.isExperienceSite
      ? "Upload Google Drive file"
      : "Attach Google Drive file";
  }

  get hasAudienceOptions() {
    return this.audienceOptions.length > 0;
  }

  get isPostMode() {
    return this.activePublisherType === PUBLISHER_TYPE.POST;
  }

  get isPollMode() {
    return this.activePublisherType === PUBLISHER_TYPE.POLL;
  }

  get isQuestionMode() {
    return this.activePublisherType === PUBLISHER_TYPE.QUESTION;
  }

  get showPostTab() {
    return this.enabledPublisherTypes.includes(PUBLISHER_TYPE.POST);
  }

  get showPollTab() {
    return this.enabledPublisherTypes.includes(PUBLISHER_TYPE.POLL);
  }

  get showQuestionTab() {
    return this.enabledPublisherTypes.includes(PUBLISHER_TYPE.QUESTION);
  }

  get postTabClass() {
    return `slds-tabs_scoped__item${this.isPostMode ? " slds-is-active" : ""}`;
  }

  get pollTabClass() {
    return `slds-tabs_scoped__item${this.isPollMode ? " slds-is-active" : ""}`;
  }

  get questionTabClass() {
    return `slds-tabs_scoped__item${this.isQuestionMode ? " slds-is-active" : ""}`;
  }

  get sortIconName() {
    return "utility:sort";
  }

  get sortLabel() {
    return this.sortOrder === "DESC" ? "Newest First" : "Oldest First";
  }

  get publisherPlaceholder() {
    if (this.isPollMode) {
      return "Ask a poll question...";
    }

    if (this.isQuestionMode) {
      return "Ask a question...";
    }

    return "Share an update...";
  }

  get publishButtonLabel() {
    if (this.isPollMode || this.isQuestionMode) {
      return "Ask";
    }

    return "Share";
  }

  get isPublishDisabled() {
    if (
      this.isPublishing ||
      !this.canShowPublisher ||
      !this.isPublisherExpanded
    ) {
      return true;
    }

    if (this.isPostMode) {
      return isEmpty(this.stripHtml(this.postBody));
    }

    if (this.isPollMode) {
      return (
        isEmpty(this.pollQuestion.trim()) ||
        this.validPollChoices.length < MIN_POLL_CHOICES
      );
    }

    return isEmpty(this.questionBody.trim());
  }

  get filteredFeedItems() {
    let items = isEmpty(this.searchTerm)
      ? this.feedItems
      : this.feedItems.filter((feedItem) =>
          this.doesFeedItemMatchSearch(feedItem, this.searchTerm)
        );

    return this.sortOrder === "ASC" ? [...items].reverse() : items;
  }

  get hasFeedItems() {
    return this.filteredFeedItems.length > 0;
  }

  get showFeedEmptyState() {
    return (
      !this.isLoading &&
      this.hasRecordContext &&
      this.filteredFeedItems.length === 0 &&
      isEmpty(this.errorMessage)
    );
  }

  get audienceLabel() {
    if (!this.hasAudienceOptions) {
      return "All with access";
    }

    const selectedOption = this.audienceOptions.find(
      (option) => option.value === this.selectedAudienceValue
    );
    return (
      selectedOption?.label ||
      this.audienceOptions[0]?.label ||
      "All with access"
    );
  }
}
