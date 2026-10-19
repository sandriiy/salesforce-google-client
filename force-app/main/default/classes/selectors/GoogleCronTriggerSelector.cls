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
 * Reads the scheduled entries the platform keeps for jobs that run at a set time, which is how a screen
 * learns that a step of this package is waiting to run and when, and how it cancels that step.
 */
public inherited sharing class GoogleCronTriggerSelector extends GSOQL implements GSOQL.Selector {
	@TestVisible
	private static final String MOCK_ID = 'GoogleCronTriggerSelector';

	/**
	 * The states of an entry that is still going to fire.
	 */
	public static final Set<String> PENDING_STATES = new Set<String>{ 'WAITING', 'ACQUIRED', 'EXECUTING' };

	/**
	 * The state of the entry and when it fires next.
	 */
	public static final List<SObjectField> BASE_FIELDS = new List<SObjectField>{
		CronTrigger.Id,
		CronTrigger.State,
		CronTrigger.NextFireTime,
		CronTrigger.CreatedById
	};

	/**
	 * Starts a query over scheduled entries.
	 *
	 * @return A fresh selector to narrow and run.
	 */
	public static GoogleCronTriggerSelector query() {
		return new GoogleCronTriggerSelector();
	}

	public GoogleCronTriggerSelector() {
		super(CronTrigger.SObjectType);
		systemMode();
		withoutSharing();
		mockId(MOCK_ID);
	}

	/**
	 * Keeps the entries whose name starts with a prefix, which is how one feature finds its own entries
	 * among everything else scheduled in the org.
	 *
	 * @param namePrefix The start of the scheduled job name.
	 * @return This same instance, so the call chains onto toList().
	 */
	public GoogleCronTriggerSelector byJobNamePrefix(String namePrefix) {
		whereAre(Filter.with('CronJobDetail.Name').startsWith(namePrefix));
		return this;
	}

	/**
	 * Keeps the entries that are still going to fire.
	 *
	 * @return This same instance, so the call chains onto toList().
	 */
	public GoogleCronTriggerSelector byPendingStates() {
		whereAre(Filter.with(CronTrigger.State).isIn(new List<String>(PENDING_STATES)));
		return this;
	}

	/**
	 * Selects the state, the next firing time and the entry's name.
	 *
	 * @return This same instance, so the call chains onto toList().
	 */
	public GoogleCronTriggerSelector withBaseFields() {
		with(BASE_FIELDS);
		with('CronJobDetail.Name');
		return this;
	}

	/**
	 * Soonest entry first.
	 *
	 * @return This same instance, so the call chains onto toList().
	 */
	public GoogleCronTriggerSelector orderByNextFireTime() {
		orderBy(CronTrigger.NextFireTime);
		return this;
	}
}
