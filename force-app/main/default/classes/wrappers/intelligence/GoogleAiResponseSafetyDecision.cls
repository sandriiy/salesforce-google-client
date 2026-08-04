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
public class GoogleAiResponseSafetyDecision {
	public static final String REASON_PROVIDER_SAFETY = 'ProviderSafety';
	public static final String REASON_SECRET_LEAK = 'SecretLeak';
	public static final String REASON_OFF_TOPIC = 'OffTopic';
	public static final String REASON_HALLUCINATED_PII = 'HallucinatedPii';
	public static final String REASON_POLICY = 'Policy';

	public Boolean allowed;
	public String reasonCode;
	public String userVisibleMessage;
	public String sanitizedText;

	public static GoogleAiResponseSafetyDecision allow() {
		GoogleAiResponseSafetyDecision decision = new GoogleAiResponseSafetyDecision();
		decision.allowed = true;
		return decision;
	}

	public static GoogleAiResponseSafetyDecision block(String reasonCode, String userVisibleMessage) {
		GoogleAiResponseSafetyDecision decision = new GoogleAiResponseSafetyDecision();
		decision.allowed = false;
		decision.reasonCode = reasonCode;
		decision.userVisibleMessage = userVisibleMessage;
		return decision;
	}
}
