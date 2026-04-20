public with sharing class PicklistController {
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getPicklistOptions(String objectName, String fieldName) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        Schema.SObjectType objType = globalDescribe.get(objectName);
        if (objType == null) {
            return options;
        }
        Map<String, Schema.SObjectField> fieldMap = objType.getDescribe().fields.getMap();
        Schema.SObjectField field = fieldMap.get(fieldName);
        if (field == null) {
            return options;
        }
        
        Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
        if (fieldDescribe.getType() != Schema.DisplayType.Picklist && 
            fieldDescribe.getType() != Schema.DisplayType.MultiPicklist) {
            return options;
        }
        
        List<Schema.PicklistEntry> picklistEntries = fieldDescribe.getPicklistValues();
        
        for (Schema.PicklistEntry entry : picklistEntries) {
            if (entry.isActive()) {
                options.add(new Map<String, String>{
                    'label' => entry.getLabel(),
                    'value' => entry.getValue()
                });
            }
        }
        return options;
    }
}