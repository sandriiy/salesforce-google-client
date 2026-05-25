public with sharing class GoogleCloudFileIntelligenceController {
	@AuraEnabled(cacheable=true)
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