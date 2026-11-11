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
@IsTest
private class GoogleTransientFailureResolverTest {
	private static final String TIMEOUT = 'timeout';
	private static final String BUSY = 'busy';
	private static final String VERTEX_RESOURCE_EXHAUSTED_BODY = '{"error":{"code":429,"message":"Resource exhausted. Please try again later. Please refer to https://cloud.google.com/vertex-ai/generative-ai/docs/error-code-429 for more details.","status":"RESOURCE_EXHAUSTED"}}';
	private static final String GEMINI_UNAVAILABLE_BODY = '{"error":{"code":503,"message":"The model is overloaded. Please try again later.","status":"UNAVAILABLE"}}';
	private static final String GEMINI_INTERNAL_BODY = '{"error":{"code":500,"message":"An internal error has occurred. Please retry or report in https://developers.generativeai.google/guide/troubleshooting","status":"INTERNAL"}}';
	private static final String VERTEX_DEADLINE_EXCEEDED_BODY = '{"error":{"code":504,"message":"Deadline expired before operation could complete.","status":"DEADLINE_EXCEEDED"}}';
	private static final String GEMINI_INVALID_KEY_BODY = '{"error":{"code":400,"message":"API key not valid. Please pass a valid API key.","status":"INVALID_ARGUMENT","details":[{"@type":"type.googleapis.com/google.rpc.ErrorInfo","reason":"API_KEY_INVALID","domain":"googleapis.com"}]}}';
	private static final String TOKEN_LIMIT_BODY_WITH_SERVER_DIGITS = '{"error":{"code":400,"message":"The input token count (1503002) exceeds the maximum number of tokens allowed (1048576).","status":"INVALID_ARGUMENT"}}';
	private static final String VERTEX_PERMISSION_DENIED_BODY = '{"error":{"code":403,"message":"Permission \'aiplatform.endpoints.predict\' denied on resource \'//aiplatform.googleapis.com/projects/project-1/locations/global/publishers/google/models/gemini-3.8-flash\' (or it may not exist).","status":"PERMISSION_DENIED"}}';
	private static final String VERTEX_MODEL_NOT_FOUND_BODY = '{"error":{"code":404,"message":"Publisher Model projects/project-1/locations/global/publishers/google/models/gemini-9-flash was not found or your project does not have access to it.","status":"NOT_FOUND"}}';
	private static final String GATEWAY_ERROR_PAGE = '<!DOCTYPE html>\n<html lang=en>\n  <meta charset=utf-8>\n  <title>Error 502 (Server Error)!!1</title>\n  <p><b>502.</b> <ins>That is an error.</ins>';
	private static final String DRIVE_USER_RATE_LIMIT_BODY = '{\n  "error": {\n    "code": 403,\n    "message": "User rate limit exceeded.",\n    "errors": [\n      {\n        "message": "User rate limit exceeded.",\n        "domain": "usageLimits",\n        "reason": "userRateLimitExceeded"\n      }\n    ]\n  }\n}';
	private static final String DRIVE_RATE_LIMIT_BODY = '{"error":{"code":429,"message":"Rate Limit Exceeded","errors":[{"message":"Rate Limit Exceeded","domain":"usageLimits","reason":"rateLimitExceeded"}]}}';
	private static final String DRIVE_FORBIDDEN_RATE_LIMIT_BODY = '{"error":{"code":403,"message":"Rate Limit Exceeded","errors":[{"message":"Rate Limit Exceeded","domain":"usageLimits","reason":"rateLimitExceeded"}]}}';
	private static final String DRIVE_BACKEND_ERROR_BODY = '{"error":{"code":500,"message":"Internal Error","errors":[{"message":"Internal Error","domain":"global","reason":"backendError"}]}}';
	private static final String DRIVE_UNAVAILABLE_BODY = '{"error":{"code":503,"message":"Service Unavailable","errors":[{"message":"Service Unavailable","domain":"global","reason":"backendError"}]}}';
	private static final String DRIVE_UNAVAILABLE_PAGE = '<!DOCTYPE html>\n<html lang=en>\n  <meta charset=utf-8>\n  <title>Error 503 (Service Unavailable)!!1</title>\n  <p><b>503.</b> <ins>That is an error.</ins>';
	private static final String DRIVE_NOT_FOUND_WITH_SERVER_DIGITS_BODY = '{\n  "error": {\n    "code": 404,\n    "message": "File not found: 1x5035029AbC503dEfGhI429jKlMnOpQrS.",\n    "errors": [\n      {\n        "message": "File not found: 1x5035029AbC503dEfGhI429jKlMnOpQrS.",\n        "domain": "global",\n        "reason": "notFound",\n        "location": "fileId",\n        "locationType": "parameter"\n      }\n    ]\n  }\n}';
	private static final String DRIVE_CONVERSION_REFUSED_BODY = '{\n  "error": {\n    "code": 400,\n    "message": "The requested conversion is not supported.",\n    "errors": [\n      {\n        "message": "The requested conversion is not supported.",\n        "domain": "global",\n        "reason": "badRequest",\n        "location": "convertTo",\n        "locationType": "parameter"\n      }\n    ]\n  }\n}';
	private static final String DRIVE_EXPIRATION_REFUSED_BODY = '{\n  "error": {\n    "code": 403,\n    "message": "Expiration dates cannot be set on this item.",\n    "errors": [\n      {\n        "message": "Expiration dates cannot be set on this item.",\n        "domain": "global",\n        "reason": "cannotSetExpiration"\n      }\n    ]\n  }\n}';
	private static final String DRIVE_BAD_REQUEST_PAGE = '<!DOCTYPE html>\n<html lang=en>\n  <meta charset=utf-8>\n  <meta name=viewport content="initial-scale=1, minimum-scale=1, width=device-width">\n  <title>Error 400 (Bad Request)!!1</title>\n  <style>\n    *{margin:0;padding:0}html,code{font:15px/22px arial,sans-serif}html{background:#fff;color:#222;padding:15px}body{margin:7% auto 0;max-width:390px;min-height:180px;padding:30px 0 15px}* > body{background:url(//www.google.com/images/errors/robot.png) 100% 5px no-repeat;padding-right:205px}p{margin:11px 0 22px;overflow:hidden}ins{color:#777;text-decoration:none}a img{border:0}@media screen and (max-width:772px){body{background:none;margin-top:0;max-width:none;padding-right:0}}\n  </style>';

