public class GenAiResponse {
    private static final String SUCCESS_REASON = 'SUCCESS';
    private static final String NO_CANDIDATE_REASON = 'NO_CANDIDATE';
    private static final String NO_CONTENT_REASON = 'NO_CONTENT';

    public Integer statusCode;
    public String rawBody;
    public String modelVersion;
    public Map<String, Object> raw;
    public List<GenAiCandidate> candidates;
    public GenAiUsage usage;

    public GenAiResponse() {
        this.candidates = new List<GenAiCandidate>();
    }

    public void addCandidate(GenAiCandidate candidate) {
        if (candidate != null) {
            candidates.add(candidate);
        }
    }

    public Boolean hasCandidates() {
        return !candidates.isEmpty();
    }

    public GenAiCandidate firstCandidate() {
        return hasCandidates() ? candidates[0] : null;
    }

    public String firstText() {
        GenAiCandidate candidate = firstCandidate();
        return candidate == null ? null : candidate.text();
    }

    public String outcomeReason() {
        GenAiCandidate candidate = firstCandidate();

        if (candidate == null) {
            return NO_CANDIDATE_REASON;
        }

        String baseReason = hasUsableContent(candidate) ? SUCCESS_REASON : NO_CONTENT_REASON;
        String finishReason = String.isBlank(candidate.finishReason) ? null : candidate.finishReason.trim();

        return finishReason == null ? baseReason : baseReason + '_' + finishReason;
    }

    private Boolean hasUsableContent(GenAiCandidate candidate) {
        return candidate != null
            && candidate.content != null
            && candidate.content.parts != null
            && !candidate.content.parts.isEmpty();
    }
}