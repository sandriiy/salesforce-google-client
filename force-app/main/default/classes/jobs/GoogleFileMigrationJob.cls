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
 * One step of a migration of Salesforce Files into Google Drive. Each step copies what one transaction
 * can hold and then hands over to the next step through a scheduled entry a minute out rather than by
 * chaining it: a chain keeps every job it has run, so a migration chained end to end would grow without
 * bound and wait behind the preview and folder jobs of every file it copied. The scheduled entry runs in
 * a fresh context, which starts a fresh chain, while this step's follow up jobs finish in their own. The
 * entry's name starts with STEP_JOB_NAME_PREFIX, which is how the screen sees that a step is pending and
 * how Stop cancels it.
 */
public with sharing class GoogleFileMigrationJob extends GQueueableJob.AllowsCallouts {
	public class GoogleFileMigrationJobException extends Exception {}

	/**
	 * The start of every scheduled step's name, shared with the service that reads and cancels them.
	 */
	public static final String STEP_JOB_NAME_PREFIX = 'Google Client file migration';
	/**
	 * The number the first step of a run carries.
	 */
	public static final Integer FIRST_STEP_NUMBER = 1;

	private static final Integer STEP_DELAY_MINUTES = 1;
	private static final String STEP_NAME_SEPARATOR = '/';
	private static final String CRON_ANY_DAY_OF_WEEK = '?';
	private static final String STEP_FAILED_MESSAGE = 'The migration step could not be completed. Run the migration again to continue; files already copied are skipped';

	@TestVisible
	private static Boolean skipExecution = false;

	private final GoogleFileMigrationRequestDTO request;
	private final Integer stepNumber;
	private Database.Cursor cursor;
	private Integer position;

	/**
	 * Builds one step.
	 *
	 * @param request What the run was asked to do.
	 * @param cursor The cursor the run walks, or null to open it from the request.
	 * @param position Where this step starts in the cursor.
	 * @param stepNumber Which step of the run this is, counting from FIRST_STEP_NUMBER.
	 */
	public GoogleFileMigrationJob(GoogleFileMigrationRequestDTO request, Database.Cursor cursor, Integer position, Integer stepNumber) {
		this.request = request;
		this.cursor = cursor;
		this.position = position == null ? 0 : position;
		this.stepNumber = stepNumber == null ? FIRST_STEP_NUMBER : stepNumber;
	}

	/**
	 * Copies the next files, then schedules the following step unless the walk is over or this step was
	 * cancelled while it ran. A step that fails is reported as failed by the platform, and the next run
	 * picks up where the files already copied end.
	 */
	public override void work() {
		if (skipExecution) return;
		if (this.request == null) return;

		GoogleLocalFileMigrationService migrationService = new GoogleLocalFileMigrationService();
		Logger.info('Migration Step --> Step=' + this.stepNumber + ', Position=' + this.position).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

		GoogleLocalFileMigrationService.StepResult step;
		try {
			if (this.cursor == null) {
				this.cursor = migrationService.openCandidateCursor(this.request.condition);
			}

			step = migrationService.runStep(this.cursor, this.position, this.request);
		} catch (Exception ex) {
			Logger.error('Migration Step Failed --> Step=' + this.stepNumber + ', Position=' + this.position + ', Message=' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();
			throw new GoogleFileMigrationJobException(STEP_FAILED_MESSAGE);
		}

		Logger.info('Migration Step Done --> Step=' + this.stepNumber + ', Copied=' + step.copiedCount + ', Failed=' + step.failedCount + ', Skipped=' + step.skippedCount + ', Deferred=' + step.deferredCount + ', NextPosition=' + step.nextPosition + ', Exhausted=' + String.valueOf(step.isExhausted)).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);

		if (!step.isExhausted && !migrationService.isStepAborted(this.queueableCtx == null ? null : this.queueableCtx.getJobId())) {
			scheduleNextStep(new GoogleFileMigrationJob(this.request, step.cursor, step.nextPosition, this.stepNumber + 1));
		}

		Logger.saveLog();
	}

	private void scheduleNextStep(GoogleFileMigrationJob nextStep) {
		Datetime fireAt = Datetime.now().addMinutes(STEP_DELAY_MINUTES);
		GCronBuilder cron = new GCronBuilder()
			.second(String.valueOf(fireAt.second()))
			.minute(String.valueOf(fireAt.minute()))
			.hour(String.valueOf(fireAt.hour()))
			.dayOfMonth(String.valueOf(fireAt.day()))
			.month(String.valueOf(fireAt.month()))
			.dayOfWeek(CRON_ANY_DAY_OF_WEEK)
			.optionalYear(String.valueOf(fireAt.year()));

		GAsync.schedulable(new GoogleFileMigrationStepSchedulable(nextStep))
			.name(STEP_JOB_NAME_PREFIX + STEP_NAME_SEPARATOR + nextStep.stepNumber + STEP_NAME_SEPARATOR + UUID.randomUUID().toString())
			.cronExpression(cron)
			.schedule();
	}
}
