public with sharing class GenAiClientFactory {
    private IGenAiTransport transport;

    public GenAiClientFactory() {
        this(new GenAiHttpTransport());
    }

    public GenAiClientFactory(IGenAiTransport transport) {
        this.transport = transport;
    }

    public IGenAiClient google(GenAiGoogleConfig config) {
        return new GenAiClient(new GenAiGoogleProvider(config), transport);
    }
}