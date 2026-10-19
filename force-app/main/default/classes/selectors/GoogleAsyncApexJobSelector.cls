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
 * Reads the platform's own record of background work, which is how a screen learns whether one of this
 * package's jobs is queued, running or has just finished without the package keeping a record of its own.
 * Salesforce keeps these rows for seven days.
 */
public inherited sharing class GoogleAsyncApexJobSelector extends GSOQL implements GSOQL.Selector {
	@TestVisible
	private static final String MOCK_ID = 'GoogleAsyncApexJobSelector';

	/**
	 * The states a job can be in while it is still going to run or is running now.
	 */
	public static final Set<String> PENDING_STATUSES = new Set<String>{ 'Queued', 'Holding', 'Preparing', 'Processing' };
	/**
	 * The state of a job that ended in an error.
	 */
	public static final String FAILED_STATUS = 'Failed';
	/**
	 * The state of a job that was cancelled before or while it ran.
	 */
	public static final String ABORTED_STATUS = 'Aborted';

	/**
	 * The state of a job, when it started and ended, and what it reported.
	 */
	public static final List<SObjectField> BASE_FIELDS = new List<SObjectField>{
		AsyncApexJob.Id,
		AsyncApexJob.Status,
		AsyncApexJob.ExtendedStatus,
		AsyncApexJob.JobType,
		AsyncApexJob.CreatedById,
		AsyncApexJob.CreatedDate,
		AsyncApexJob.CompletedDate
	};

	private static final String QUEUEABLE_JOB_TYPE = 'Queueable';

	/**
	 * Starts a query over background jobs.
	 *
	 * @return A fresh selector to narrow and run.
	 */
	public static GoogleAsyncApexJobSelector query() {
		return new GoogleAsyncApexJobSelector();
	}

	public GoogleAsyncApexJobSelector() {
		super(AsyncApexJob.SObjectType);
		systemMode();
		withoutSharing();
		mockId(MOCK_ID);
	}

	/**
	 * Keeps the runs of one job class.
	 *
	 * @param apexClassName The class name, without a namespace.
	 * @return This same instance, so the call chains onto toList().
	 */
	public GoogleAsyncApexJobSelector byApexClassName(String apexClassName) {
		whereAre(Filter.with('ApexClass.Name').equal(apexClassName));
		return this;
	}

	/**
	 * Keeps the jobs in any of those states.
	 *
	 * @param statuses The states to match, such as PENDING_STATUSES.
	 * @return This same instance, so the call chains onto toList().
	 */
	public GoogleAsyncApexJobSelector byStatuses(Set<String> statuses) {
		whereAre(Filter.with(AsyncApexJob.Status).isIn(new List<String>(statuses)));
		return this;
	}

	/**
	 * Keeps the queueable runs, leaving out the scheduled entries and batches of the same class.
	 *
	 * @return This same instance, so the call chains onto toList().
	 */
	public GoogleAsyncApexJobSelector byQueueableType() {
		whereAre(Filter.with(AsyncApexJob.JobType).equal(QUEUEABLE_JOB_TYPE));
		return this;
	}

	/**
	 * Selects the state and timing of each job, with the class and the user who started it.
	 *
	 * @return This same instance, so the call chains onto toList().
	 */
	public GoogleAsyncApexJobSelector withBaseFields() {
		with(BASE_FIELDS);
		with('ApexClass.Name');
		with('CreatedBy.Name');
		return this;
	}

	/**
	 * Newest job first.
	 *
	 * @return This same instance, so the call chains onto toList().
	 */
	public GoogleAsyncApexJobSelector orderByCreatedDesc() {
		orderBy(AsyncApexJob.CreatedDate).sortDesc();
		return this;
	}

	/**
	 * Caps how many rows come back.
	 *
	 * @param n The maximum number of jobs.
	 * @return This same instance, so the call chains onto toList().
	 */
	public GoogleAsyncApexJobSelector limitTo(Integer n) {
		setLimit(n);
		return this;
	}
}
