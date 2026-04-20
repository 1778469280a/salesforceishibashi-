@isTest
public with sharing class RecentJobViewedControllerTest {

    /**
     * 正常系テスト：実際の組織データを使ってメソッドが正常に動作することを検証します。
     * LastViewedDate は読み取り専用のため、既存データに依存します（SeeAllData=true）。
     */
    @isTest(SeeAllData=true)
    static void testGetRecentViewedJobsNormal() {
        Test.startTest();
        List<Job__c> results = RecentJobViewedController.getRecentViewedJobs();
        Test.stopTest();

        System.assert(results != null, '結果が null ではありません');
        System.assert(results.size() <= 4, '返却されるレコードは最大4件です。実際: ' + results.size());

        if (results.size() > 1) {
            for (Integer i = 0; i < results.size() - 1; i++) {
                System.assert(results[i].LastViewedDate >= results[i+1].LastViewedDate,
                    'LastViewedDate が降順で並んでいる必要があります');
            }
        }

        for (Job__c job : results) {
            System.assert(job.Id != null, 'Id が取得できていません');
            System.assert(job.Name != null, 'Name が取得できていません');
            System.assert(job.JobPosition__c != null, 'JobPosition__c が取得できていません');
            System.assert(job.LastViewedDate != null, 'LastViewedDate が取得できていません');
        }
    }

    /**
     * 異常系テスト：強制例外フラグを true にして catch ブロックを実行させ、
     * AuraHandledException がスローされることだけを確認します（メッセージ内容は検証しません）。
     */
    @isTest
    static void testGetRecentViewedJobsException() {
        RecentJobViewedController.testForceException = true;

        Test.startTest();
        try {
            RecentJobViewedController.getRecentViewedJobs();
            System.assert(false, 'AuraHandledException が発生すべき');
        } catch (AuraHandledException e) {
            // 例外がスローされれば成功（メッセージ内容は環境依存のため検証しない）
            System.assert(true);
        } catch (Exception e) {
            System.assert(false, 'AuraHandledException 以外の例外が発生しました: ' + e.getMessage());
        }
        Test.stopTest();

        RecentJobViewedController.testForceException = false;
    }
}