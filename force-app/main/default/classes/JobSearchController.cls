/**
 * 求人検索コントローラクラス
 * 市区町村（City__mdt）によるフィルタリング機能を追加した完全版。
 */
public with sharing class JobSearchController {

    public class JobWrapper {
        @AuraEnabled public Id Id;
        @AuraEnabled public String JobPosition;
        @AuraEnabled public String WorkLocation2;
        @AuraEnabled public String JobCategory1;
        @AuraEnabled public Decimal MaxAnnualSalary;
        @AuraEnabled public Decimal MinAnnualSalary;
        @AuraEnabled public String JobDescription;
        @AuraEnabled public Datetime LastModifiedDate;
        @AuraEnabled public Datetime LastViewedDate;
        @AuraEnabled public Boolean IsFavorite;
        @AuraEnabled public String MainIndustry;
    }

    @AuraEnabled(cacheable=true)
    public static List<JobWrapper> getJobs(Map<String, Object> filters) {
        Set<Id> favoriteJobIds = new Set<Id>();
        if (UserInfo.getUserId() != null) {
            for (InterestedJob__c fav : [
                SELECT Job__c FROM InterestedJob__c
                WHERE CreatedById = :UserInfo.getUserId() AND IsArchive__c = false
                LIMIT 1000
            ]) {
                favoriteJobIds.add(fav.Job__c);
            }
        }

        String baseQuery = 'SELECT Id FROM Job__c';
        List<String> baseConditions = new List<String>();
        
        List<String> jobCats = filters.containsKey('categories') ? convertToListOfString(filters.get('categories')) : new List<String>();
        List<String> prefectures = filters.containsKey('prefectures') ? convertToListOfString(filters.get('prefectures')) : new List<String>();
        List<String> cities = filters.containsKey('cities') ? convertToListOfString(filters.get('cities')) : new List<String>();
        
        if (!jobCats.isEmpty()) {
            baseConditions.add('JobCategoryDetail1__c IN :jobCats');
        }

        List<String> locationConditions = new List<String>();
        if (!prefectures.isEmpty()) {
            locationConditions.add('WorkLocationPrefecture__c IN :prefectures');
        }
        if (!cities.isEmpty()) {
            locationConditions.add('WorkLocationCity__c IN :cities');
        }
        if (!locationConditions.isEmpty()) {
            baseConditions.add('(' + String.join(locationConditions, ' OR ') + ')');
        }

        if (filters.containsKey('minSalary')) {
            String minSalaryStr = String.valueOf(filters.get('minSalary')).trim();
            if (String.isNotBlank(minSalaryStr) && isNumeric(minSalaryStr)) {
                Decimal minSalaryValue = Decimal.valueOf(minSalaryStr);
                baseConditions.add('MinAnnualSalary__c >= :minSalaryValue');
            }
        }

        if (filters.containsKey('transfer')) {
            String transfer = String.valueOf(filters.get('transfer')).trim();
            if (String.isNotBlank(transfer)) {
                baseConditions.add('TransferRequired__c = :transfer');
            }
        }

        if (filters.containsKey('conditions')) {
            List<String> specificConds = convertToListOfString(filters.get('conditions'));
            if (!specificConds.isEmpty()) {
                List<String> includesList = new List<String>();
                for (String cond : specificConds) {
                    includesList.add('SpecificConditions__c INCLUDES (\'' + String.escapeSingleQuotes(cond) + '\')');
                }
                baseConditions.add('(' + String.join(includesList, ' AND ') + ')');
            }
        }

        if (!baseConditions.isEmpty()) {
            baseQuery += ' WHERE ' + String.join(baseConditions, ' AND ');
        }

        Set<Id> baseJobIds = new Set<Id>();
        for (Job__c job : Database.query(baseQuery)) {
            baseJobIds.add(job.Id);
        }

        Set<Id> finalJobIds = new Set<Id>();
        String keyword = filters.containsKey('keyword') ? String.valueOf(filters.get('keyword')).trim() : '';
        if (String.isNotBlank(keyword)) {
            for (Job__c job : [SELECT Id, SearchKeywords__c FROM Job__c WHERE Id IN :baseJobIds]) {
                if (job.SearchKeywords__c != null && job.SearchKeywords__c.containsIgnoreCase(keyword)) {
                    finalJobIds.add(job.Id);
                }
            }
        } else {
            finalJobIds = baseJobIds;
        }

        String finalQuery = 'SELECT Id, JobPosition__c, WorkLocation2__c, JobCategory1__c, ' +
                            'MaxAnnualSalary__c, MinAnnualSalary__c, JobDescription__c, LastModifiedDate, LastViewedDate, Company__r.MainIndustry__c ' +
                            'FROM Job__c WHERE Id IN :finalJobIds';

        String sortBy = 'LastModifiedDate DESC';
        if (filters.containsKey('sortBy')) {
            String sortParam = String.valueOf(filters.get('sortBy'));
            if (sortParam == 'highestSalary') sortBy = 'MaxAnnualSalary__c DESC';
            else if (sortParam == 'lowestSalary') sortBy = 'MaxAnnualSalary__c ASC';
            else if (sortParam == 'recommended') sortBy = 'CreatedDate DESC';
        }
        finalQuery += ' ORDER BY ' + sortBy;

        List<JobWrapper> result = new List<JobWrapper>();
        for (Job__c j : Database.query(finalQuery)) {
            JobWrapper wrapper = new JobWrapper();
            wrapper.Id = j.Id;
            wrapper.JobPosition = j.JobPosition__c;
            wrapper.WorkLocation2 = j.WorkLocation2__c;
            wrapper.JobCategory1 = j.JobCategory1__c;
            wrapper.MaxAnnualSalary = j.MaxAnnualSalary__c;
            wrapper.MinAnnualSalary = j.MinAnnualSalary__c;
            wrapper.JobDescription = j.JobDescription__c;
            wrapper.LastModifiedDate = j.LastModifiedDate;
            wrapper.LastViewedDate = j.LastViewedDate;
            wrapper.IsFavorite = favoriteJobIds.contains(j.Id);
            wrapper.MainIndustry = (j.Company__r != null) ? j.Company__r.MainIndustry__c : null;
            result.add(wrapper);
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getFilterOptions() {
        return new Map<String, Object>{
            'jobCategories' => getJobCategories(),
            'regions' => getDistinctValues('WorkLocationRegion__c'),
            'prefectures' => getDistinctValues('WorkLocationPrefecture__c'),
            'cities' => [SELECT MasterLabel, CityName__c, Sort__c FROM City__mdt ORDER BY Sort__c ASC],
            'specificConditions' => getPicklistValues('Job__c', 'SpecificConditions__c')
        };
    }

    private static List<Map<String, String>> getJobCategories() {
        List<Map<String, String>> categories = new List<Map<String, String>>();
        for (AggregateResult ar : [
            SELECT JobCategory1__c, JobCategoryDetail1__c FROM Job__c 
            WHERE JobCategory1__c != null GROUP BY JobCategory1__c, JobCategoryDetail1__c
            ORDER BY JobCategory1__c, JobCategoryDetail1__c
        ]) {
            categories.add(new Map<String, String>{
                'JobCategory1__c' => (String)ar.get('JobCategory1__c'),
                'JobCategoryDetail1__c' => (String)ar.get('JobCategoryDetail1__c')
            });
        }
        return categories;
    }

    private static List<String> getDistinctValues(String fieldName) {
        Set<String> values = new Set<String>();
        String query = 'SELECT ' + fieldName + ' FROM Job__c WHERE ' + fieldName + ' != NULL LIMIT 5000';
        for (Job__c job : Database.query(query)) {
            values.addAll(splitAndTrim((String)job.get(fieldName)));
        }
        List<String> sortedValues = new List<String>(values);
        sortedValues.sort();
        return sortedValues;
    }

    private static List<String> splitAndTrim(String input) {
        List<String> result = new List<String>();
        if (String.isNotBlank(input)) {
            for (String item : input.split(';')) {
                if (String.isNotBlank(item)) result.add(item.trim());
            }
        }
        return result;
    }

    private static List<String> getPicklistValues(String objectName, String fieldName) {
        List<String> values = new List<String>();
        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
        if (objType != null) {
            Schema.DescribeFieldResult fieldResult = objType.getDescribe().fields.getMap().get(fieldName).getDescribe();
            for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
                if (entry.isActive()) values.add(entry.getLabel());
            }
        }
        return values;
    }

    private static List<String> convertToListOfString(Object obj) {
        List<String> result = new List<String>();
        if (obj instanceof List<Object>) {
            for (Object item : (List<Object>)obj) result.add(String.valueOf(item).trim());
        } else if (obj instanceof String) {
            String s = (String)obj;
            result = s.contains(',') ? s.split(',') : new List<String>{ s.trim() };
        }
        return result;
    }

    private static Boolean isNumeric(String str) {
        try { Decimal.valueOf(str); return true; } catch (Exception e) { return false; }
    }

    @AuraEnabled
    public static Boolean toggleFavoriteJob(String jobId, Boolean isFavorite) {
        try {
            Id userId = UserInfo.getUserId();
            List<InterestedJob__c> existing = [SELECT Id FROM InterestedJob__c WHERE Job__c = :jobId AND CreatedById = :userId LIMIT 1];
            if (!existing.isEmpty()) {
                existing[0].IsArchive__c = !isFavorite;
                update existing[0];
            } else if (isFavorite) {
                insert new InterestedJob__c(Job__c = jobId, IsArchive__c = false);
            }
            return true;
        } catch (Exception e) { return false; }
    }

    @AuraEnabled
    public static List<JobWrapper> getRecommendedJobs(Map<String, Object> filters) {
        if (filters == null) return new List<JobWrapper>();
        List<String> conditions = new List<String>();
        Set<String> locations = new Set<String>();
        for (String key : new List<String>{'pref1', 'pref2', 'pref3'}) {
            if (filters.get(key) != null) locations.add(String.valueOf(filters.get(key)));
        }
        List<String> cityList = filters.containsKey('cities') ? convertToListOfString(filters.get('cities')) : new List<String>();
        if (!locations.isEmpty() || !cityList.isEmpty()) {
            List<String> locOrs = new List<String>();
            if (!locations.isEmpty()) locOrs.add('WorkLocationPrefecture__c INCLUDES (\'' + String.join(new List<String>(locations), '\',\'') + '\')');
            if (!cityList.isEmpty()) locOrs.add('WorkLocationCity__c IN :cityList');
            conditions.add('(' + String.join(locOrs, ' OR ') + ')');
        }
        List<String> cats = filters.containsKey('categories') ? convertToListOfString(filters.get('categories')) : new List<String>();
        if (!cats.isEmpty()) {
            conditions.add('(JobCategory1__c IN :cats OR JobCategory2__c IN :cats OR JobCategory3__c IN :cats)');
        }
        String query = 'SELECT Id, JobPosition__c, WorkLocation2__c, JobCategory1__c, MaxAnnualSalary__c, MinAnnualSalary__c, JobDescription__c, LastModifiedDate, LastViewedDate, Company__r.MainIndustry__c FROM Job__c';
        if (!conditions.isEmpty()) query += ' WHERE ' + String.join(conditions, ' AND ');
        query += ' ORDER BY LastModifiedDate DESC LIMIT 100';
        List<JobWrapper> result = new List<JobWrapper>();
        for (Job__c j : Database.query(query)) {
            JobWrapper w = new JobWrapper();
            w.Id = j.Id; w.JobPosition = j.JobPosition__c; w.WorkLocation2 = j.WorkLocation2__c;
            w.JobCategory1 = j.JobCategory1__c; w.MaxAnnualSalary = j.MaxAnnualSalary__c;
            w.MinAnnualSalary = j.MinAnnualSalary__c; w.JobDescription = j.JobDescription__c;
            w.LastModifiedDate = j.LastModifiedDate; w.LastViewedDate = j.LastViewedDate;
            w.MainIndustry = (j.Company__r != null) ? j.Company__r.MainIndustry__c : null;
            result.add(w);
        }
        return result;
    }

    @AuraEnabled
    public static Map<String, Object> getPreferences() {
        try {
            Id userId = UserInfo.getUserId();
            User u = [SELECT Contact.AccountId FROM User WHERE Id = :userId LIMIT 1];
            
            if (u.Contact.AccountId == null) {
                return null;
            }

            Account acc = [SELECT PreferredWorkLocation1__c, PreferredWorkLocation2__c, PreferredWorkLocation3__c,
                                  PreferredSalary__c, PreferredOccupations__c, IsWillingToRelocate__pc
                           FROM Account WHERE Id = :u.Contact.AccountId LIMIT 1];
            
            Map<String, Object> prefs = new Map<String, Object>();
            prefs.put('pref1', acc.PreferredWorkLocation1__c);
            prefs.put('pref2', acc.PreferredWorkLocation2__c);
            prefs.put('pref3', acc.PreferredWorkLocation3__c);
            prefs.put('minSalary', acc.PreferredSalary__c);
            
            // 複数選択項目はセミコロン区切りを配列に戻す
            prefs.put('categories', String.isNotBlank(acc.PreferredOccupations__c) ? acc.PreferredOccupations__c.split(';') : new List<String>());
            prefs.put('transfer', String.isNotBlank(acc.IsWillingToRelocate__pc) ? acc.IsWillingToRelocate__pc.split(';') : new List<String>());
            
            return prefs;
        } catch (Exception e) {
            throw new AuraHandledException('希望条件の取得に失敗しました: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void savePreferences(Map<String, Object> filters) {
        try {
            // ログインユーザーに紐づく個人取引先（Account）のIDを取得
            Id userId = UserInfo.getUserId();
            User u = [SELECT Contact.AccountId FROM User WHERE Id = :userId LIMIT 1];
            
            if (u.Contact.AccountId == null) {
                throw new AuraHandledException('取引先レコードが見つかりません。');
            }

            Account acc = new Account(Id = u.Contact.AccountId);
            
            // 勤務地マッピング（値とカテゴリ）
            acc.PreferredWorkLocation1__c = (String)filters.get('pref1');
            acc.PreferredWorkLocation1Category__c = (String)filters.get('pref1Category');
            acc.PreferredWorkLocation2__c = (String)filters.get('pref2');
            acc.PreferredWorkLocation2Category__c = (String)filters.get('pref2Category');
            acc.PreferredWorkLocation3__c = (String)filters.get('pref3');
            acc.PreferredWorkLocation3Category__c = (String)filters.get('pref3Category');

            // 希望年収
            acc.PreferredSalary__c = (String)filters.get('minSalary');

            // 希望職種（複数選択：セミコロン区切りで保存）
            List<Object> categories = (List<Object>)filters.get('categories');
            if (categories != null) {
                acc.PreferredOccupations__c = String.join(categories, ';');
            }

            // 転勤可否（複数選択：セミコロン区切りで保存）
            List<Object> transfer = (List<Object>)filters.get('transfer');
            if (transfer != null) {
                acc.IsWillingToRelocate__pc = String.join(transfer, ';');
            }

            update acc;
            
        } catch (Exception e) {
            throw new AuraHandledException('登録に失敗しました: ' + e.getMessage());
        }
    }
}