public interface IGoogleFileIntelligenceStrategy {
    GoogleFileAnalysisResultDTO summarize(Id localGoogleFileVersionId);
	GoogleFileAnalysisResultDTO answerQuestion(Id localGoogleFileVersionId, String question);
	Boolean validate();
}