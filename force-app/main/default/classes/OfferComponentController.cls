/**
 * オファー（JOB打診）情報を提供するコントローラクラス
 * Lightning Web Component から呼び出され、オファー件数と最新のオファー詳細を返します。
 */
public with sharing class OfferComponentController {

    /**
     * オファー（JOB打診）の総件数と、最新2件の求人情報を取得します。
     * cacheable=true により、同じリクエストではキャッシュが利用されます。
     *
     * @return  以下のキーを含む Map<String, Object>
     *          - 'totalCount' : Integer オファーの総件数
     *          - 'jobInfos'   : List<Map<String, Object>> 求人詳細のリスト（最大2件）
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getOffers() {
        // オファー（LatestProcessStatus__c = 'JOB打診'）の総件数を取得
        Integer totalCount = [SELECT COUNT() FROM SelectionProcess__c WHERE LatestProcessStatus__c = 'JOB打診'];

        // 最新のオファーを最大2件、最終更新日時の降順で取得
        // 同時にリレーション先の Job__c および Company__c の必要なフィールドも取得
        List<SelectionProcess__c> processes = [
            SELECT 
                Id, 
                JobPosition__c,
                LatestProcessStatus__c,
                LastModifiedDate,
                JobPosition__r.Id,
                JobPosition__r.Company__r.Name,
                JobPosition__r.JobPosition__c,
                JobPosition__r.WorkLocation2__c,
                JobPosition__r.Company__r.MainIndustry__c,
                JobPosition__r.JobCategory1__c,
                JobPosition__r.LastViewedDate
            FROM SelectionProcess__c
            WHERE LatestProcessStatus__c = 'JOB打診'
            ORDER BY LastModifiedDate DESC
            LIMIT 2
        ];

        // フロントエンドに渡すための情報を格納するリスト
        List<Map<String, Object>> jobInfos = new List<Map<String, Object>>();

        // 取得した各選考プロセスレコードから必要な情報を抽出
        for (SelectionProcess__c process : processes) {
            Map<String, Object> jobInfo = new Map<String, Object>();
            jobInfo.put('jobId', process.JobPosition__c); // 求人ID
            // 最終更新日時を「yyyy/M/d HH:mm」形式の文字列に変換
            jobInfo.put('lastUpdate', process.LastModifiedDate.format('yyyy/M/d HH:mm'));
            // 求人タイトル（Null安全演算子を使用）
            jobInfo.put('JobPosition', process.JobPosition__r?.JobPosition__c);
            // 勤務地（Null安全）
            jobInfo.put('WorkLocation2', process.JobPosition__r?.WorkLocation2__c);
            // 職種カテゴリ（Null安全）
            jobInfo.put('JobCategory1', process.JobPosition__r?.JobCategory1__c);
            // 職種カテゴリ（Null安全）
            jobInfo.put('MainIndustry', process.JobPosition__r?.Company__r?.MainIndustry__c);
            // 企業名（Null安全、二階層のリレーション）
            jobInfo.put('companyName', process.JobPosition__r?.Company__r.Name);
            // 最終閲覧日（Null安全）
            jobInfo.put('lastViewedDate', process.JobPosition__r?.LastViewedDate);
            jobInfos.add(jobInfo);
        }

        // 結果をマップにまとめて返却
        Map<String, Object> result = new Map<String, Object>();
        result.put('jobInfos', jobInfos);
        result.put('totalCount', totalCount);
        return result;
    }
}