import { LightningElement, api, track } from 'lwc';

import retrieveFileIntelligenceState from '@salesforce/apex/GoogleCloudFileIntelligenceController.retrieveFileIntelligenceState';
import answerFileQuestion from '@salesforce/apex/GoogleCloudFileIntelligenceController.answerFileQuestion';
import {
	DEFAULT_FILE_INTELLIGENCE_SUMMARY_UNAVAILABLE_MESSAGE,
	createDefaultFileIntelligenceState,
	normalizeFileIntelligenceState,
	resolveFileIntelligencePanelOpen
} from 'c/googleCloudFileIntelligenceUtils';

const MAX_QUESTION_CHARACTERS = 255;
const DEFAULT_FILE_INTELLIGENCE_QUESTION_ERROR_MESSAGE = 'We could not answer that question. Try again in a moment.';
const PARTIAL_RESPONSE_NOTE = 'Response may be incomplete.';

export default class GoogleCloudFileIntelligence extends LightningElement {
	@track intelligenceState = createDefaultFileIntelligenceState();
	@track isLoading = false;
	@track isOpen = false;
	@track messages = [];
	@track draftQuestion = '';
	@track questionError = '';
	@track isQuestionLoading = false;

	requestSequence = 0;
	questionRequestSequence = 0;
	userOpenPreference = null;
	versionIdValue;
	messageSequence = 0;
	shouldScrollConversation = false;
	questionCharacterLimit = MAX_QUESTION_CHARACTERS;

	renderedCallback() {
		if (this.shouldScrollConversation !== true) {
			return;
		}

		const conversation = this.template.querySelector('.intelligence-conversation');
		if (conversation) {
			conversation.scrollTop = conversation.scrollHeight;
		}

		this.shouldScrollConversation = false;
	}

	@api
	get versionId() {
		return this.versionIdValue;
	}

	set versionId(value) {
		const normalizedVersionId = value || undefined;
		if (this.versionIdValue === normalizedVersionId) {
			return;
		}

		this.versionIdValue = normalizedVersionId;
		this.userOpenPreference = null;
		this.requestSequence += 1;
		this.questionRequestSequence += 1;
		this.intelligenceState = createDefaultFileIntelligenceState(normalizedVersionId);
		this.isLoading = false;
		this.isOpen = false;
		this.resetConversationState();

		if (!normalizedVersionId) {
			this.emitStateChange();
			return;
		}

		void this.loadIntelligenceState(normalizedVersionId);
	}

	@api
	async refresh() {
		if (!this.versionIdValue) {
			return;
		}

		this.questionError = '';
		await this.loadIntelligenceState(this.versionIdValue);
	}

	handleOpen() {
		this.userOpenPreference = true;
		this.isOpen = true;
		this.dispatchEvent(new CustomEvent('panelopen'));
		this.emitStateChange();
	}

	handleClose() {
		this.userOpenPreference = false;
		this.isOpen = false;
		this.dispatchEvent(new CustomEvent('panelclose'));
		this.emitStateChange();
	}

	handleQuestionInput(event) {
		this.draftQuestion = event.target?.value || '';
		this.questionError = '';
	}

	handleQuestionKeyDown(event) {
		if (event.key !== 'Enter') {
			return;
		}

		event.preventDefault();
		void this.handleQuestionSend();
	}

	async handleQuestionSend() {
		const question = this.normalizedQuestion;
		if (!question || this.isQuestionLoading || !this.versionIdValue) {
			return;
		}

		if (question.length > MAX_QUESTION_CHARACTERS) {
			this.questionError = 'Questions must be 255 characters or fewer.';
			return;
		}

		const pendingMessage = this.createPendingAssistantMessage();
		const currentVersionId = this.versionIdValue;
		const currentQuestionRequestSequence = ++this.questionRequestSequence;

		this.messages = [
			...this.messages,
			this.createUserMessage(question),
			pendingMessage
		];
		this.shouldScrollConversation = true;
		this.draftQuestion = '';
		this.questionError = '';
		this.isQuestionLoading = true;

		try {
			const result = await answerFileQuestion({
				localFileVersionId: currentVersionId,
				question
			});

			if (currentQuestionRequestSequence !== this.questionRequestSequence || currentVersionId !== this.versionIdValue) {
				return;
			}

			if (result?.success === true && result?.text) {
				this.replaceMessage(
					pendingMessage.id,
					this.createAssistantMessage(result.text, result?.finishReason, pendingMessage.id)
				);
				return;
			}

			this.replaceMessage(
				pendingMessage.id,
				this.createAssistantErrorMessage(result?.errorMessage || DEFAULT_FILE_INTELLIGENCE_QUESTION_ERROR_MESSAGE, pendingMessage.id)
			);
		} catch (error) {
			if (currentQuestionRequestSequence !== this.questionRequestSequence || currentVersionId !== this.versionIdValue) {
				return;
			}

			this.replaceMessage(
				pendingMessage.id,
				this.createAssistantErrorMessage(this.normalizeQuestionError(error), pendingMessage.id)
			);
		} finally {
			if (currentQuestionRequestSequence === this.questionRequestSequence && currentVersionId === this.versionIdValue) {
				this.isQuestionLoading = false;
			}
		}
	}

