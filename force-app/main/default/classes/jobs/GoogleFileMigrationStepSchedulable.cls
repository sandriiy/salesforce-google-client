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
 * The scheduled hand over between two migration steps. It fires a minute after the previous step ended,
 * queues the next step as a fresh chain and removes its own scheduled entry, so nothing repeats and
 * nothing lingers under Scheduled Jobs. Cancelling the entry before it fires is what Stop does.
 */
public with sharing class GoogleFileMigrationStepSchedulable implements Schedulable {
	private final GoogleFileMigrationJob nextStep;

	/**
	 * Builds the hand over to one step.
	 *
	 * @param nextStep The step to queue when the entry fires.
	 */
	public GoogleFileMigrationStepSchedulable(GoogleFileMigrationJob nextStep) {
		this.nextStep = nextStep;
	}

	/**
	 * Queues the step and removes this entry.
	 *
	 * @param ctx The scheduled entry that fired.
	 */
	public void execute(SchedulableContext ctx) {
		if (this.nextStep != null) {
			GAsync.queueable(this.nextStep).enqueue();
		}

		System.abortJob(ctx.getTriggerId());
	}
}
