public with sharing class GoogleFileIntelligenceFactory {
	public class GoogleFileIntelligenceFactoryException extends Exception {}

	private GoogleMetadataConfigService metadataConfig;
	public GoogleFileIntelligenceFactory() {
		this.metadataConfig = new GoogleMetadataConfigService();
	}

    public IGoogleFileIntelligenceStrategy create() {
		String geminiKey = metadataConfig.getGoogleGeminiKey();
		String vertexLocation = metadataConfig.getGoogleVertexLocation();
		String vertexProjectId = metadataConfig.getGoogleVertexProjectId();

		if (String.isNotBlank(geminiKey)) {
			return new GoogleGeminiIntelligenceStrategy();
		} else if (String.isNotBlank(vertexLocation) && String.isNotBlank(vertexProjectId)) {
			return new GoogleVertexIntelligenceStrategy();
		} else {
			throw new GoogleFileIntelligenceFactoryException('Unable to determine which Google AI Strategy to use. Please verify the configuration for Gemini or Vertex AI is set correctly');
		}
    }
}