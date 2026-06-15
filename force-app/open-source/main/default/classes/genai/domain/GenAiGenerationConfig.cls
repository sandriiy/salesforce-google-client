public class GenAiGenerationConfig {
    public Decimal temperature;
    public Decimal topP;
    public Integer topK;
    public Integer candidateCount;
    public Integer maxTokens;
    public Decimal presencePenalty;
    public Decimal frequencyPenalty;
    public String responseMimeType;
    public Integer seed;
    public Boolean responseLogprobs;
    public Integer logprobs;
    public List<String> stopSequences;
    public Map<String, Object> responseSchema;
    public List<String> responseModalities;

    public GenAiGenerationConfig() {
        this.stopSequences = new List<String>();
        this.responseSchema = new Map<String, Object>();
        this.responseModalities = new List<String>();
    }

    public GenAiGenerationConfig addStop(String stopSequence) {
        if (String.isNotBlank(stopSequence)) {
            stopSequences.add(stopSequence);
        }
        return this;
    }

    public GenAiGenerationConfig setResponseSchema(Map<String, Object> responseSchema) {
        this.responseSchema = responseSchema == null ? new Map<String, Object>() : responseSchema;
        return this;
    }

    public GenAiGenerationConfig addResponseModality(String modality) {
        if (String.isNotBlank(modality)) {
            responseModalities.add(modality);
        }
        return this;
    }

    public Boolean isEmpty() {
        return temperature == null
            && topP == null
            && topK == null
            && candidateCount == null
            && maxTokens == null
            && presencePenalty == null
            && frequencyPenalty == null
            && String.isBlank(responseMimeType)
            && seed == null
            && responseLogprobs == null
            && logprobs == null
            && stopSequences.isEmpty()
            && responseSchema.isEmpty()
            && responseModalities.isEmpty();
    }
}