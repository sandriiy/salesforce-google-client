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
 * Where a migration stands, derived from the platform's job records and the files already copied rather
 * than from a record of the run, which the package deliberately does not keep.
 */
public with sharing class GoogleFileMigrationProgressDTO {
	/**
	 * True while a step is queued, running or scheduled to run.
	 */
	@AuraEnabled
	public Boolean isActive = false;
	/**
	 * True while a step is executing or about to, as opposed to waiting for its scheduled time.
	 */
	@AuraEnabled
	public Boolean isStepRunning = false;
	/**
	 * When the next step is due, or null when none is scheduled.
	 */
	@AuraEnabled
	public Datetime nextStepAt;
	/**
	 * When the most recent step finished, or null when none has.
	 */
	@AuraEnabled
	public Datetime lastActivityAt;
	/**
	 * True when the most recent step ended in an error, which is how a run that stopped by itself is told
	 * apart from one that finished.
	 */
	@AuraEnabled
	public Boolean lastStepFailed = false;
	/**
	 * How many files have been copied since countedSince, capped so the count stays cheap.
	 */
	@AuraEnabled
	public Integer copiedCount = 0;
	/**
	 * True when copiedCount hit its cap and the real number is higher.
	 */
	@AuraEnabled
	public Boolean isCopiedCountCapped = false;
	/**
	 * The moment copiedCount counts from.
	 */
	@AuraEnabled
	public Datetime countedSince;
	/**
	 * Who started the most recent step, which is who started the run.
	 */
	@AuraEnabled
	public String startedByName;
}
