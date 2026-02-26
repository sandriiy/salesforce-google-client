public with sharing class GoogleFileWebErrorHandler implements GoogleFailureStrategy {
    public void onFailure(GoogleCloudException ex) {
		Logger.error('Google Drive API Exception: ' + ex.getMessage()).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
		Logger.error('Google Drive API Endpoint:' + ex.endpoint).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
		Logger.error('Google Drive API Headers:' + JSON.serialize(ex.httpHeaders)).addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
		Logger.error('Google Drive API Parameters:' + JSON.serialize(ex.httpParameters)).addTag('some tag').addTag(GoogleCloudConstants.DEFAULT_LOGGER_TAG);
		Logger.saveLog();
	}
}