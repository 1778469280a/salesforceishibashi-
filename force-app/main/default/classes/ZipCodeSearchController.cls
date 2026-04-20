public with sharing class ZipCodeSearchController {
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> searchAddress(String zipcode) {
        String cleanZip = zipcode?.remove('-');
        if (String.isBlank(cleanZip) || cleanZip.length() != 7 || !cleanZip.isNumeric()) {
            return new Map<String, Object>{
                'status' => 400,
                'message' => '郵便番号は7桁の数字で入力してください'
            };
        }
        String endpoint = 'https://zipcloud.ibsnet.co.jp/api/search?zipcode=' + cleanZip;
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setTimeout(10000);

        try {
            Http http = new Http();
            HttpResponse res = http.send(req);
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return result;
        } catch (Exception e) {
            return new Map<String, Object>{
                'status' => 500,
                'message' => 'API接続エラー: ' + e.getMessage()
            };
        }
    }
}