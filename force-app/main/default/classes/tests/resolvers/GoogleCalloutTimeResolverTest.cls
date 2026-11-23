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
private class GoogleCalloutTimeResolverTest {
	private static final Integer TRANSACTION_CALLOUT_ALLOWANCE_MILLIS = 120000;
	private static final Integer ELAPSED_WALL_TIME_MILLIS = 40;

	private static void letWallTimePass(Integer millis) {
		Long startedAt = System.currentTimeMillis();
		while (System.currentTimeMillis() - startedAt < millis) {
			Math.random();
		}
	}

	@IsTest
	private static void testResolveRequestTimeoutMillisPositiveFullAllowanceAtStart() {
		GoogleCalloutTimeResolver.elapsedMillisOverride = 0L;

		Assert.areEqual(TRANSACTION_CALLOUT_ALLOWANCE_MILLIS, new GoogleCalloutTimeResolver().resolveRequestTimeoutMillis(), 'A call made first in its transaction may wait the whole two minutes');
	}

	@IsTest
	private static void testResolveRequestTimeoutMillisPositiveShrinksWithElapsedTime() {
		GoogleCalloutTimeResolver.elapsedMillisOverride = 45000L;

		Assert.areEqual(75000, new GoogleCalloutTimeResolver().resolveRequestTimeoutMillis());
	}

	@IsTest
	private static void testResolveRequestTimeoutMillisPositiveNeverBelowOne() {
		GoogleCalloutTimeResolver.elapsedMillisOverride = 120000L;
		Assert.areEqual(1, new GoogleCalloutTimeResolver().resolveRequestTimeoutMillis(), 'A wait of 0 would be ignored by the AI client, which then waits its own 20 seconds');

		GoogleCalloutTimeResolver.elapsedMillisOverride = 130000L;
		Assert.areEqual(1, new GoogleCalloutTimeResolver().resolveRequestTimeoutMillis());
	}

	@IsTest
	private static void testResolveRequestTimeoutMillisPositiveNeverAboveTheAllowance() {
		GoogleCalloutTimeResolver.elapsedMillisOverride = -5000L;

		Assert.areEqual(TRANSACTION_CALLOUT_ALLOWANCE_MILLIS, new GoogleCalloutTimeResolver().resolveRequestTimeoutMillis(), 'A single callout can never wait longer than two minutes');
	}

	@IsTest
	private static void testHasTimeForAnotherRequestPositiveAtStart() {
		GoogleCalloutTimeResolver.elapsedMillisOverride = 0L;

		Assert.isTrue(new GoogleCalloutTimeResolver().hasTimeForAnotherRequest());
	}

	@IsTest
	private static void testHasTimeForAnotherRequestPositiveAtTheWindowEdge() {
		GoogleCalloutTimeResolver.elapsedMillisOverride = 90000L;

		Assert.areEqual(30000, GoogleCalloutTimeResolver.MIN_REQUEST_WINDOW_MILLIS);
		Assert.isTrue(new GoogleCalloutTimeResolver().hasTimeForAnotherRequest(), 'Exactly thirty seconds left is still enough to start a call');
	}

	@IsTest
	private static void testHasTimeForAnotherRequestNegativePastTheWindow() {
		GoogleCalloutTimeResolver.elapsedMillisOverride = 90001L;
		Assert.isFalse(new GoogleCalloutTimeResolver().hasTimeForAnotherRequest(), 'Under thirty seconds left, the next call belongs in a follow-up job');

		GoogleCalloutTimeResolver.elapsedMillisOverride = 130000L;
		Assert.isFalse(new GoogleCalloutTimeResolver().hasTimeForAnotherRequest());
	}

	@IsTest
	private static void testResolveRequestTimeoutMillisPositiveUnstartedClockStartsOnFirstUse() {
		GoogleCalloutTimeResolver clock = new GoogleCalloutTimeResolver();

		Integer firstWait = clock.resolveRequestTimeoutMillis();
		letWallTimePass(ELAPSED_WALL_TIME_MILLIS);
		Integer laterWait = new GoogleCalloutTimeResolver().resolveRequestTimeoutMillis();

		Assert.isTrue(firstWait <= TRANSACTION_CALLOUT_ALLOWANCE_MILLIS && firstWait > TRANSACTION_CALLOUT_ALLOWANCE_MILLIS - 1000, 'The first question starts the clock with the whole allowance, not ' + firstWait);
		Assert.isTrue(laterWait <= firstWait - ELAPSED_WALL_TIME_MILLIS, 'Asking again must not restart the clock: first ' + firstWait + ', later ' + laterWait);
	}

	@IsTest
	private static void testStartClockPositiveKeepsTheFirstMoment() {
		new GoogleCalloutTimeResolver().startClock();
		letWallTimePass(ELAPSED_WALL_TIME_MILLIS);
		new GoogleCalloutTimeResolver().startClock();

		Integer remainingWait = new GoogleCalloutTimeResolver().resolveRequestTimeoutMillis();

		Assert.isTrue(remainingWait <= TRANSACTION_CALLOUT_ALLOWANCE_MILLIS - ELAPSED_WALL_TIME_MILLIS, 'A strategy starting the clock again inside a job must not hand the job a fresh two minutes, got ' + remainingWait);
	}
}
