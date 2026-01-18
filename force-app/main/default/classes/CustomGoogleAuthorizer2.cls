public with sharing class CustomGoogleAuthorizer2 implements GoogleAuthorizer {
    private final String SERVICE_ACCOUNT_EMAIL = 'googleclient1@inspiring-dryad-481303-f4.iam.gserviceaccount.com';
    private final String CERTIFICATE_NAME = 'privatekey';

    public String retrieveAccessToken() {
        Auth.JWT jwt = new Auth.JWT();
        jwt.setAud('https://oauth2.googleapis.com/token');
        jwt.setSub(SERVICE_ACCOUNT_EMAIL);
        jwt.setIss(SERVICE_ACCOUNT_EMAIL);
        jwt.setAdditionalClaims(new Map<String, Object>{'scope' => 'https://www.googleapis.com/auth/drive'});

        Auth.JWS jws = new Auth.JWS(jwt, CERTIFICATE_NAME);

        Auth.JWTBearerTokenExchange bearer = new Auth.JWTBearerTokenExchange(
            jwt.getAud(),
            jws
        );

        return bearer.getAccessToken();
    }
}