	private static Boolean isRetryable(Exception failure) {
		return new GoogleTransientFailureResolver().isRetryable(failure);
	}

	private static String describeFailure(Exception failure) {
		return new GoogleTransientFailureResolver().describeFailure(failure);
	}

	@IsTest
	private static void testIsRetryablePositiveReadTimeout() {
		Assert.isTrue(isRetryable(new CalloutException('Read timed out')), 'A call the AI service did not answer in time is worth another attempt');
	}

	@IsTest
	private static void testIsRetryablePositiveConnectTimeout() {
		Assert.isTrue(isRetryable(new CalloutException('connect timed out')));
	}

	@IsTest
	private static void testIsRetryablePositiveCalloutTimeExhausted() {
		Assert.isTrue(isRetryable(new CalloutException('Exceeded maximum time allotted for callout (120000 ms)')), 'Running out of the transaction\'s callout time is solved by a later transaction');
	}

	@IsTest
	private static void testIsRetryablePositiveDroppedConnection() {
		Assert.isTrue(isRetryable(new CalloutException('Connection reset')));
		Assert.isTrue(isRetryable(new CalloutException('Unexpected end of file from server')));
	}

	@IsTest
	private static void testIsRetryableNegativeUnauthorizedEndpoint() {
		Assert.isFalse(isRetryable(new CalloutException('Unauthorized endpoint, please check Setup->Security->Remote site settings. endpoint = https://aiplatform.googleapis.com/v1/projects/project-1/locations/global/publishers/google/models/gemini-3.8-flash:generateContent')), 'A missing remote site fails the same way every time');
	}

	@IsTest
	private static void testIsRetryableNegativeUncommittedWorkPending() {
		Assert.isFalse(isRetryable(new CalloutException('You have uncommitted work pending. Please commit or rollback before calling out')), 'A callout made after unsaved changes fails the same way on every attempt');
	}

	@IsTest
	private static void testIsRetryablePositiveResourceExhausted() {
		Assert.isTrue(isRetryable(new GenAiProviderException(VERTEX_RESOURCE_EXHAUSTED_BODY)), 'A busy answer from Agent Platform is worth another attempt');
	}

	@IsTest
	private static void testIsRetryablePositiveUnavailableInternalAndDeadlineExceeded() {
		Assert.isTrue(isRetryable(new GenAiProviderException(GEMINI_UNAVAILABLE_BODY)));
		Assert.isTrue(isRetryable(new GenAiProviderException(GEMINI_INTERNAL_BODY)));
		Assert.isTrue(isRetryable(new GenAiProviderException(VERTEX_DEADLINE_EXCEEDED_BODY)));
	}

