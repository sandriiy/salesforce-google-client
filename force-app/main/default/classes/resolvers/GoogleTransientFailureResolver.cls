/**
 * MIT License
 *
 * Copyright (c) 2026 Andrii Sukhetskyi
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
/**
 * Decides whether a failed call to Google, the AI service or Drive alike, passes on its own and is worth
 * another attempt later, and how long that attempt waits. A failure is read from Google's own error code,
 * status and reason, never by searching the message for digits, because a file Id or a token count can
 * carry the same numbers as a server error.
 */
public with sharing class GoogleTransientFailureResolver {
	/**
	 * The attempts a file gets in all: the first and two retries.
	 */
	public static final Integer MAX_ATTEMPTS = 3;
	/**
	 * What describeFailure() answers when the service took too long.
	 */
	public static final String TIMEOUT_FAILURE = 'timeout';
	/**
	 * What describeFailure() answers when the service could not take the request now.
	 */
	public static final String BUSY_FAILURE = 'busy';

	private static final String CALLOUT_TIME_EXHAUSTED_MESSAGE = 'Exceeded maximum time allotted for callout';
	private static final List<String> TIMED_OUT_CALLOUT_MESSAGES = new List<String>{ 'Read timed out', 'connect timed out', CALLOUT_TIME_EXHAUSTED_MESSAGE };
	private static final List<String> DROPPED_CONNECTION_MESSAGES = new List<String>{ 'Connection reset', 'Unexpected end of file from server' };
	private static final Set<Integer> PASSING_STATUS_CODES = new Set<Integer>{ 408, 429, 500, 502, 503, 504 };
	private static final Set<String> PASSING_STATUSES = new Set<String>{ 'RESOURCE_EXHAUSTED', 'UNAVAILABLE', 'INTERNAL', 'DEADLINE_EXCEEDED' };
	private static final Set<String> PASSING_DRIVE_REASONS = new Set<String>{ 'rateLimitExceeded', 'userRateLimitExceeded', 'backendError', 'internalError' };
	private static final Pattern ERROR_PAGE_TITLE_PATTERN = Pattern.compile('(?i)<title>\\s*Error\\s+(\\d{3})');
	private static final String EMPTY_ANSWER_FINISH_REASON = 'MAX_TOKENS';
	private static final Integer FIRST_RETRY_ATTEMPT = 2;
	private static final Integer FIRST_RETRY_DELAY_MINUTES = 1;
	private static final Integer LATER_RETRY_DELAY_MINUTES = 3;
	private static final Integer RETRY_SPREAD_CHOICES = 2;

	@TestVisible
	private static Integer retrySpreadOverride;

	/**
	 * Says whether a failure passes on its own: a time-out, a dropped connection, the transaction running out
	 * of callout time, or Google answering that it is busy or briefly unavailable. A configuration error, a
	 * refusal and anything that is not a call to Google are final.
	 *
	 * @param failure What the call threw.
	 * @return True when another attempt later is likely to work.
	 */
	public Boolean isRetryable(Exception failure) {
		if (failure == null) return false;

		if (failure instanceof CalloutException) {
			return isTimedOutCall(failure) || containsAny(failure.getMessage(), DROPPED_CONNECTION_MESSAGES);
		}

		if (failure instanceof GenAiProviderException) {
			String body = failure.getMessage();
			return String.isBlank(body) || isPassingGoogleError(body);
		}

		if (failure instanceof GoogleCloudException) {
			return isPassingGoogleError(failure.getMessage());
		}

		return false;
	}

	/**
	 * Says whether an answer the model did send is worth asking for again, which is only the case when it
	 * spent all its room reasoning and wrote nothing.
	 *
	 * @param finishReason Why the model stopped, such as "STOP" or "MAX_TOKENS".
	 * @param hasText Whether the answer carried any text.
	 * @return True when another attempt later is likely to bring an answer.
	 */
	public Boolean isRetryableOutcome(String finishReason, Boolean hasText) {
		return finishReason == EMPTY_ANSWER_FINISH_REASON && hasText != true;
	}

	/**
	 * Says whether the call failed because the transaction ran out of callout time, which a later
	 * transaction solves, as opposed to Google refusing it. The platform's message is looked for on the
	 * failure and on its causes, since a library may pass it on inside its own exception.
	 *
	 * @param failure What the call threw.
	 * @return True when the failure, or one of its causes, is the callout time running out.
	 */
	public Boolean isCalloutTimeExhausted(Exception failure) {
		Exception current = failure;
		while (current != null) {
			if (String.isNotBlank(current.getMessage()) && current.getMessage().contains(CALLOUT_TIME_EXHAUSTED_MESSAGE)) return true;
			current = current.getCause();
		}

		return false;
	}

	/**
	 * Says whether a file that has had this many attempts may have another.
	 *
	 * @param attempt The attempt that just failed, counting from one. Null counts as the first.
	 * @return True while fewer than MAX_ATTEMPTS were made.
	 */
	public Boolean hasAttemptsLeft(Integer attempt) {
		Integer madeAttempts = attempt == null ? 1 : attempt;
		return madeAttempts < MAX_ATTEMPTS;
	}

	/**
	 * How long an attempt waits before it starts: about one minute for the first retry and three for any
	 * later one, plus a random extra minute so a burst of failures does not come back as a burst.
	 *
	 * @param nextAttempt The attempt about to be queued, counting from one.
	 * @return The delay in whole minutes, within what a queued job may wait.
	 */
	public Integer resolveRetryDelayMinutes(Integer nextAttempt) {
		Integer baseDelay = nextAttempt == null || nextAttempt <= FIRST_RETRY_ATTEMPT
			? FIRST_RETRY_DELAY_MINUTES
			: LATER_RETRY_DELAY_MINUTES;

		return baseDelay + resolveRetrySpread();
	}

	/**
	 * Says what kind of passing failure this was, which is what a user is told: "timeout" when the service
	 * took too long, "busy" when it answered that it could not take the request now.
	 *
	 * @param failure What the call threw.
	 * @return "timeout", "busy", or null for a failure that does not pass on its own.
	 */
	public String describeFailure(Exception failure) {
		if (failure == null) return null;
		if (failure instanceof CalloutException && isTimedOutCall(failure)) return TIMEOUT_FAILURE;
		return isRetryable(failure) ? BUSY_FAILURE : null;
	}

	private Boolean isTimedOutCall(Exception failure) {
		return containsAny(failure.getMessage(), TIMED_OUT_CALLOUT_MESSAGES);
	}

	private Boolean containsAny(String message, List<String> fragments) {
		if (String.isBlank(message)) return false;

		for (String fragment : fragments) {
			if (message.containsIgnoreCase(fragment)) return true;
		}

		return false;
	}

	private Boolean isPassingGoogleError(String body) {
		if (String.isBlank(body)) return false;

		Map<String, Object> error = readErrorObject(body);
		if (error == null) {
			Integer pageStatusCode = readErrorPageStatusCode(body);
			return pageStatusCode != null && PASSING_STATUS_CODES.contains(pageStatusCode);
		}

		Integer statusCode = readInteger(error.get('code'));
		if (statusCode != null && PASSING_STATUS_CODES.contains(statusCode)) return true;

		Object status = error.get('status');
		if (status != null && PASSING_STATUSES.contains(String.valueOf(status))) return true;

		return hasPassingDriveReason(error.get('errors'));
	}

	private Map<String, Object> readErrorObject(String body) {
		Integer objectStart = body.indexOf('{');
		Integer objectEnd = body.lastIndexOf('}');
		if (objectStart < 0 || objectEnd <= objectStart) return null;

		try {
			Object parsedBody = JSON.deserializeUntyped(body.substring(objectStart, objectEnd + 1));
			if (!(parsedBody instanceof Map<String, Object>)) return null;

			Object error = ((Map<String, Object>) parsedBody).get('error');
			return error instanceof Map<String, Object> ? (Map<String, Object>) error : null;
		} catch (Exception ex) {
			return null;
		}
	}

	private Integer readErrorPageStatusCode(String body) {
		Matcher titleMatcher = ERROR_PAGE_TITLE_PATTERN.matcher(body);
		return titleMatcher.find() ? Integer.valueOf(titleMatcher.group(1)) : null;
	}

	private Integer readInteger(Object value) {
		if (value == null) return null;

		String text = String.valueOf(value);
		return text.isNumeric() ? Integer.valueOf(text) : null;
	}

	private Boolean hasPassingDriveReason(Object errors) {
		if (!(errors instanceof List<Object>)) return false;

		for (Object entry : (List<Object>) errors) {
			if (!(entry instanceof Map<String, Object>)) continue;

			Object reason = ((Map<String, Object>) entry).get('reason');
			if (reason != null && PASSING_DRIVE_REASONS.contains(String.valueOf(reason))) return true;
		}

		return false;
	}

	private Integer resolveRetrySpread() {
		if (retrySpreadOverride != null) return retrySpreadOverride;
		return Math.abs(Math.mod(Crypto.getRandomInteger(), RETRY_SPREAD_CHOICES));
	}
}
