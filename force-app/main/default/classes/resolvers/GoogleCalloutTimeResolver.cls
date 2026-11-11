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
 * Keeps track of how much of the transaction's two minutes of callout time is left, so a call can wait as
 * long as Salesforce still allows and a job knows when the next call no longer fits. The clock starts the
 * first time anything asks, once per transaction, and measures wall time, which is never less than the
 * time spent in callouts, so the rule stays on the safe side.
 */
public with sharing class GoogleCalloutTimeResolver {
	public static final Integer MIN_REQUEST_WINDOW_MILLIS = 30000;

	private static final Integer TRANSACTION_CALLOUT_ALLOWANCE_MILLIS = 120000;
	private static final Integer SHORTEST_REQUEST_TIMEOUT_MILLIS = 1;

	private static Long clockStartedAtMillis;

	@TestVisible
	private static Long elapsedMillisOverride;

	/**
	 * Starts the clock for this transaction. Calling it again does nothing, so a strategy starting it inside
	 * a job never hands that job a fresh two minutes.
	 */
	public void startClock() {
		if (clockStartedAtMillis == null) {
			clockStartedAtMillis = System.currentTimeMillis();
		}
	}

	/**
	 * How long the next call may wait: whatever callout time the transaction has left, never more than the
	 * two minutes Salesforce allows one call and never 0, which the AI client would ignore in favour of its
	 * own 20 seconds.
	 *
	 * @return The wait in milliseconds, from 1 to 120,000.
	 */
	public Integer resolveRequestTimeoutMillis() {
		return resolveRequestTimeoutMillis(0);
	}

	/**
	 * How long the next call may wait when the caller still needs callout time after it, for example to
	 * apply what the call decided: what is left minus that reserve, within the same bounds.
	 *
	 * @param reservedMillis The callout time to keep for after the call. Null counts as none.
	 * @return The wait in milliseconds, from 1 to 120,000.
	 */
	public Integer resolveRequestTimeoutMillis(Integer reservedMillis) {
		Long remainingMillis = resolveRemainingMillis() - (reservedMillis == null ? 0 : reservedMillis);
		if (remainingMillis < SHORTEST_REQUEST_TIMEOUT_MILLIS) return SHORTEST_REQUEST_TIMEOUT_MILLIS;
		if (remainingMillis > TRANSACTION_CALLOUT_ALLOWANCE_MILLIS) return TRANSACTION_CALLOUT_ALLOWANCE_MILLIS;
		return remainingMillis.intValue();
	}

	/**
	 * Says whether another call still fits in this transaction, which needs MIN_REQUEST_WINDOW_MILLIS left.
	 * A job asks before every file after its first, and hands the rest to a follow-up job when the answer is
	 * no.
	 *
	 * @return True when a new call may start.
	 */
	public Boolean hasTimeForAnotherRequest() {
		return resolveRemainingMillis() >= MIN_REQUEST_WINDOW_MILLIS;
	}

	private Long resolveRemainingMillis() {
		return TRANSACTION_CALLOUT_ALLOWANCE_MILLIS - resolveElapsedMillis();
	}

	private Long resolveElapsedMillis() {
		if (elapsedMillisOverride != null) return elapsedMillisOverride;

		startClock();
		return System.currentTimeMillis() - clockStartedAtMillis;
	}
}