	@IsTest
	private static void testIsRetryablePositiveBlankProviderBody() {
		Assert.isTrue(isRetryable(new GenAiProviderException('')), 'A refused answer that carries no body at all comes from a gateway and counts as busy');
	}

	@IsTest
	private static void testIsRetryablePositiveGatewayErrorPage() {
		Assert.isTrue(isRetryable(new GenAiProviderException(GATEWAY_ERROR_PAGE)), 'Google\'s own 502 page is read by the code in its title');
	}

	@IsTest
	private static void testIsRetryableNegativeConfigurationErrors() {
		Assert.isFalse(isRetryable(new GenAiProviderException(GEMINI_INVALID_KEY_BODY)), 'A wrong API key fails the same way every time');
		Assert.isFalse(isRetryable(new GenAiProviderException(VERTEX_PERMISSION_DENIED_BODY)), 'A missing permission fails the same way every time');
		Assert.isFalse(isRetryable(new GenAiProviderException(VERTEX_MODEL_NOT_FOUND_BODY)), 'A model that does not exist fails the same way every time');
	}

	@IsTest
	private static void testIsRetryableNegativeClientErrorWhoseMessageCarriesServerDigits() {
		Assert.isFalse(isRetryable(new GenAiProviderException(TOKEN_LIMIT_BODY_WITH_SERVER_DIGITS)), 'Digits inside the message must not be read as the status code');
	}

	@IsTest
	private static void testIsRetryablePositiveDriveRateLimits() {
		Assert.isTrue(isRetryable(new GoogleCloudException(DRIVE_USER_RATE_LIMIT_BODY)), 'Drive answers 403 userRateLimitExceeded under a burst, as it did on 2026-11-09');
		Assert.isTrue(isRetryable(new GoogleCloudException(DRIVE_RATE_LIMIT_BODY)));
		Assert.isTrue(isRetryable(new GoogleCloudException(DRIVE_FORBIDDEN_RATE_LIMIT_BODY)));
	}

	@IsTest
	private static void testIsRetryablePositiveDriveServerErrors() {
		Assert.isTrue(isRetryable(new GoogleCloudException(DRIVE_BACKEND_ERROR_BODY)));
		Assert.isTrue(isRetryable(new GoogleCloudException(DRIVE_UNAVAILABLE_BODY)));
		Assert.isTrue(isRetryable(new GoogleCloudException(DRIVE_UNAVAILABLE_PAGE)));
	}

	@IsTest
	private static void testIsRetryableNegativeDriveNotFoundWhoseIdCarriesServerDigits() {
		Assert.isFalse(isRetryable(new GoogleCloudException(DRIVE_NOT_FOUND_WITH_SERVER_DIGITS_BODY)), 'A file Id that happens to contain 503 or 429 must not turn a missing file into a busy service');
	}

	@IsTest
	private static void testIsRetryableNegativeDriveRefusals() {
		Assert.isFalse(isRetryable(new GoogleCloudException(DRIVE_CONVERSION_REFUSED_BODY)), 'A conversion Drive does not support is refused on every attempt');
		Assert.isFalse(isRetryable(new GoogleCloudException(DRIVE_EXPIRATION_REFUSED_BODY)));
		Assert.isFalse(isRetryable(new GoogleCloudException(DRIVE_BAD_REQUEST_PAGE)), 'Numbers in the page styling must not be read as the status code');
	}

	@IsTest
	private static void testIsRetryableNegativeNullAndUnrelatedFailures() {
		Assert.isFalse(isRetryable(null));
		Assert.isFalse(isRetryable(new GenAiConfigurationException('Google model is required.')));
		Assert.isFalse(isRetryable(new DmlException('UNABLE_TO_LOCK_ROW')));
		Assert.isFalse(isRetryable(new IllegalArgumentException('Read timed out')), 'Only a callout that timed out counts, not any exception quoting the words');
	}

	@IsTest
	private static void testIsRetryableOutcomePositiveEmptyMaxTokensAnswer() {
		Assert.isTrue(new GoogleTransientFailureResolver().isRetryableOutcome('MAX_TOKENS', false), 'An answer that ran out of room before writing anything is worth another attempt');
	}

	@IsTest
	private static void testIsRetryableOutcomeNegativeAnswersWithTextOrOtherReasons() {
		GoogleTransientFailureResolver resolver = new GoogleTransientFailureResolver();

		Assert.isFalse(resolver.isRetryableOutcome('MAX_TOKENS', true), 'An answer cut short keeps the text it has');
		Assert.isFalse(resolver.isRetryableOutcome('STOP', false));
		Assert.isFalse(resolver.isRetryableOutcome('SAFETY', false));
		Assert.isFalse(resolver.isRetryableOutcome(null, false));
	}