	async loadIntelligenceState(versionId) {
		const currentRequestSequence = ++this.requestSequence;
		this.isLoading = true;
		this.emitStateChange();

		try {
			const intelligenceState = await retrieveFileIntelligenceState({
				localFileVersionId: versionId
			});

			if (currentRequestSequence !== this.requestSequence || versionId !== this.versionIdValue) {
				return;
			}

			this.intelligenceState = normalizeFileIntelligenceState(intelligenceState, versionId);
			this.isOpen = resolveFileIntelligencePanelOpen(this.intelligenceState, this.userOpenPreference);
		} catch (error) {
			if (currentRequestSequence !== this.requestSequence || versionId !== this.versionIdValue) {
				return;
			}

			this.intelligenceState = createDefaultFileIntelligenceState(versionId);
			this.isOpen = false;
		} finally {
			if (currentRequestSequence === this.requestSequence && versionId === this.versionIdValue) {
				this.isLoading = false;
				this.emitStateChange();
			}
		}
	}

	resetConversationState() {
		this.messages = [];
		this.draftQuestion = '';
		this.questionError = '';
		this.isQuestionLoading = false;
		this.shouldScrollConversation = false;
	}

	nextMessageId() {
		this.messageSequence += 1;
		return `message-${this.messageSequence}`;
	}

	createUserMessage(text) {
		return this.buildMessage({
			id: this.nextMessageId(),
			role: 'user',
			text
		});
	}

	createPendingAssistantMessage() {
		return this.buildMessage({
			id: this.nextMessageId(),
			role: 'assistant',
			text: '',
			isPending: true
		});
	}

	createAssistantMessage(text, finishReason, id = this.nextMessageId()) {
		return this.buildMessage({
			id,
			role: 'assistant',
			text,
			metaText: finishReason === 'MAX_TOKENS' ? PARTIAL_RESPONSE_NOTE : ''
		});
	}

	createAssistantErrorMessage(text, id = this.nextMessageId()) {
		return this.buildMessage({
			id,
			role: 'assistant',
			text,
			isError: true
		});
	}

	buildMessage({ id, role, text, isPending = false, isError = false, metaText = '' }) {
		const isUser = role === 'user';
		const rowClass = isUser ? 'intelligence-message-row intelligence-message-row--user' : 'intelligence-message-row intelligence-message-row--assistant';
		let bubbleClass = isUser ? 'intelligence-message-bubble intelligence-message-bubble--user' : 'intelligence-message-bubble intelligence-message-bubble--assistant';

		if (isError) {
			bubbleClass += ' intelligence-message-bubble--error';
		}

		return {
			id,
			text,
			isPending,
			showMeta: Boolean(metaText),
			metaText,
			rowClass,
			bubbleClass,
			copyClass: isError
				? 'intelligence-message__copy intelligence-message__copy--error'
				: 'intelligence-message__copy'
		};
	}

	replaceMessage(messageId, nextMessage) {
		this.messages = this.messages.map((message) => (
			message.id === messageId
				? nextMessage
				: message
		));
		
		this.shouldScrollConversation = true;
	}

	normalizeQuestionError(error) {
		const bodyMessage = error?.body?.message;
		if (bodyMessage) {
			return bodyMessage;
		}

		return error?.message || DEFAULT_FILE_INTELLIGENCE_QUESTION_ERROR_MESSAGE;
	}

	emitStateChange() {
		this.dispatchEvent(new CustomEvent('statechange', {
			detail: {
				isEligible: this.intelligenceState?.isIntelligenceEligible === true,
				isLoading: this.isLoading === true,
				isOpen: this.isOpen === true
			}
		}));
	}

	get summaryCopy() {
		return this.intelligenceState?.hasSummary === true && this.intelligenceState?.summary
			? this.intelligenceState.summary
			: DEFAULT_FILE_INTELLIGENCE_SUMMARY_UNAVAILABLE_MESSAGE;
	}

	get summaryCopyClass() {
		return this.intelligenceState?.hasSummary === true
			? 'intelligence-summary-copy'
			: 'intelligence-summary-copy intelligence-summary-copy--placeholder';
	}

	get normalizedQuestion() {
		return typeof this.draftQuestion === 'string'
			? this.draftQuestion.trim()
			: '';
	}

	get questionShellClass() {
		let classes = 'intelligence-question-shell';
		if (this.normalizedQuestion) {
			classes += ' intelligence-question-shell--active';
		}
		if (this.isQuestionLoading) {
			classes += ' intelligence-question-shell--disabled';
		}
		return classes;
	}

	get showSendButton() {
		return this.normalizedQuestion.length > 0 && this.isQuestionLoading !== true;
	}

	get showComposerSpinner() {
		return this.isQuestionLoading === true;
	}

	get isQuestionInputDisabled() {
		return this.isQuestionLoading === true || !this.versionIdValue;
	}

	get questionCountCopy() {
		return `${this.draftQuestion?.length || 0}/${MAX_QUESTION_CHARACTERS}`;
	}

	get questionCountClass() {
		return (this.draftQuestion?.length || 0) >= MAX_QUESTION_CHARACTERS
			? 'intelligence-question-count intelligence-question-count--danger'
			: 'intelligence-question-count';
	}

	get showMessages() {
		return this.messages.length > 0;
	}

	get showTrigger() {
		return this.intelligenceState?.isIntelligenceEligible === true && this.isOpen !== true;
	}

	get showPanel() {
		return this.intelligenceState?.isIntelligenceEligible === true && this.isOpen === true;
	}
}