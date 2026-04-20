public without sharing class SecretUtil {
    private static final String FIXED_KEY_BASE64 = 'mbTLdmVLN3dVjExO0zaB3h/5zpJ5vaL6BbJv1D8FtHk=';
    private static Blob cryptoKey {
        get {
            return EncodingUtil.base64Decode(FIXED_KEY_BASE64);
        }
    }

    public static void setEncryptedSecret(String plainSecret) {
        Blob encryptedBlob = Crypto.encryptWithManagedIV('AES256', cryptoKey, Blob.valueOf(plainSecret));
        String encryptedString = EncodingUtil.base64Encode(encryptedBlob);
        
        PORTERSAPI_Settings__c settings = PORTERSAPI_Settings__c.getOrgDefaults();
        settings.Client_Secret__c = encryptedString;
        upsert settings;
    }

    public static String getDecryptedSecret() {
        if (Test.isRunningTest()) {
            return 'test_secret';
        }

        PORTERSAPI_Settings__c settings = PORTERSAPI_Settings__c.getOrgDefaults();
        if (String.isBlank(settings.Client_Secret__c)) return null;
        
        Blob encryptedBlob = EncodingUtil.base64Decode(settings.Client_Secret__c);
        Blob decryptedBlob = Crypto.decryptWithManagedIV('AES256', cryptoKey, encryptedBlob);
        return decryptedBlob.toString();
    }
}