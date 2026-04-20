public with sharing class CustomMetadataManagerController {

    // 1. メタデータ型一覧取得 (変更なし)
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getAllMetadataTypes() {
        List<EntityDefinition> defs = [
            SELECT MasterLabel, QualifiedApiName 
            FROM EntityDefinition 
            WHERE QualifiedApiName LIKE '%__mdt'
            ORDER BY MasterLabel
        ];
        List<Map<String, String>> result = new List<Map<String, String>>();
        for(EntityDefinition def : defs) {
            result.add(new Map<String, String>{
                'Label' => def.MasterLabel,
                'DeveloperName' => def.QualifiedApiName
            });
        }
        return result;
    }

    // 2. 項目定義とデータ取得 (変更なし)
    @AuraEnabled
    public static Map<String, Object> getMetadataRecordsAndColumns(String metadataName) {
        Map<String, Object> result = new Map<String, Object>();
        
        SObjectType sType = Schema.getGlobalDescribe().get(metadataName);
        if (sType == null) {
            throw new AuraHandledException('Invalid Metadata Type: ' + metadataName);
        }
        
        Map<String, SObjectField> fieldMap = sType.getDescribe().fields.getMap();
        List<Map<String, String>> columns = new List<Map<String, String>>();
        List<String> queryFields = new List<String>();

        columns.add(new Map<String, String>{'label' => 'Label', 'fieldName' => 'MasterLabel'});
        columns.add(new Map<String, String>{'label' => 'DeveloperName', 'fieldName' => 'DeveloperName'});
        queryFields.add('Id');
        queryFields.add('MasterLabel');
        queryFields.add('DeveloperName');

        for (String fieldName : fieldMap.keySet()) {
            DescribeFieldResult dfr = fieldMap.get(fieldName).getDescribe();
            String apiName = dfr.getName();
            
            if (apiName.endsWith('__c')) {
                columns.add(new Map<String, String>{
                    'label' => dfr.getLabel(),
                    'fieldName' => apiName
                });
                queryFields.add(apiName);
            }
        }
        result.put('columns', columns);

        String query = 'SELECT ' + String.join(queryFields, ',') + ' FROM ' + String.escapeSingleQuotes(metadataName) + ' ORDER BY MasterLabel LIMIT 2000';
        List<SObject> records = Database.query(query);
        result.put('data', records);

        return result;
    }

    // 3. デプロイ実行 (★修正: 型変換ロジックを追加)
    @AuraEnabled
    public static String deployMetadata(String metadataType, String jsonRecords) {
        try {
            List<Object> rawRecords = (List<Object>) JSON.deserializeUntyped(jsonRecords);
            Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
            
            // --- ★追加: メタデータの項目定義を取得しておく ---
            SObjectType sType = Schema.getGlobalDescribe().get(metadataType);
            Map<String, SObjectField> fieldMap = sType.getDescribe().fields.getMap();

            for (Object obj : rawRecords) {
                Map<String, Object> row = (Map<String, Object>) obj;

                Metadata.CustomMetadata customMetadata = new Metadata.CustomMetadata();
                String devName = (String) row.get('DeveloperName');
                String label = (String) row.get('MasterLabel');
                
                customMetadata.fullName = metadataType + '.' + devName;
                customMetadata.label = label;
                
                for (String key : row.keySet()) {
                    // システム項目や基本項目はスキップ
                    if (key == 'DeveloperName' || key == 'MasterLabel' || key == 'Id' || key == 'attributes') {
                        continue;
                    }

                    // 項目の存在確認
                    if (!fieldMap.containsKey(key)) {
                        continue; 
                    }

                    Metadata.CustomMetadataValue customField = new Metadata.CustomMetadataValue();
                    customField.field = key;

                    // CSVの値(String)を取得
                    Object rawValue = row.get(key);
                    String strValue = String.valueOf(rawValue);

                    // --- ★追加: 型に合わせて変換する ---
                    DescribeFieldResult dfr = fieldMap.get(key).getDescribe();
                    Schema.DisplayType dtype = dfr.getType();

                    if (String.isEmpty(strValue)) {
                        customField.value = null;
                    } else if (dtype == Schema.DisplayType.BOOLEAN) {
                        // チェックボックス: "true", "TRUE", "1" などを Boolean に変換
                        customField.value = Boolean.valueOf(strValue);
                    } else if (dtype == Schema.DisplayType.DOUBLE || 
                               dtype == Schema.DisplayType.PERCENT || 
                               dtype == Schema.DisplayType.CURRENCY || 
                               dtype == Schema.DisplayType.INTEGER) {
                        // 数値・通貨・パーセント: Double に変換
                        customField.value = Double.valueOf(strValue);
                    } else if (dtype == Schema.DisplayType.DATE) {
                        // 日付: YYYY-MM-DD 文字列を Date に変換
                        customField.value = Date.valueOf(strValue);
                    } else if (dtype == Schema.DisplayType.DATETIME) {
                        // 日時: ISO文字列を Datetime に変換
                        customField.value = (Datetime) JSON.deserialize('"' + strValue + '"', Datetime.class);
                    } else {
                        // テキスト系: そのまま
                        customField.value = strValue;
                    }
                    
                    customMetadata.values.add(customField);
                }
                mdContainer.addMetadata(customMetadata);
            }
            return Metadata.Operations.enqueueDeployment(mdContainer, null);

        } catch (Exception e) {
            throw new AuraHandledException('Deploy Error: ' + e.getMessage());
        }
    }

    // 4. ステータス確認 (変更なし)
    @AuraEnabled
    public static String checkDeployStatus(String jobId) {
        String baseUrl = Url.getOrgDomainUrl().toExternalForm();
        String endpoint = baseUrl + '/services/data/v60.0/tooling/sobjects/DeployRequest/' + jobId;

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        req.setHeader('Content-Type', 'application/json');

        Http http = new Http();
        try {
            HttpResponse res = http.send(req);
            if (res.getStatusCode() == 200) {
                Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                return (String) result.get('Status');
            } else {
                return 'Unknown'; 
            }
        } catch (Exception e) {
            throw new AuraHandledException('Status Check Error: ' + e.getMessage());
        }
    }
}