public class GoogleFileHeaderInfoDTO {
    @AuraEnabled public String name;
    @AuraEnabled public List<CompactFieldDTO> compactFields;

    public class CompactFieldDTO {
        @AuraEnabled public String apiName;
        @AuraEnabled public String label;
        @AuraEnabled public String displayValue;
        @AuraEnabled public Boolean isReference;
        @AuraEnabled public Id referenceId;
    }
}
