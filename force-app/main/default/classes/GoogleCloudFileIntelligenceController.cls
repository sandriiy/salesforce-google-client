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
public with sharing class GoogleCloudFileIntelligenceController {
	@AuraEnabled
	public static GoogleFileIntelligenceStateDTO retrieveFileIntelligenceState(Id localFileVersionId) {
		try {
			return new GoogleLocalFileIntelligenceService().retrieveIntelligenceState(localFileVersionId);
		} catch (Exception ex) {
			Logger.error('Retrieve File Intelligence, Id: ' + localFileVersionId).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.error('Retrieve File Intelligence, Message: ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();

			throw new AuraHandledException('We could not load file intelligence. Please refresh the preview or contact your system administrator');
		}
	}

	@AuraEnabled
	public static GoogleFileAnalysisResultDTO answerFileQuestion(Id localFileVersionId, String question) {
		try {
			return new GoogleLocalFileIntelligenceService().answerQuestion(localFileVersionId, question);
		} catch (Exception ex) {
			Logger.error('Answer File Intelligence Question, Id: ' + localFileVersionId).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.error('Answer File Intelligence Question, Message: ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
			Logger.saveLog();

			throw new AuraHandledException('We could not answer your question about this file. Please try again or contact your system administrator');
		}
	}
}