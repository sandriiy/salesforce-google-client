public with sharing class DefaultGoogleDriveAuthorizer implements GoogleAuthorizer {
    private GoogleMetadataConfigService metadataService = new GoogleMetadataConfigService();

    public String retrieveAccessToken() {
        Auth.JWT jwt = new Auth.JWT();
        jwt.setAud('https://oauth2.googleapis.com/token');
        jwt.setSub(metadataService.getGoogleDriveServiceAccountEmail());
        jwt.setIss(metadataService.getGoogleDriveServiceAccountEmail());
        jwt.setAdditionalClaims(new Map<String, Object>{'scope' => 'https://www.googleapis.com/auth/drive https://www.googleapis.com/auth/cloud-platform'});

        Auth.JWS jws = new Auth.JWS(jwt, metadataService.getGoogleDriveCertificateName());
        Auth.JWTBearerTokenExchange bearer = new Auth.JWTBearerTokenExchange(
            jwt.getAud(),
            jws
        );

        return bearer.getAccessToken();
    }
}