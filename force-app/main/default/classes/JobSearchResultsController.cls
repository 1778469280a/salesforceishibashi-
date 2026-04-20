public with sharing class JobSearchResultsController {

    @AuraEnabled(cacheable=true)
    public static Map<String, Map<String, Object>> getJobCategoryValues() {
        // // 获取 JobCategory1__c 字段的描述信息
        // Schema.DescribeFieldResult ctrl = Job__c.JobCategory1__c.getDescribe();
        
        // // 获取 JobCategoryDetail1__c 字段的描述信息
        // Schema.DescribeFieldResult dep = Job__c.JobCategoryDetail1__c.getDescribe();
        
        // // 创建一个 Map 来存储 JobCategory1__c 选项和对应的 JobCategoryDetail1__c 选项
        // Map<String, List<String>> result = new Map<String, List<String>>();
        
        // // 获取 JobCategory1__c 的所有 Picklist 值
        // List<Schema.PicklistEntry> ctrlPicklist = ctrl.getPicklistValues();

        // List<Schema.PicklistEntry> depPicklist = dep.getPicklistValues();
        
        // // 遍历 JobCategory1__c 的选项
        // for (Schema.PicklistEntry ctrlVal : ctrlPicklist) {
        //     // 初始化结果 Map
        //     result.put(ctrlVal.getLabel(), new List<String>());
            
        //     // 遍历 JobCategoryDetail1__c 的选项
        //     for (Schema.PicklistEntry depVal : depPicklist) {
        //         // 根据控制字段的选项来筛选出依赖字段的有效选项
        //         // 在这个例子中，假设我们没有依赖关系，仅返回所有选项
        //         result.get(ctrlVal.getLabel()).add(depVal.getLabel());
        //     }
        // }

     // 创建一个 Map 用于存储父类别和对应的子类别
        Map<String, Map<String, Object>> result = new Map<String, Map<String, Object>>();

        // 父类 "営業系"
        List<Map<String, Object>> engineeringSubCategories = new List<Map<String, Object>>();
        engineeringSubCategories.add(new Map<String, Object>{'name' => 'Software Engineer', 'checked' => false});
        engineeringSubCategories.add(new Map<String, Object>{'name' => 'Data Scientist', 'checked' => false});
        engineeringSubCategories.add(new Map<String, Object>{'name' => 'System Architect', 'checked' => false});
        
        // 父类 "営業系" 数据，保持 "name", "checked", 和 "child"
        Map<String, Object> engineeringCategory = new Map<String, Object>();
        engineeringCategory.put('name', '営業系');
        engineeringCategory.put('checked', false);
        engineeringCategory.put('child', engineeringSubCategories);

        result.put('営業系', engineeringCategory);

        // 父类 "管理部門"
        List<Map<String, Object>> managementSubCategories = new List<Map<String, Object>>();
        managementSubCategories.add(new Map<String, Object>{'name' => 'Human Resources', 'checked' => false});
        managementSubCategories.add(new Map<String, Object>{'name' => 'Legal', 'checked' => false});

        Map<String, Object> managementCategory = new Map<String, Object>();
        managementCategory.put('name', '管理部門');
        managementCategory.put('checked', false);
        managementCategory.put('child', managementSubCategories);

        result.put('管理部門', managementCategory);

        // 父类 "マーケティング"
        List<Map<String, Object>> marketingSubCategories = new List<Map<String, Object>>();
        marketingSubCategories.add(new Map<String, Object>{'name' => 'Marketing Specialist', 'checked' => false});
        marketingSubCategories.add(new Map<String, Object>{'name' => 'Brand Manager', 'checked' => false});

        Map<String, Object> marketingCategory = new Map<String, Object>();
        marketingCategory.put('name', 'マーケティング');
        marketingCategory.put('checked', false);
        marketingCategory.put('child', marketingSubCategories);

        result.put('マーケティング', marketingCategory);

        // 返回模拟数据
        return result;
    }
}