	@IsTest
	private static void testHasAttemptsLeftPositiveBeforeTheThirdAttempt() {
		GoogleTransientFailureResolver resolver = new GoogleTransientFailureResolver();

		Assert.isTrue(resolver.hasAttemptsLeft(1));
		Assert.isTrue(resolver.hasAttemptsLeft(2));
	}

	@IsTest
	private static void testHasAttemptsLeftNegativeFromTheThirdAttempt() {
		GoogleTransientFailureResolver resolver = new GoogleTransientFailureResolver();

		Assert.areEqual(3, GoogleTransientFailureResolver.MAX_ATTEMPTS);
		Assert.isFalse(resolver.hasAttemptsLeft(3), 'Three attempts in all: the first and two retries');
		Assert.isFalse(resolver.hasAttemptsLeft(4));
	}

	@IsTest
	private static void testResolveRetryDelayMinutesPositiveOneThenThreeMinutes() {
		GoogleTransientFailureResolver.retrySpreadOverride = 0;
		GoogleTransientFailureResolver resolver = new GoogleTransientFailureResolver();

		Assert.areEqual(1, resolver.resolveRetryDelayMinutes(2));
		Assert.areEqual(3, resolver.resolveRetryDelayMinutes(3));
	}

	@IsTest
	private static void testResolveRetryDelayMinutesPositiveSpreadAddsOneMinute() {
		GoogleTransientFailureResolver.retrySpreadOverride = 1;
		GoogleTransientFailureResolver resolver = new GoogleTransientFailureResolver();

		Assert.areEqual(2, resolver.resolveRetryDelayMinutes(2));
		Assert.areEqual(4, resolver.resolveRetryDelayMinutes(3));
	}

	@IsTest
	private static void testResolveRetryDelayMinutesPositiveSpreadStaysWithinOneMinute() {
		GoogleTransientFailureResolver resolver = new GoogleTransientFailureResolver();

		for (Integer draw = 0; draw < 40; draw++) {
			Integer firstRetryDelay = resolver.resolveRetryDelayMinutes(2);
			Integer secondRetryDelay = resolver.resolveRetryDelayMinutes(3);
			Assert.isTrue(firstRetryDelay == 1 || firstRetryDelay == 2, 'The first retry waits one minute plus up to one more, never ' + firstRetryDelay);
			Assert.isTrue(secondRetryDelay == 3 || secondRetryDelay == 4, 'The second retry waits three minutes plus up to one more, never ' + secondRetryDelay);
		}
	}

	@IsTest
	private static void testResolveRetryDelayMinutesPositiveOutOfRangeAttempts() {
		GoogleTransientFailureResolver.retrySpreadOverride = 0;
		GoogleTransientFailureResolver resolver = new GoogleTransientFailureResolver();

		Assert.areEqual(1, resolver.resolveRetryDelayMinutes(0));
		Assert.areEqual(1, resolver.resolveRetryDelayMinutes(1));
		Assert.areEqual(3, resolver.resolveRetryDelayMinutes(4));
		Assert.areEqual(3, resolver.resolveRetryDelayMinutes(10), 'A delay stays within the ten minutes a queued job may wait');
	}

	@IsTest
	private static void testDescribeFailurePositiveTimeout() {
		Assert.areEqual(TIMEOUT, describeFailure(new CalloutException('Read timed out')));
		Assert.areEqual(TIMEOUT, describeFailure(new CalloutException('Exceeded maximum time allotted for callout (120000 ms)')));
	}

	@IsTest
	private static void testDescribeFailurePositiveBusy() {
		Assert.areEqual(BUSY, describeFailure(new GenAiProviderException(VERTEX_RESOURCE_EXHAUSTED_BODY)));
		Assert.areEqual(BUSY, describeFailure(new GenAiProviderException(GEMINI_UNAVAILABLE_BODY)));
		Assert.areEqual(BUSY, describeFailure(new GenAiProviderException('')));
	}

	@IsTest
	private static void testDescribeFailureNegativeOtherFailures() {
		Assert.isNull(describeFailure(new GenAiProviderException(GEMINI_INVALID_KEY_BODY)));
		Assert.isNull(describeFailure(new CalloutException('Unauthorized endpoint, please check Setup->Security->Remote site settings.')));
		Assert.isNull(describeFailure(null));
	}
}
