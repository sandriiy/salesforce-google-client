public class GenAiAccessToken implements IGenAiAccessTokenProvider {
    private String tokenType;
    private String value;

    public GenAiAccessToken(String tokenType, String value) {
        this.tokenType = tokenType;
        this.value = value;
    }

    public String headerValue() {
        if (String.isBlank(value)) {
            return null;
        }

        String resolvedType = String.isBlank(tokenType) ? 'Bearer' : tokenType.trim();
        return resolvedType + ' ' + value.trim();
    }

    public GenAiAccessToken token() {
        return this;
    }
}